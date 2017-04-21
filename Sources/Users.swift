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
    let mobile = Column("mobile")
}

class CredentialsTable: Table {
    let tableName = "credentials"
    let id = Column("id")
    let userId = Column("user_id")
    let token = Column("token")
    let name = Column("name")
    let issued = Column("issued")
    let expires = Column("expires")
}

class Users: DatabaseModel {
    private let users = UsersTable()
    private let credentials = CredentialsTable()

    public func get(byMobile mobile: String, callback: @escaping([String:Any?]?)->Void) -> Void {

        let query = Select(from: users)
            .where(users.mobile == mobile)

        if let connection = self.pool.getConnection() {
            connection.execute(query: query) { result in
                if
                    let rows = result.asRows,
                    let row = rows.first,
                    let userId = row["id"] as? Data
                {
                    let user: [String: Any] = [
                        "id": uuidString(withData: userId),
                        "name": row["name"] as? String ?? "",
                        "admin": row["admin"] as? Bool ?? false,
                        "datareader": row["datareader"] as? Bool ?? false
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
        } else {
            Log.warning("Error Connecting to DB")
            callback(nil)
        }
    }

    public func generateToken(forUser userID: String, callback: @escaping([String:Any?]?)->Void) -> Void {

        let query = "INSERT INTO credentials (user_id, name) VALUES ('\(userID)'::uuid,'fysfemman.se') RETURNING token"

        if let connection = self.pool.getConnection() {
            connection.execute(query) { result in
                guard
                    result.success == true,
                    let rows = result.asRows,
                    let row = rows.first,
                    let tokenData = row["token"] as? Data
                else {
                        callback(nil)
                        return
                }

                let token: [String: Any?] = [
                    "token": uuidString(withData: tokenData)
                ]

                callback(token)
            }
        } else {
            Log.warning("Error Connecting to DB")
            callback(nil)
        }
    }

    public func verifyCredentials(token: String, password: String, callback: @escaping(UserProfile?)->Void) -> Void {

        let query = Select(credentials.userId, users.name, from: credentials)
            .leftJoin(users)
            .on(credentials.userId == users.id)
            .where(credentials.token == token)

        if let connection = self.pool.getConnection() {
            connection.execute(query: query) { result in
                if let queryError = result.asError {
                    Log.error("Something went wrong \(queryError)")
                    callback(nil)
                    return
                }

                guard
                    let rows = result.asRows,
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
        } else {
            Log.warning("Error Connecting to DB")
            callback(nil)
        }
    }
}
