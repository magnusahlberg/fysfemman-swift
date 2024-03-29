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
import SwiftyJSON

class ActivitiesTable : Table {
    let tableName = "activities"
    let id = Column("id")
    let userId = Column("user_id")
    let date = Column("date")
    let rating = Column("rating")
    let activityTypeId = Column("activity_type_id")
    let units = Column("units")
    let bonusMultiplier = Column("bonus_multiplier")
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
    private let users = UsersTable()

    public func get(withUserID userID: String, oncompletion: @escaping([[String: Any?]]?, Error?) -> Void) {

        let query = Select(
                        activities.id,
                        activityTypes.name,
                        activities.units,
                        activityTypes.unit,
                        activities.bonusMultiplier,
                        activities.points,
                        activities.rating,
                        activities.comment,
                        RawField("to_char(date, 'YYYY-MM-DD') as date"),
                        from: activities)
            .leftJoin(activityTypes)
            .on(activities.activityTypeId == activityTypes.id)
            .where(activities.userId == Parameter())
            .order(by: .DESC(activities.date), .DESC(activities.registered_date))

        if let connection = self.pool.getConnection() {
            connection.execute(query: query, parameters: [userID]) { result in
                if let rows = result.asRows {
                   let activities: [[String: Any?]] = rows.map {
                        var activity = $0
                        activity["bonus_multiplier"] = Int($0["bonus_multiplier"] as? Int32 ?? 0)
                        activity["rating"] = Int($0["rating"] as? Int32 ?? 0)
                        return activity
                    }
                    oncompletion(activities, nil)
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

    public func getAll(oncompletion: @escaping([[String:Any?]]?, Error?) -> Void) {

        let query = Select(
            activities.id,
            users.name.as("user"),
            RawField("to_char(date, 'YYYY-MM-DD') as date"),
            activities.rating,
            activityTypes.name,
            activities.units,
            activityTypes.unit,
            activities.bonusMultiplier,
            activities.points,
            activities.comment,
            from: activities
            )
        .leftJoin(activityTypes)
        .on(activities.activityTypeId == activityTypes.id)
        .leftJoin(users)
        .on(activities.userId == users.id)
        .order(by: .ASC(activities.date), .ASC(activities.registered_date))

        if let connection = self.pool.getConnection() {
            connection.execute(query: query) { result in
                if let rows = result.asRows {
                    let activities: [[String: Any?]] = rows.map {
                        var activity = $0
                        activity["bonus_multiplier"] = Int($0["bonus_multiplier"] as? Int32 ?? 0)
                        activity["rating"] = Int($0["rating"] as? Int32 ?? 0)
                        return activity
                    }
                    Log.info(String(describing: activities))
                    oncompletion(activities, nil)
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

    public func add(userID: String, date: String, rating: Int, activityType: String, units: Double, bonusMultiplier: Int, comment: String = "", oncompletion: @escaping([String: Any]?, Error?) -> Void) {

        getActivityType(byID: activityType) { activityTypeResult, error in
            let points: Double

            guard
                let activityTypeResult = activityTypeResult,
                let multiplier = activityTypeResult["multiplier"] as? Double,
                let name = activityTypeResult["name"] as? String,
                let unit = activityTypeResult["unit"] as? String
            else {
                Log.error("No activity for multiplier found")
                return
            }

            points = (units * multiplier * (Double(bonusMultiplier) / 100.0 + 1) * 1000).rounded() / 1000

            let query = Insert(into: self.activities,
                               columns: [
                                  self.activities.userId,
                                  self.activities.date,
                                  self.activities.rating,
                                  self.activities.activityTypeId,
                                  self.activities.units,
                                  self.activities.bonusMultiplier,
                                  self.activities.points,
                                  self.activities.comment
                               ],
                               values: [Parameter(), Parameter(), Parameter(), Parameter(), Parameter(), Parameter(), Parameter(), Parameter()]
                        )
                .suffix("RETURNING id")


            if let connection = self.pool.getConnection() {
                connection.execute(query: query, parameters: [userID, date, rating, activityType, units, bonusMultiplier, points, comment]) { result in

                    if let queryError = result.asError {
                        Log.error("Error: \(queryError)")
                        oncompletion(nil, queryError)
                        return
                    }

                    guard
                        let rows = result.asRows,
                        let row = rows.first,
                        let activityId = row["id"] as? String
                    else {
                        oncompletion(nil, DatabaseError.NoData)
                        return
                    }
                    let activity: [String: Any] = [
                        "id": activityId,
                        "name": name,
                        "units": units,
                        "unit": unit,
                        "bonus_multiplier": bonusMultiplier,
                        "points": points,
                        "rating": rating,
                        "comment": comment,
                        "date": date
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
            .order(by: .ASC(activityTypes.name))

        if let connection = self.pool.getConnection() {
            connection.execute(query: query) { result in
                if let activities = result.asRows {
                    oncompletion(activities, nil)
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
        let query = Select(from: activityTypes)
            .where(activityTypes.id == Parameter())

        if let connection = self.pool.getConnection() {
            connection.execute(query: query, parameters: [id]) { result in
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

    public func sendActivity(userName: String, activityName: String, units: String, unit: String, points: String) {

        let url = URL(string: "https://hooks.slack.com/services/")!

        var request: URLRequest = URLRequest(url: url)
        request.httpMethod = "POST"

        let jsonString = "{\"text\": \"\(userName) har tränat! \(activityName), \(units) \(unit). Ökar med \(points) poäng.\"}"
        Log.info(jsonString)
        request.httpBody = jsonString.data(using: .utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let task = URLSession(configuration: URLSessionConfiguration.default).dataTask(with: request) { data, response, error in
            guard let data = data else {
                Log.error("No data received")
                return
            }
            let json = JSON(data)
            Log.info(json.debugDescription)
        }
        task.resume()
    }

}
