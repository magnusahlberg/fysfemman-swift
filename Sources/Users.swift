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

class Users {
    private let users = UsersTable()

    private let connection: PostgreSQLConnection

    public init(withConnection connection: PostgreSQLConnection) {
        self.connection = connection
    }

    public func get(userID: String) {
        // TODO
    }

    public func add(name: String, email: String, password: String, callback: @escaping(Error?) -> Void) {
        // TODO
    }

    public func verifyPassword(userID email: String, password: String, callback: @escaping(UserProfile?)->Void) -> Void {
        let query = Select(users.email, users.password, from: users)
            .where(users.email == email)

        connection.connect() { error in
            if let error = error {
                Log.error("SQL: Could not connect: \(error)")
                callback(nil)
                return
            }
            connection.execute(query: query) { result in
                if let rows = result.asRows {
                    if rows.count > 0 {
                        if let truePassword = rows[0]["password"] as? String {
                            if truePassword == password {
                                let name = rows[0]["name"] as? String ?? ""

                                callback(UserProfile(id: email, displayName: name, provider: "Kitura-HTTP"))
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
    }


}
