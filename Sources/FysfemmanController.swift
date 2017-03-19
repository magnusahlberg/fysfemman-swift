//
//  FysfemmanController.swift
//  Fysfemman
//
//  Created by Magnus Ahlberg on 2017-02-15.
//
//

import Foundation

import Kitura
import KituraCORS
import KituraStencil
import KituraSession

import Credentials
import CredentialsHTTP

import LoggerAPI
import SwiftKuery
import SwiftKueryPostgreSQL
import SwiftyJSON

public final class FysfemmanController {
    public let router = Router()

    private let activities: Activities
    private let users: Users
    private let connection = PostgreSQLConnection(host: "localhost", port: 5432, options: [.databaseName("fysfemman"), .userName("fysfemman")])
    private let credentials = Credentials()

    // Initialising our KituraSession
    private let session = Session(secret: "")

    public init() {
        activities = Activities(withConnection: self.connection)
        users = Users(withConnection: self.connection)

        credentials.register(plugin: CredentialsHTTPBasic(verifyPassword: users.verifyPassword, realm: "Kitura-Realm"))

        setupRoutes()
    }

    private func setupRoutes() {
        let options = Options(allowedOrigin: .all)
        let cors = CORS(options: options)

        router.add(templateEngine: StencilTemplateEngine())
        router.all(middleware: session)
        router.all(middleware: BodyParser())
        router.all("/api", middleware: credentials)
        router.all(middleware: cors)
        router.get("/", handler: onIndex)
        router.get("/api/1/activities", handler: onGetActivities)
        router.post("/api/1/activities", handler: onAddActivity)
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
                    Log.error("No activity returned")
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
