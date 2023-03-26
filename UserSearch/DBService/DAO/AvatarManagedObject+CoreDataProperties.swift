//
//  AvatarManagedObject+CoreDataProperties.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 26/03/23.
//
//

import Foundation
import CoreData


extension AvatarManagedObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AvatarManagedObject> {
        return NSFetchRequest<AvatarManagedObject>(entityName: "Avatar")
    }

    @NSManaged public var image: Data?
    @NSManaged public var url: String

}

extension AvatarManagedObject : Identifiable {
    static var entityName: String {
        "Avatar"
    }
}
