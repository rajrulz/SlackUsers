//
//  Config.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 22/03/23.
//

import Foundation

enum Configuration {

    //pageSize of search results
    static let pageSize: Int = 20

    //wait time after every key stroke while searching user name
    static let searchWaitTimeInMilliSeconds: Int = 500
}

enum SharedPrefereces {
    enum Keys {
        static let denyList = "denyList"
    }
}
