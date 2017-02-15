//
//  FysfemmanController.swift
//  Fysfemman
//
//  Created by Magnus Ahlberg on 2017-02-15.
//
//

import Foundation

import Kitura
import KituraStencil
import KituraSession

import LoggerAPI
import SwiftKuery
import SwiftKueryPostgreSQL
import SwiftyJSON

class Users : Table {
    let tableName = "users"
    let uid = Column("uid")
    let email = Column("email")
    let password = Column("password")
}

let connection = PostgreSQLConnection(host: "localhost", port: 5432, options: [.databaseName("fysfemman"), .userName("fysfemman"), .password("")])


public final class FysfemmanController {
    //    private let activities: Activities
    private let users = Users()
    public let router = Router()

    // Initialising our KituraSession
    private let session = Session(secret: "")

    public init() {//backend: Activities) {
        //        self.activities = backend
        setupRoutes()
    }

    private func setupRoutes() {
        router.add(templateEngine: StencilTemplateEngine())
        router.all(middleware: session)
        router.all(middleware: BodyParser())
        router.get("/", handler: onIndex)
        router.post("/login", handler: onLogin)
        router.post("/logout", handler: onLogout)
    }

    private func isAuthorized(email: String, password: String) -> Bool {
        //Connect to database
        var authorized = false
        connection.connect() { error in
            if let error = error {
                Log.error("Error is \(error)")

            }
            else {
                let query = Select(users.email, users.password, from: users)
                    .where(users.email == email)
                connection.execute(query: query) { result in
                    if let rows = result.asRows {
                        Log.info("Rows: \(rows.count))")
                        if rows.count > 0 {
                            if let truePassword = rows[0]["password"] as? String {
                                if truePassword == password {
                                    Log.info("Password valid")
                                    authorized = true
                                }
                            }
                        }
                    } else if let queryError = result.asError {
                        Log.error("Something went wrong \(queryError)")
                    }
                }
            }
        }
        return authorized
    }

    private func onIndex(request: RouterRequest, response: RouterResponse, next: () -> Void) {
        defer {
            next()
        }

        let maybeSess = request.session

        var context: [String: Any] = [:]
        do {
            //Check if we have a session and it has a value for email
            guard let sess = maybeSess, let email = sess["email"].string else {
                try response.render("login.stencil", context: context).end()
                return
            }

            context["name"] = email

            try response.render("index.stencil", context: context).end()
        } catch {}
    }

    private func onLogin(request: RouterRequest, response: RouterResponse, next: () -> Void) {
        defer {
            next()
        }
        //Get current session
        // Where we will store the current session data
        //var sess: SessionState?

        let maybeSess = request.session

        var maybeEmail: String?
        var maybePassword: String?

        do {
            switch request.body {
            case .urlEncoded(let params)?:
                Log.info("URL encoded")
                maybeEmail = params["email"]
                maybePassword = params["password"]
            default:
                try response.send("fail").end()
                break
            }

            if let email = maybeEmail?.removingPercentEncoding, let password = maybePassword?.removingPercentEncoding, let sess = maybeSess {
                if isAuthorized(email: email, password: password) {
                    Log.info("Logged in")
                    sess["email"] = JSON(email)
                    try response.send("done").end()
                }
            }
            try response.send("fail").end()
        } catch {}

    }

    private func onLogout(request: RouterRequest, response: RouterResponse, next: () -> Void) {
        //Destroy all data in our session
        request.session?.destroy() {
            (error: NSError?) in
            if let error = error {
                if Log.isLogging(.error) {
                    Log.error("\(error)")
                }
            }
        }
        do {
            try response.send("done").end()
        } catch {}
    }
}
