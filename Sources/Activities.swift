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
    let comment = Column("comment")
}

class ActivityTypesTable : Table {
    let tableName = "activity_types"
    let id = Column("id")
    let name = Column("name")
    let unit = Column("unit")
    let multiplier = Column("multiplier")
}

class Activities: DatabaseModel {
    private let activities = ActivitiesTable()
    private let activityTypes = ActivityTypesTable()

    public func get(withUserID userID: String, oncompletion: @escaping([[String: Any?]]?, Error?) -> Void) {

        let query = "SELECT name, units, unit, bonus_multiplier, points, rating, comment FROM activities LEFT JOIN activity_types ON activities.activity_type = activity_types.id WHERE activities.user_id = '\(userID)'::uuid"

        if let connection = self.pool.getConnection() {
            connection.execute(query) { result in
                if let rows = result.asRows {
                    oncompletion(rows, nil)
                } else if let queryError = result.asError {
                    oncompletion(nil, queryError)
                } else {
                    Log.warning("No rows returned")
                    oncompletion(nil, DatabaseError.NoData)
                }
            }
        } else {
            Log.warning("Error Connecting to DB")
            oncompletion(nil, DatabaseError.ConnectionError)
        }
    }

    public func add(userID: String, date: String, rating: Int, activityType: String, units: Double, bonusMultiplier: Double, comment: String = "", oncompletion: @escaping([String: Any]?, Error?) -> Void) {

        getActivityType(byID: activityType) { activityTypeResult, error in
            let points: Double

            guard let activityTypeResult = activityTypeResult else {
                Log.error("No activity for multiplier found")
                return
            }

            let multiplier = activityTypeResult["multiplier"] as? Double ?? 0.0
            points = (units * multiplier * (Double(bonusMultiplier) / 100.0 + 1) * 1000).rounded() / 1000

            let query = "INSERT INTO activities (user_id, date, rating, activity_type, units, bonus_multiplier, points, registered_date, comment) VALUES ('\(userID)'::uuid, '\(date)', \(rating), '\(activityType)'::uuid, \(units), \(bonusMultiplier), \(points), current_timestamp, '\(comment)') RETURNING id"

            if let connection = self.pool.getConnection() {
                connection.execute(query) { result in
                    guard result.success == true else { oncompletion(nil, DatabaseError.NoData); return }

                    if let queryError = result.asError {
                        Log.error("Error: \(queryError)")
                        oncompletion(nil, queryError)
                        return
                    }

                    let activity: [String: Any] = [
                        "user_id": userID,
                        "date": date,
                        "rating": rating,
                        "activity_type": activityType,
                        "units": units,
                        "bonus_multiplier": bonusMultiplier,
                        "points": points,
                        "comment": comment
                    ]

                    oncompletion(activity, nil)
                }
            } else {
                Log.warning("Error Connecting to DB")
                oncompletion(nil, DatabaseError.ConnectionError)
            }
        }
    }

    public func getActivityTypes(oncompletion: @escaping([[String: Any?]]?, Error?) -> Void) {
        let query = Select(from: activityTypes)

        if let connection = self.pool.getConnection() {
            connection.execute(query: query) { result in
                if let activities = result.asRows {
                    let newActivities: [[String: Any?]] = activities.map{
                        var newActivity = $0
                        if let idData = newActivity["id"] as? Data {
                            newActivity["id"] = uuidString(withData: idData)
                        }
                        return newActivity
                    }
                    oncompletion(newActivities, nil)
                } else if let queryError = result.asError {
                    Log.error("Error: \(queryError)")
                    oncompletion(nil, queryError)
                } else {
                    Log.error("No data")
                    oncompletion(nil, DatabaseError.NoData)
                }
            }
        } else {
            Log.warning("Error Connecting to DB")
            oncompletion(nil, DatabaseError.ConnectionError)
        }
    }

    private func getActivityType(byID id: String, oncompletion: @escaping([String: Any?]?, Error?) -> Void) {
        let query = "SELECT * FROM activity_types WHERE id = '\(id)'::uuid"

        if let connection = self.pool.getConnection() {
            connection.execute(query) { result in
                if let rows = result.asRows {
                    oncompletion(rows[0], nil)
                } else if let queryError = result.asError {
                    Log.error("Error: \(queryError)")
                    oncompletion(nil, queryError)
                } else {
                    Log.error("No data")
                    oncompletion(nil, DatabaseError.NoData)
                }
            }
        } else {
            Log.warning("Error Connecting to DB")
            oncompletion(nil, DatabaseError.ConnectionError)
        }
    }
}
