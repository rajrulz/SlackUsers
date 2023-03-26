//
//  KeyValuePreferenceStore.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 22/03/23.
//

import Foundation

protocol KeyValueStore<Item> {
    associatedtype Item: Codable
    func set(value: Item, forKey key: String)
    func value(forKey key: String) -> Item?
}

class KeyValuePreferenceStore<Item: Codable>: KeyValueStore {

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func set(value: Item, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    func value(forKey key: String) -> Item? {
        userDefaults.value(forKey: key) as? Item
    }
}
