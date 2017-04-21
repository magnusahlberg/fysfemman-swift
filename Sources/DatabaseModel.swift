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
    public let pool: ConnectionPool

    public init(withConnectionPool pool: ConnectionPool) {
        self.pool = pool
    }
}

