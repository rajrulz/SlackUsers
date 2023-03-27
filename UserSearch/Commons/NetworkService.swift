//
//  Networking.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 22/03/23.
//

import Foundation
import Combine

enum EndpointError: Error {
    case incorrectURL(urlStr: String)
}

public enum HTTPMethod: String {
    case post
    case get
}

public struct NetworkRequest: Endpoint {
    public var baseURL: String
    public var method: HTTPMethod = .get
    public var headers: [String : String]?
    public var body: Data?
    public var queryParams: [String : String]?
}

public protocol Endpoint {
    //MARK: required Params
    var baseURL: String { get }
    var method: HTTPMethod { get }

    //MARK: optional Params
    var headers: [String: String]? { get }
    var body: Data? { get }
    var queryParams: [String: String]? { get }
}

extension Endpoint {
    public func createURLRequest() -> URLRequest? {
        guard var urlComponents = URLComponents(string: baseURL) else {
            return nil
        }
        if let queryPararms = queryParams {
            var queryItems: [URLQueryItem] = []
            queryPararms.forEach { queryItems.append(.init(name: $0, value: $1)) }
            urlComponents.queryItems = queryItems
        }
        var request = URLRequest(url: urlComponents.url!)
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpMethod = self.method.rawValue.uppercased()
        request.httpBody = body
        request.timeoutInterval = Configuration.networkTimeOutIntervalInSeconds
        return request
    }
}

enum NetworkingError: Error {
    case responseDataNotFound
    case parsingFailure
}

public protocol NetworkService {
    func makeNetworkRequest<RequestEndpoint: Endpoint, Response: Decodable>(
        _ endpoint: RequestEndpoint, responseType: Response.Type) -> AnyPublisher<Response, Error>
}

final public class HttpNetworkService: NetworkService {

    private var session: URLSession

    public init(session: URLSession = URLSession.shared) {
        self.session = session
    }
    
    public func makeNetworkRequest<RequestEndpoint: Endpoint, Response: Decodable>(
        _ endpoint: RequestEndpoint, responseType: Response.Type) -> AnyPublisher<Response, Error> {

        guard let request = endpoint.createURLRequest() else {
            return Fail(error: EndpointError.incorrectURL(urlStr: endpoint.baseURL))
                    .eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: request)
                .compactMap { $0.data }
                .mapError { $0 as Error }
                .decode(type: responseType, decoder: JSONDecoder())
                .eraseToAnyPublisher()
    }
}
