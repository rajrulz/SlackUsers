//
//  UIFont+Extension.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 22/03/23.
//

import Foundation
import UIKit

extension UIFont {
    static func latoRegular(ofSize size: CGFloat) -> UIFont {
        UIFont(name: "Lato-Regular", size: size) ?? .systemFont(ofSize: size)
    }

    static func latoBold(ofSize size: CGFloat) -> UIFont {
        UIFont(name: "Lato-Bold", size: size) ?? .boldSystemFont(ofSize: size)
    }
}
