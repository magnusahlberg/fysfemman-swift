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

public final class FysfemmanController {
    private let activities: Activities
    private let users = Users()
    private let connection = PostgreSQLConnection(host: "localhost", port: 5432, options: [.databaseName("fysfemman"), .userName("fysfemman")])
    public let router = Router()

    // Initialising our KituraSession
    private let session = Session(secret: "")

    public init() {
        connection.connect() { error in
            if let error = error {
                Log.error("SQL: Could not connect: \(error)")
            }
        }
        activities = Activities(withConnection: self.connection)
        setupRoutes()
    }

    private func setupRoutes() {
        router.add(templateEngine: StencilTemplateEngine())
        router.all(middleware: session)
        router.all(middleware: BodyParser())
        router.get("/", handler: onIndex)
        router.get("/api/1/activities", handler: onGetActivities)
        router.post("/api/1/activities", handler: onAddActivity)
        router.post("/login", handler: onLogin)
        router.post("/logout", handler: onLogout)
    }

    private func isAuthorized(email: String, password: String) -> Bool {
        //Connect to database
        var authorized = false

        let query = Select(users.email, users.password, from: users)
            .where(users.email == email)

        connection.execute(query: query) { result in
            if let rows = result.asRows {
                Log.info("Rows: \(rows.count))")
                if rows.count > 0 {
                    if let truePassword = rows[0]["password"] as? String {
                        if truePassword == password {
                            authorized = true
                        }
                    }
                } else {
                    //TBD: Send user / password incorrect response
                    Log.error("User not found")
                }
            } else if let queryError = result.asError {
                Log.error("Something went wrong \(queryError)")
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

    private func onGetActivities(request: RouterRequest, response: RouterResponse, next: () -> Void) {
        activities.get(withUserID: "1") { activities, error in
            do {
                guard error == nil else {
                    try response.status(.badRequest).end()
                    Log.error(error.debugDescription)
                    return
                }
                guard let activities = activities else {
                    try response.status(.internalServerError).end()
                    return
                }

                let json = JSON(activities)
                try response.status(.OK).send(json: json).end()
            } catch {
                Log.error("Communication error")
            }
        }
    }

    private func onAddActivity(request: RouterRequest, response: RouterResponse, next: () -> Void) {
        guard let body = request.body else {
            Log.error("No body found")
            response.status(.badRequest)
            return
        }

        guard case let .json(json) = body else {
            Log.error("Body contains invalid JSON")
            response.status(.badRequest)
            return
        }
        let userID = 1

        guard let date = json["date"].string,
            let rating = json["rating"].int,
            let activityType = json["activityType"].int,
            let units = json["units"].double,
            let bonus = json["bonusMultiplier"].double
            else {
                Log.error("Body contains invalid JSON")
                do {
                    try response.status(.badRequest).end()
                } catch {
                    Log.error("Communication error")
                }
                return
        }
        Log.info("Success")

        let bonusMultiplier = bonus / 100 + 1

        activities.add(userID: userID, date: date, rating: rating, activityType: activityType, units: units, bonusMultiplier: bonusMultiplier) { activity, error in
            do {
                guard error == nil else {
                    try response.status(.badRequest).end()
                    Log.error(error.debugDescription)
                    return
                }
                guard let activity = activity else {
                    try response.status(.internalServerError).end()
                    return
                }
                let json = JSON(activity)
                try response.status(.OK).send(json: json).end()
            } catch {
                Log.error("Communication error")
            }
        }
    }

    private func onLogin(request: RouterRequest, response: RouterResponse, next: () -> Void) {
        defer {
            next()
        }

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
