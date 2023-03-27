//
//  UserSearchDataStorageServiceTests.swift
//  UserSearchTests
//
//  Created by Rajneesh Biswal on 27/03/23.
//

import Foundation
import CoreData
import XCTest
@testable import UserSearch

class MockPersistentContainerProvider: PersistentContainerProvider {
    lazy public var persistentContainer: NSPersistentContainer = {
        let description = NSPersistentStoreDescription()
        description.url = URL(fileURLWithPath: "/dev/null")
        let container = NSPersistentContainer(name: "UserSearch")
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
}
class UserSearchDataStorageServiceTests: XCTestCase {

    private var mockContainerProvider: PersistentContainerProvider = MockPersistentContainerProvider()

    private lazy var dataStorageService: UserSearchDataStorageService = UserSearchCoreDataService(coreDataStack: mockContainerProvider)

    func test_CoreDataBatchInsertAndFetchUsers() {
        var users: [Model.User] = []
        for i in 0..<20000 {
            users.append(Model.User(avatarURL: "http://xyz",
                                    displayName: "Display\(i)",
                                    id: i,
                                    userName: "display\(i)"))
        }
        
        let expectation = XCTestExpectation(description: "20000 users must be inserted")
        dataStorageService.batchInsertUsers(users) { [weak self] error in
            guard let self = self else { return }
            if error == nil {
                let fetchedObjects = try? self.dataStorageService.fetchUsersWithDisplayAndUserName(startingWith: "display", pageOffset: 0, pageSize: 20000)
                XCTAssertNotNil(fetchedObjects)
                XCTAssertTrue(fetchedObjects!.count == 20000)
                expectation.fulfill()
            } else {
                fatalError("error occured while batch insertion")
            }
        }
        wait(for: [expectation], timeout: 30)
        
    }

    func test_CoreDataInsertAndFetchAvatarImage() {
        let avatar = Model.Avatar(url: "http://xyz", image: Data())
        let expectation = XCTestExpectation(description: "Avatar image must be inserted")
        
        dataStorageService.saveUserImageInfo(avatar) { [weak self] error in
            guard let self = self else { return }
            if error == nil {
                let avatarImage = try? self.dataStorageService.getUserImageInfo("http://xyz")
                XCTAssertNotNil(avatarImage?.url)
                expectation.fulfill()
            } else {
                fatalError("error while saving avatar image")
            }
        }
        wait(for: [expectation], timeout: 30)
    }
}

