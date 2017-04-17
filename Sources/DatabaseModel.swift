//
//  DatabaseModel.swift
//  Fysfemman
//
//  Created by Magnus Ahlberg on 2017-04-16.
//
//

import Foundation
import SwiftKuery
import SwiftKueryPostgreSQL
import LoggerAPI

enum DatabaseError: Error {
    case ConnectionError
    case NoData
}

public func uuidString(withData data: Data) -> String {
    return data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>)->String in
        return NSUUID(uuidBytes: bytes).uuidString

    }
}


class DatabaseModel {
    private let connection: PostgreSQLConnection

    public init(withConnection connection: PostgreSQLConnection) {
        self.connection = connection
    }

    func executeQuery(query: Query, oncompletion: @escaping (QueryResult?) -> ()) {

        self.connection.connect() { error in

            guard error == nil else {
                Log.error("SQL: Could not connect: \(String(describing:error))")
                oncompletion(nil)
                return
            }

            self.connection.execute(query: query) { result in

                defer {
                    self.connection.closeConnection()
                }

                oncompletion(result)
            }
        }
    }

    func executeQuery(_ raw: String, oncompletion: @escaping (QueryResult?) -> ()) {

        self.connection.connect() { error in

            guard error == nil else {
                Log.error("SQL: Could not connect: \(String(describing: error))")
                oncompletion(nil)
                return
            }

            self.connection.execute(raw) { result in

                defer {
                    self.connection.closeConnection()
                }

                oncompletion(result)
            }
        }
    }
}

