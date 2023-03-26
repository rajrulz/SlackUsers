//
//  UserSearchTests.swift
//  UserSearchTests
//
//  Created by Rajneesh Biswal on 21/03/23.
//

import Combine
import XCTest
@testable import UserSearch

class MockURLProtocol: URLProtocol {
    enum MockDataError: Error {
        case badRequestFile(URL)
        case badData(Data?)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        do {
            let (response, data) = try mockReponse(forRequest: request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    private func mockReponse(forRequest request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let url = request.url!
        let jsonFileName = url.pathComponents.last
        let testBundle = Bundle(for: type(of: self))
        guard let path = testBundle.path(forResource: jsonFileName, ofType: "json") else {
            throw MockDataError.badRequestFile(url)
        }
        let jsonData = try Data(contentsOf: URL(fileURLWithPath: path))
        return (HTTPURLResponse(), jsonData)
    }

    override func stopLoading() {
    }
}

final class UserSearchTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    private var cancellableSubscriptions: Set<AnyCancellable> = []
    func testCommonNetworkService() throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)
        let networkService: NetworkService = HttpNetworkService(session: urlSession)
        let endpoint = NetworkRequest(baseURL: "http://MockResponse")
        let expectation = XCTestExpectation(description: "return mocked response present in project bundle")
        networkService.makeNetworkRequest(endpoint, responseType: UserListResponse.self)
            .sink(receiveCompletion: { _ in }) { userListResponse in
                expectation.fulfill()
            }.store(in: &cancellableSubscriptions)
        wait(for: [expectation], timeout: 30)
    }
    
    func test_IncorrectURLInNetworkService() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)
        let networkService: NetworkService = HttpNetworkService(session: urlSession)
        let endpoint = NetworkRequest(baseURL: "xyz")
        let expectation = XCTestExpectation(description: "return mocked response present in project bundle")
        networkService.makeNetworkRequest(endpoint, responseType: UserListResponse.self)
            .sink(receiveCompletion: { result in
                switch result {
                case .failure(let error):
                    print("error occured \(error)")
                    expectation.fulfill()
                case .finished:
                    fatalError("should not be executed")
                }
            }) { userListResponse in
                expectation.fulfill()
            }.store(in: &cancellableSubscriptions)
        wait(for: [expectation], timeout: 30)

    }
}
