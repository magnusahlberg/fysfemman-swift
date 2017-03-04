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

import Credentials
import CredentialsHTTP

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
    public let router = Router()

    private let activities: Activities
    private let users = Users()
    private let connection = PostgreSQLConnection(host: "localhost", port: 5432, options: [.databaseName("fysfemman"), .userName("fysfemman")])
    private let credentials = Credentials()

    // Initialising our KituraSession
    private let session = Session(secret: "")

    public init() {
        connection.connect() { error in
            if let error = error {
                Log.error("SQL: Could not connect: \(error)")
            }
        }
        activities = Activities(withConnection: self.connection)

        credentials.register(plugin: CredentialsHTTPBasic(verifyPassword: verifyPassword, realm: "Kitura-Realm"))

        setupRoutes()
    }

    private func setupRoutes() {
        router.add(templateEngine: StencilTemplateEngine())
        router.all(middleware: session)
        router.all(middleware: BodyParser())
        router.all("/api", middleware: credentials)
        router.get("/", handler: onIndex)
        router.get("/api/1/activities", handler: onGetActivities)
        router.post("/api/1/activities", handler: onAddActivity)
    }

    private func verifyPassword(userID: String, password: String, callback: @escaping(UserProfile?)->Void) -> Void {
        let query = Select(users.email, users.password, from: users)
            .where(users.email == userID)

        connection.execute(query: query) { result in
            if let rows = result.asRows {
                Log.info("Rows: \(rows.count))")
                if rows.count > 0 {
                    if let truePassword = rows[0]["password"] as? String {
                        if truePassword == password {
                            callback(UserProfile(id: userID, displayName: userID, provider: "Kitura-HTTP"))
                            return
                        }
                    }
                } else {
                    //TBD: Send user / password incorrect response
                    Log.error("User not found")
                }
            } else if let queryError = result.asError {
                Log.error("Something went wrong \(queryError)")
            }
            callback(nil)
        }
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
}
