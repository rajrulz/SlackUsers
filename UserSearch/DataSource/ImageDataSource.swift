//
//  ImageDataSource.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 27/03/23.
//

import Combine
import CoreData
import Foundation

public protocol UserImageDataSource {
    func image(fromUrl url: String) -> AnyPublisher<Model.Avatar, Error>
}

public final class UserImageDataSourceRepository: UserImageDataSource {

    private let userSearchDBService: UserSearchDataStorageService

    private let userSearchNetworkService: UserSearchNetworkService

    init(userSearchService: UserSearchNetworkService = UserSearchNetworkServiceClient(),
         userSearchDBService: UserSearchDataStorageService = UserSearchCoreDataService()) {
        self.userSearchNetworkService = userSearchService
        self.userSearchDBService = userSearchDBService
    }

    /// Checks is image is available in DB then fetches from DB else fetched from network
    /// - Parameter url: remote image url
    /// - Returns: returns publisher of `Avatar` model or error
    public func image(fromUrl url: String) -> AnyPublisher<Model.Avatar, Error> {
        if let avatar = self.fetchImageFromDB(withUrl: url) {
            return Result<Model.Avatar, Error>.success(avatar).publisher.eraseToAnyPublisher()
        } else {
            return fetchRemoteImageFrom(url: url)
        }
    }

    /// Fetches image binary data from DB
    /// - Parameter url: remote url of image
    /// - Returns: `Avatar` model
    private func fetchImageFromDB(withUrl url: String) -> Model.Avatar? {
        do {
            let avatar = try userSearchDBService.getUserImageInfo(url)
            return avatar == nil ? nil : .init(url: avatar?.url ?? "", image: avatar?.image ?? Data())
        } catch {
            print("Error: \(error) occured while fetching image from db")
            return nil
        }
    }
    
    /// Fetches image from network
    /// - Parameter url: remote url of image
    /// - Returns: `Avatar` model
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
