//
//  PersistentContainerProvider.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 27/03/23.
//

import Foundation
import CoreData

public protocol PersistentContainerProvider {
    var persistentContainer: NSPersistentContainer { get }
}

final class CoreDataStack: PersistentContainerProvider {
    lazy public var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "UserSearch")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
}
