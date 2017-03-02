//
//  Activities.swift
//  Fysfemman
//
//  Created by Magnus Ahlberg on 2017-02-15.
//
//

import Foundation
import LoggerAPI
import SwiftKuery
import SwiftKueryPostgreSQL

class ActivitiesTable : Table {
    let tableName = "activities"
    let id = Column("id")
    let user_id = Column("user_id")
    let date = Column("date")
    let rating = Column("rating")
    let activity_type = Column("activity_type")
    let units = Column("units")
    let bonus_multiplier = Column("bonus_multiplier")
    let points = Column("points")
    let registered_date = Column("registered_date")
}

class ActivityTypesTable : Table {
    let tableName = "activity_types"
    let id = Column("id")
    let name = Column("name")
    let unit = Column("unit")
    let multiplier = Column("multiplier")
}


public final class Activities {
    public let connection: PostgreSQLConnection

    private let activities = ActivitiesTable()
    private let activityTypes = ActivityTypesTable()

    public init(withConnection connection: PostgreSQLConnection) {
        self.connection = connection
    }

    public func get(withUserID userId: String, oncompletion: @escaping([[String: Any]]?, Error?) -> Void) {

        let query = Select(from: activities)
            .where(activities.user_id == userId)

        var activitiesDictionary = [[String: Any]]()

        connection.execute(query: query) { result in
            if let rows = result.asRows {
                activitiesDictionary = rows
            } else if let queryError = result.asError {
                oncompletion(nil, queryError)
            } else {
                Log.warning("Mo rows returned")
            }
            oncompletion(activitiesDictionary, nil)
        }
    }

    public func add(userID: Int, date: String, rating: Int, activityType: Int, units: Double, bonusMultiplier: Double, oncompletion: @escaping([String: Any]?, Error?) -> Void) {

        getActivityType(byID: activityType) { result, error in
            let points: Double

            guard let result = result else {
                Log.error("No activity for multiplier found")
                return
            }

            let multiplierString = result["multiplier"] as? String ?? "0"

            if let multiplier = Double(multiplierString) {
                points = units * multiplier * bonusMultiplier
            } else {
                Log.error("Could not convert multiplier to double")
                points = 0
            }

            let query = "INSERT INTO activities (user_id, date, rating, activity_type, units, bonus_multiplier, points, registered_date) VALUES (\(userID), '\(date)', \(rating), \(activityType), \(units), \(bonusMultiplier), \(points), current_timestamp) RETURNING id"
            self.connection.execute(query) { result in
                if result.success {
                    Log.info("Insert successful: \(String(describing: result.asValue))")
                    var activity = [String: Any]()
                    activity["user_id"] = userID
                    activity["date"] = date
                    activity["rating"] = rating
                    activity["activity_type"] = activityType
                    activity["units"] = units
                    activity["bonus_multiplier"] = bonusMultiplier
                    activity["points"] = points

                    oncompletion(activity, nil)
                } else if let queryError = result.asError {
                    oncompletion(nil, queryError)
                }
            }
        }
    }

    private func getActivityType(byID id: Int, oncompletion: @escaping([String: Any]?, Error?) -> Void) {
        let query = Select(from: activityTypes)
                        .where(activityTypes.id == id)

        connection.execute(query: query) { result in
            if let rows = result.asRows {
                Log.info(String(describing: rows[0]))
                oncompletion(rows[0], nil)
            } else if let queryError = result.asError {
                oncompletion(nil, queryError)
            }
        }
    }
}