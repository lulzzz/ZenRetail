//
//  Device.swift
//  Webretail
//
//  Created by Gerardo Grisolini on 11/04/17.
//
//

import Foundation
import PostgresNIO
import ZenPostgres


class Device: PostgresTable, Codable {
	
	public var deviceId : Int = 0
	public var idStore : Int = 0
	public var deviceName : String = ""
	public var deviceToken : String = ""
	public var deviceCreated : Int = Int.now()
	public var deviceUpdated : Int = Int.now()
	
	public var _store: Store = Store()

    private enum CodingKeys: String, CodingKey {
        case deviceId
        case deviceName
        case deviceToken
        case _store = "store"
        case deviceUpdated = "updatedAt"
    }

    required init() {
        super.init()
        self.tableIndexes.append("deviceId")
        self.tableIndexes.append("deviceName")
    }
    
    override func decode(row: PostgresRow) {
        deviceId = row.column("deviceId")?.int ?? 0
        idStore = row.column("idStore")?.int ?? 0
        deviceName = row.column("deviceName")?.string ?? ""
        deviceToken = row.column("deviceToken")?.string ?? ""
        deviceCreated = row.column("deviceCreated")?.int ?? 0
        deviceUpdated = row.column("deviceUpdated")?.int ?? 0
        if idStore > 0 {
            _store.decode(row: row)
        }
    }
	
	/// Performs a find on supplied deviceToken
	func get(token: String, name: String) -> EventLoopFuture<Void> {
        let sql = querySQL(
            whereclause: "deviceToken = $1 AND deviceName = $2",
            params: [token, name],
            cursor: Cursor(limit: 1, offset: 0)
        )
        
        return sqlRowsAsync(sql).flatMap { rows -> EventLoopFuture<Void> in
            if let row = rows.first {
                self.decode(row: row)
                return self.connection!.eventLoop.future()
            } else {
                self.deviceName = name
                self.deviceToken = token
                return self.save().map { id -> Void in
                    self.deviceId = id as! Int
                }
            }
        }
	}
}
