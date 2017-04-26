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
            .where(users.mobile == Parameter())

        if let connection = self.pool.getConnection() {
            connection.execute(query: query, parameters: [mobile]) { result in
                if
                    let rows = result.asRows,
                    let row = rows.first
                {
                    callback(row)
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

        let query = Insert(into: credentials, columns: [credentials.userId, credentials.name], values: [Parameter(), "fysfemman.se"])
                    .suffix("RETURNING token")

        if let connection = self.pool.getConnection() {
            connection.execute(query: query, parameters: [userID]) { result in
                guard
                    let rows = result.asRows,
                    let row = rows.first
                else {
                    Log.error("Failed to insert new token in database")
                    if let error = result.asError {
                        Log.error("Error: \(error)")
                    }
                    callback(nil)
                    return
                }

                callback(row)
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
            .where(credentials.token == Parameter())

        if let connection = self.pool.getConnection() {
            connection.execute(query: query, parameters: [token]) { result in
                if let queryError = result.asError {
                    Log.error("Something went wrong \(queryError)")
                    callback(nil)
                    return
                }

                guard
                    let rows = result.asRows,
                    let row = rows.first,
                    let name = row["name"] as? String,
                    let userID = row["user_id"] as? String
                else {
                        //TBD: Send user / password incorrect response
                        Log.error("User not found")
                        callback(nil)
                        return
                }

                Log.info("Authenticated user: \(userID) as \(name)")
                callback(UserProfile(id: userID, displayName: name, provider: "Kitura-HTTP"))
                return
            }
        } else {
            Log.warning("Error Connecting to DB")
            callback(nil)
        }
    }
}
