//
//  UsersDataSource.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 22/03/23.
//

import Foundation
import Combine
import CoreData

public protocol UsersPersistentDataSource {
    func loadSavedDataFor(searchedText: String, pageOffset: Int, pageSize: Int) -> AnyPublisher<[Model.User], Error>
}

public protocol UsersRemoteDataSource {
    func loadDataFor(searchedText: String, pageOffset: Int, pageSize: Int) -> AnyPublisher<[Model.User], Error>
}

//MARK: Repository pattern
/// This class fetches Data required by Coordinator to populate the view model either from SQLite or BE via API Call.
final public class UsersDataSourceRepository: UsersPersistentDataSource, UsersRemoteDataSource  {

    private let userSearchDBService: UserSearchDataStorageService

    private let userSearchNetworkService: UserSearchNetworkService

    init(userSearchService: UserSearchNetworkService = UserSearchNetworkServiceClient(),
         userSearchDBService: UserSearchDataStorageService = UserSearchCoreDataService()) {
        self.userSearchNetworkService = userSearchService
        self.userSearchDBService = userSearchDBService
    }
    
    /// Fetches user with name prefixed with `text` from Sqllite cache.
    ///
    /// if pageOffset is 0 fetches for first batch of 20 i.e `page size` records.
    /// similarly fetches next 20 records on subsequent calls with same search text and incrementing page offset.
    /// - Parameters:
    ///   - text: searched text
    ///   - pageOffset: page index (starts with 0)
    ///   - pageSize: `Configuration.pageSize`
    /// - Returns: either Array of userInfo or error
    private func fetchUsersFromDBWithName(startingWith text: String,
                                         pageOffset: Int = 0,
                                         pageSize: Int = Configuration.pageSize) -> Result<[Model.User], Error> {
        do {
            let userManagedObjects = try userSearchDBService.fetchUsersWithDisplayAndUserName(startingWith: text,
                                                                                pageOffset: pageOffset,
                                                                                pageSize: pageSize)
            
            return .success(userManagedObjects.map {
                .init(avatarURL: $0.avatarURL ?? "",
                      displayName: $0.displayName ?? "",
                      id: Int($0.id),
                      userName: $0.userName ?? "")
            })
        } catch {
            return .failure(error)
        }
    }

    /// Fetches list of UserInfo having display name prefixed with searched text from persistent store.
    /// - Parameter searchedText: text that is searched by user
    /// - Parameter pageOffset: page offset of the table view
    /// - Parameter pageSize: count of cells in 1 page. `Configuration.PageSize`
    /// - Returns: returns publisher of `User` model or `error`
    public func loadSavedDataFor(searchedText: String, pageOffset: Int, pageSize: Int) -> AnyPublisher<[Model.User], Error> {
        return fetchUsersFromDBWithName(startingWith: searchedText, pageOffset: pageOffset, pageSize: pageSize)
                .publisher
                .eraseToAnyPublisher()
    }

    /// checks if searched text is empty then fetches the records from DB. else
    /// checks for pageOffset if 0 then fetches from network else from DB
    /// - Parameter searchedText: text that is searched by user
    /// - Parameter pageOffset: page offset of the table view
    /// - Parameter pageSize: count of cells in 1 page. `Configuration.PageSize`
    /// - Returns: returns publisher of `User` model or `error`
    public func loadDataFor(searchedText: String, pageOffset: Int, pageSize: Int) -> AnyPublisher<[Model.User], Error> {
        if searchedText.isEmpty || (!searchedText.isEmpty && pageOffset != 0) {
            return fetchUsersFromDBWithName(startingWith: searchedText, pageOffset: pageOffset, pageSize: pageSize)
                    .publisher
                    .eraseToAnyPublisher()
        } else {
            return fetchUsersFromAPIWhoseName(startsWith: searchedText)
        }
    }
    
    /// Fetches list of UserInfo having display name prefixed with searched text from BE via API Call.
    /// - Parameters:
    ///   - text: searched text
    ///   - completionHandler: async block returns `Result<[UserInfo], Error>`
    private func fetchUsersFromAPIWhoseName(startsWith text: String) -> AnyPublisher<[Model.User], Error>  {
        
        userSearchNetworkService.fetchUsers(forSearchedText: text)
            .compactMap { $0.users }
            .mapError { $0 as Error }
            .flatMap { [weak self] users -> AnyPublisher<[Model.User], Error> in
                var userModels: [Model.User] = []
                for user in users {
                    userModels.append(.init(avatarURL: user.avatarURL ?? "",
                                            displayName: user.displayName ?? "",
                                            id: user.id ?? 0,
                                            userName: user.userName ?? ""))
                }

                return Future<[Model.User], Error> { [weak self] promise in
                    guard let self = self else { return }
                    self.userSearchDBService.batchInsertUsers(userModels,
                                                              completionHandler: { error in
                        guard error == nil else {
                            promise(.failure(error!))
                            return
                        }
                        promise(self.fetchUsersFromDBWithName(startingWith: text, pageOffset: 0))
                    })
                }.eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

}
