//
//  UserSearchNetworkService.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 21/03/23.
//

import Combine
import Foundation

protocol UserSearchNetworkService {
    func fetchUsers(forSearchedText text: String) -> AnyPublisher<UserListResponse, Error>

    func fetchUserImage(from url: String) -> AnyPublisher<Data, Error>
}

final class UserSearchNetworkServiceClient: UserSearchNetworkService {
    private let networkService: NetworkService

    private let baseURL: String = "https://slack-users.herokuapp.com/search"

    init(networkService: NetworkService = HttpNetworkService()) {
        self.networkService = networkService
    }

    func fetchUsers(forSearchedText text: String) -> AnyPublisher<UserListResponse, Error> {
        let request = NetworkRequest(baseURL: baseURL,
                                     queryParams: ["query": text])

        return networkService.makeNetworkRequest(request, responseType: UserListResponse.self)
    }

    func fetchUserImage(from url: String) -> AnyPublisher<Data, Error> {
        Future<Data, Error> { promise in
            DispatchQueue.global(qos: .utility).async {
                guard let url = URL(string: url),
                      let data = try? Data(contentsOf: url) else {
                    promise(.failure(NSError(domain: "incorrect url", code: 400)))
                    return
                }
                promise(.success(data))
            }
        }.eraseToAnyPublisher()
    }
}
