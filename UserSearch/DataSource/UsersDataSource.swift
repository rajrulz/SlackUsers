//
//  UsersDataSource.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 22/03/23.
//

import Foundation
import Combine
import CoreData

protocol UsersDataSource {
    func loadSavedDataFor(searchedText: String, pageOffset: Int, pageSize: Int) -> AnyPublisher<[Model.User], Error>
    
    func loadDataFor(searchedText: String, pageOffset: Int, pageSize: Int) -> AnyPublisher<[Model.User], Error>

    func image(fromUrl url: String) -> AnyPublisher<Model.Avatar, Error>
}

//MARK: Repository pattern
/// This class fetches UserInfo either from SQLite or BE via API Call.
class UsersDataSourceRepository: UsersDataSource {

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
    public func fetchUsersFromDBWithName(startingWith text: String,
                                         pageOffset: Int = 0,
                                         pageSize: Int = Configuration.pageSize) -> Result<[Model.User], Error> {
        do {
            let userManagedObjects = try userSearchDBService.fetchUsersWithName(startingWith: text,
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

    public func loadSavedDataFor(searchedText: String, pageOffset: Int, pageSize: Int) -> AnyPublisher<[Model.User], Error> {
        return fetchUsersFromDBWithName(startingWith: searchedText, pageOffset: pageOffset, pageSize: pageSize)
                .publisher
                .eraseToAnyPublisher()
    }

    public func loadDataFor(searchedText: String, pageOffset: Int, pageSize: Int) -> AnyPublisher<[Model.User], Error> {
        if searchedText.isEmpty || (!searchedText.isEmpty && pageOffset != 0) {
            return fetchUsersFromDBWithName(startingWith: searchedText, pageOffset: pageOffset, pageSize: pageSize)
                    .publisher
                    .eraseToAnyPublisher()
        } else {
            return fetchUsersFromAPIWhoseName(startsWith: searchedText)
        }
    }

    public func image(fromUrl url: String) -> AnyPublisher<Model.Avatar, Error> {
        if let avatar = self.fetchImageFromDB(withUrl: url) {
            return Result<Model.Avatar, Error>.success(avatar).publisher.eraseToAnyPublisher()
        } else {
            return fetchRemoteImageFrom(url: url)
        }
    }
    
    
    /// Fetches list of UserInfo having display name prefixed with searched text from BE via API Call.
    /// - Parameters:
    ///   - text: searched text
    ///   - completionHandler: async block returns `Result<[UserInfo], Error>`
    public func fetchUsersFromAPIWhoseName(startsWith text: String) -> AnyPublisher<[Model.User], Error>  {
        
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

extension UsersDataSourceRepository {
    private func fetchImageFromDB(withUrl url: String) -> Model.Avatar? {
        do {
            let avatar = try userSearchDBService.getUserImageInfo(url)
            return avatar == nil ? nil : .init(url: avatar?.url ?? "", image: avatar?.image ?? Data())
        } catch {
            print("Error: \(error) occured while fetching image from db")
            return nil
        }
    }

    private func fetchRemoteImageFrom(url: String) -> AnyPublisher<Model.Avatar, Error> {
        userSearchNetworkService.fetchUserImage(from: url)
            .mapError { $0 as Error }
            .flatMap { data  -> AnyPublisher<Model.Avatar, Error> in
                Future<Model.Avatar, Error> { [weak self] promise in
                    guard let self = self else { return }
                    self.userSearchDBService.saveUserImageInfo(.init(url: url, image: data)) { error in
                        guard error == nil else {
                            promise(.failure(error!))
                            return
                        }
                        promise(.success(self.fetchImageFromDB(withUrl: url)!))
                    }
                }.eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

}