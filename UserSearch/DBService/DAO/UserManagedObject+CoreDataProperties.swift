//
//  UserManagedObject+CoreDataProperties.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 26/03/23.
//
//

import Foundation
import CoreData


extension UserManagedObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserManagedObject> {
        return NSFetchRequest<UserManagedObject>(entityName: "User")
    }

    @NSManaged public var avatarURL: String?
    @NSManaged public var displayName: String?
    @NSManaged public var id: Int16
    @NSManaged public var userName: String?

}

extension UserManagedObject : Identifiable {
    static var entityName: String {
        "User"
    }
}
