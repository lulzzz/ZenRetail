//
//  StoreRepository.swift
//  Webretail
//
//  Created by Gerardo Grisolini on 27/02/17.
//
//

import NIO

struct StoreRepository : StoreProtocol {

    func getAll() -> EventLoopFuture<[Store]> {
        return Store().queryAsync()
    }
    
    func get(id: Int) -> EventLoopFuture<Store> {
        let item = Store()
        return item.getAsync(id).map { () -> Store in
            item
        }
    }
    
    func add(item: Store) -> EventLoopFuture<Int> {
        item.storeCreated = Int.now()
        item.storeUpdated = Int.now()
        return item.saveAsync().map { id -> Int in
            item.storeId = id as! Int
            return item.storeId
        }
    }
    
    func update(id: Int, item: Store) -> EventLoopFuture<Bool> {
        item.storeId = id
        item.storeUpdated = Int.now()
        return item.saveAsync().map { id -> Bool in
            id as! Int > 0
        }
    }
    
    func delete(id: Int) -> EventLoopFuture<Bool> {
        return Store().deleteAsync(id)
    }
}
