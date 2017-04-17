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
    private let loginCodes = LoginCodes()
    private let connection = PostgreSQLConnection(host: "localhost", port: 5432, options: [.databaseName("fysfemman"), .userName("fysfemman")])
    private let credentials = Credentials()

    // Initialising our KituraSession
    private let session = Session(secret: "")

    public init() {
        activities = Activities(withConnection: self.connection)
        users = Users(withConnection: self.connection)
        loginCodes.setupCodeInvalidationTimer(interval: 60.0)

        credentials.register(plugin: CredentialsHTTPBasic(verifyPassword: users.verifyCredentials, realm: "Kitura-Realm"))

        setupRoutes()
    }

    private func setupRoutes() {
        let options = Options(allowedOrigin: .all)
        let cors = CORS(options: options)

        router.add(templateEngine: StencilTemplateEngine())
        router.all(middleware: session)
        router.all(middleware: BodyParser())
        router.all(middleware: cors)
        router.all("/api", middleware: credentials)
        router.get("/", handler: onIndex)
        router.get("/api/v1/activities", handler: onGetActivities)
        router.post("/api/v1/activities", handler: onAddActivity)
        router.get("/api/v1/login/:mobile", handler: onGetLogin)
        router.post("/api/v1/login/:mobile", handler: onPostLogin)
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
        guard let userProfile = request.userProfile else {
            do {
                try response.status(.badRequest).end()
            } catch { Log.error("Communication error") }
            return
        }

        activities.get(withUserID: userProfile.id) { activities, error in
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

    private func onGetLogin(request: RouterRequest, response: RouterResponse, next: () -> Void) {
        guard let mobile = request.parameters["mobile"] else {
            do {
                try response.status(.badRequest).end()
            } catch { Log.error("Communication error") }
            return
        }

        users.get(byMobile: mobile) { user in
            do {
                guard
                    let user = user,
                    let userId = user["id"] as? String
                else {
                    try response.status(.badRequest).end()
                    return
                }
                let name = user["name"] as? String ?? ""
                let code = self.loginCodes.generateAndAdd(forUser: userId, withMobile: mobile)
                Log.info("Code generated for user \(name): \(code)")

                try response.status(.OK).end()
            } catch {
                Log.error("Communication error")
            }
        }
    }

    private func onPostLogin(request: RouterRequest, response: RouterResponse, next: () -> Void) {
        guard
            let json = bodyAsJson(request.body),
            let mobile = request.parameters["mobile"]
        else {
            do {
                try response.status(.badRequest).end()
            } catch { Log.error("Communication error") }
            return
        }

        guard let code = json["code"].string else {
            Log.error("No code submitted")
            do {
                try response.status(.badRequest).end()
            } catch { Log.error("Communication error") }
            return
        }

        if let userId = loginCodes.verify(code: code, withMobile: mobile) {
            users.generateToken(forUser: userId) { token in
                do {
                    guard let token = token else {
                        try response.status(.internalServerError).end()
                        return
                    }

                    let json = JSON(token)
                    try response.status(.OK).send(json: json).end()
                } catch {
                    Log.error("Communication error")
                }
            }
        } else {
            do {
                try response.status(.unauthorized).end()
            } catch { Log.error("Communication error") }
        }
    }

    private func onAddActivity(request: RouterRequest, response: RouterResponse, next: () -> Void) {
        guard let userProfile = request.userProfile else {
            do {
                try response.status(.unauthorized).end()
            } catch { Log.error("Communication error") }
            return
        }

        guard case let .json(json) = body else {
            Log.error("Body contains invalid JSON")
            response.status(.badRequest)
            return
        }
        let userID = userProfile.id

        guard let date = json["date"].string,
            let rating = json["rating"].int,
            let activityType = json["activityType"].string,
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
