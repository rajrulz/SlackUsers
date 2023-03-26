//
//  UIView+Extension.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 22/03/23.
//

import Foundation
import UIKit

extension UIView {
    func addAutoLayoutSubView(_ view: UIView) {
        addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
    }
}

enum Spacing {
    static let vSmall: CGFloat = 4
    static let medium: CGFloat = 16
    static let small: CGFloat = 8
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
    static let xxLarge: CGFloat = 64
}

class PaddedTextField: UITextField {

    let padding: UIEdgeInsets

    init(edgeInsets: UIEdgeInsets) {
        self.padding = edgeInsets
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }

    override open func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }

    override open func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
}
