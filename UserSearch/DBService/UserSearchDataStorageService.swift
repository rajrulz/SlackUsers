//
//  UserSearchDataSource.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 22/03/23.
//

import Foundation
import CoreData

public protocol UserSearchDataStorageService {

    func fetchUsersWithDisplayAndUserName(startingWith text: String,
                            pageOffset: Int,
                            pageSize: Int) throws -> [UserManagedObject]

    func batchInsertUsers(_ users: [Model.User],
                          completionHandler: @escaping (Error?) -> Void )

    func saveUserImageInfo(_ imageInfo: Model.Avatar,
                           completionHandler: @escaping (Error?) -> Void)

    func getUserImageInfo(_ url: String) throws -> AvatarManagedObject?
}

class UserSearchCoreDataService: UserSearchDataStorageService {

    //lazily load mainManagedObjectContext as it depends on lazy loading of persistentContainer
    lazy var mainManagedObjectContext = {
        self.persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        return self.persistentContainer.viewContext
    }()

    private let persistentContainer: NSPersistentContainer

    init(coreDataStack: PersistentContainerProvider = CoreDataStack()) {
        self.persistentContainer = coreDataStack.persistentContainer
    }

    public func fetchUsersWithDisplayAndUserName(startingWith text: String,
                            pageOffset: Int,
                            pageSize: Int) throws -> [UserManagedObject] {
        let fetchRequest = UserManagedObject.fetchRequest()
        fetchRequest.fetchLimit = pageSize
        fetchRequest.fetchOffset = pageOffset * pageSize
        if !text.isEmpty {
            let displayNamePrefixPredicate = NSPredicate(format: "%K BEGINSWITH[c] %@",
                                                         #keyPath(UserManagedObject.displayName), text.lowercased())
            let userNamePrefixPredicate = NSPredicate(format: "%K BEGINSWITH[c] %@",
                                                      #keyPath(UserManagedObject.userName), text.lowercased())
            fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [displayNamePrefixPredicate, userNamePrefixPredicate])
        }
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \UserManagedObject.displayName , ascending: true),
                                        NSSortDescriptor(keyPath: \UserManagedObject.userName, ascending: true)]

        let users = try mainManagedObjectContext.fetch(fetchRequest)
        return users
    }

    private func createBatchInsertRequest(forUsers users: [Model.User], in context: NSManagedObjectContext) -> NSBatchInsertRequest {
        let totalCount = users.count
        var index  = 0
        return NSBatchInsertRequest(entity: .entity(forEntityName: UserManagedObject.entityName, in: context)!, managedObjectHandler: { managedObject in
            guard index < totalCount else { return true }
            
            let user = users[index]
            if let userManagedObject = managedObject as? UserManagedObject {
                userManagedObject.userName = user.userName
                userManagedObject.id = Int32(user.id)
                userManagedObject.displayName = user.displayName
                userManagedObject.avatarURL = user.avatarURL
            }
            
            index += 1
            return false
        })
    }

    public func batchInsertUsers(_ users: [Model.User], completionHandler: @escaping (Error?) -> Void ) {
        let bgContext = persistentContainer.newBackgroundContext()
        bgContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        bgContext.perform {
            let batchRequest = self.createBatchInsertRequest(forUsers: users, in: bgContext)
            do {
                try bgContext.execute(batchRequest)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    public func saveUserImageInfo(_ imageInfo: Model.Avatar,
                                   completionHandler: @escaping (Error?) -> Void) {

        let bgContext = persistentContainer.newBackgroundContext()
        bgContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        bgContext.perform {
            let avatarManagedObject = AvatarManagedObject(context: bgContext)
            avatarManagedObject.url = imageInfo.url
            avatarManagedObject.image = imageInfo.image
            
            do {
                try bgContext.save()
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    public func getUserImageInfo(_ url: String) throws -> AvatarManagedObject? {
        let fetchRequest = AvatarManagedObject.fetchRequest()
        let imageUrlPredicate = NSPredicate(format: "%K == %@",
                                                      #keyPath(AvatarManagedObject.url), url)
        fetchRequest.predicate = imageUrlPredicate

        let avatars = try mainManagedObjectContext.fetch(fetchRequest)
        guard !avatars.isEmpty else {
            return nil
        }
        return avatars.first!
    }
}
