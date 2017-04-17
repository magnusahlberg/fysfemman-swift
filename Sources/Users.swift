//
//  Users.swift
//  Fysfemman
//
//  Created by Magnus Ahlberg on 2017-03-19.
//
//

import Foundation
import LoggerAPI
import SwiftKuery
import SwiftKueryPostgreSQL
import Credentials

class UsersTable: Table {
    let tableName = "users"
    let id = Column("id")
    let name = Column("name")
    let email = Column("email")
    let password = Column("password")
}

class Users: DatabaseModel {
    private let users = UsersTable()

    public func get(byMobile mobile: String, callback: @escaping([String:Any?]?)->Void) -> Void {
        let query = Select(from: users)
            .where(users.mobile == mobile)

        executeQuery(query: query) { result in
            guard let result = result else {
                callback(nil)
                return
            }

            if
                let rows = result.asRows,
                let row = rows.first,
                let userId = row["id"] as? Data {
                let user = [
                    "id": uuidString(withData: userId),
                    "name": row["name"],
                    "admin": row["admin"]
                ]
                callback(user)
                return
            } else if let queryError = result.asError {
                Log.error("Something went wrong \(queryError)")
            } else {
                Log.error("No user found with mobile: \(mobile)")
            }

            callback(nil)
        }
    }

    public func add(name: String, email: String, password: String, callback: @escaping(Error?) -> Void) {
        // TODO
    }

    public func verifyCredentials(token: String, password: String, callback: @escaping(UserProfile?)->Void) -> Void {
        let query = Select(credentials.userId, users.name, from: credentials)
            .leftJoin(users)
            .on(credentials.userId == users.id)
            .where(credentials.token == token)

        executeQuery(query: query) { result in
            guard let result = result else {
                callback(nil)
                return
            }
            if let queryError = result.asError {
                Log.error("Something went wrong \(queryError)")
                callback(nil)
                return
            }

            guard let rows = result.asRows,
               let row = rows.first,
               let name = row["name"] as? String,
               let id = row["user_id"] as? Data
            else {
                //TBD: Send user / password incorrect response
                Log.error("User not found")
                callback(nil)
                return
            }

            let userID = uuidString(withData: id)
            Log.info("Authenticated user: \(userID)")
            callback(UserProfile(id: userID, displayName: name, provider: "Kitura-HTTP"))
            return
        }
    }


}
