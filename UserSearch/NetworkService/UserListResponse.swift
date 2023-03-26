//
//  UserListResponse.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 22/03/23.
//

import Foundation


public struct UserListResponse: Codable {
    let error: String?
    let status: Bool?
    let users: [UserInfo]?

    enum CodingKeys: String, CodingKey {
        case status = "ok"
        case error
        case users
    }

    public struct UserInfo: Codable {
        let avatarURL: String?
        let displayName: String?
        let id: Int?
        let userName: String?

        enum CodingKeys: String, CodingKey {
            case avatarURL = "avatar_url"
            case displayName = "display_name"
            case id
            case userName = "username"
        }
    }
}

public enum Model {
    public struct User {
        let avatarURL: String
        let displayName: String
        let id: Int
        let userName: String
    }

    public struct Avatar {
        let url: String
        let image: Data
    }
}
