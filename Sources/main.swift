import Foundation
import HeliumLogger
import Kitura
import LoggerAPI

// Initialize HeliumLogger
HeliumLogger.use()

let logger = HeliumLogger()
Log.logger = logger

let controller = FysfemmanController()

// Add an HTTP server and connect it to the router
Kitura.addHTTPServer(onPort: 8090, with: controller.router)

// Start the Kitura runloop (this call never returns)
Kitura.run()
