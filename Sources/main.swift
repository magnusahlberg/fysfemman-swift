import Foundation
import HeliumLogger
import Kitura
import KituraStencil
import KituraSession
import LoggerAPI
import SwiftyJSON

// Initialize HeliumLogger
HeliumLogger.use()

let logger = HeliumLogger()
Log.logger = logger

// Create a new router
let router = Router()
router.add(templateEngine: StencilTemplateEngine())

// Where we will store the current session data
var sess: SessionState?

// Initialising our KituraSession
let session = Session(secret: "Top secret session key…")

router.all(middleware: session)

router.all(middleware: BodyParser())

// Handle HTTP GET requests to /
router.get("/") { request, response, next in
    defer {
        next()
    }
    
    sess = request.session
    
    var context: [String: Any] = [:]
    
    //Check if we have a session and it has a value for email
    guard let sess = sess, let email = sess["email"].string else {
        try response.render("login.stencil", context: context).end()
        return
    }

    context["name"] = email

    try response.render("index.stencil", context: context).end()
}

router.post("/login") {
    request, response, next in
    
    //Get current session
    sess = request.session
    
    var maybeEmail: String?
    
    switch request.body {
    case .urlEncoded(let params)?:
        maybeEmail = params["email"]
    case .json(let params)?:
        maybeEmail = params["email"].string
    default: break
    }
    
    if let email = maybeEmail?.removingPercentEncoding, let sess = sess {
        sess["email"] = JSON(email)
        try response.send("done").end()
    }
}

// Add an HTTP server and connect it to the router
Kitura.addHTTPServer(onPort: 8090, with: router)

// Start the Kitura runloop (this call never returns)
Kitura.run()
