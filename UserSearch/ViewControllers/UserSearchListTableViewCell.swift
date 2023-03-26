//
//  UserSearchListTableViewCell.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 22/03/23.
//
import Combine
import Foundation
import UIKit

class UserSearchListTableViewCell: UITableViewCell {

    static let identifier: String = "\(UserSearchListTableViewCell.self)"

    var model: Model {
        didSet {
            applyModel()
        }
    }

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .latoBold(ofSize: 16)
        label.textColor = .init(rgb: 0x1D1C1D)
        return label
    }()

    private let userNameLabel: UILabel = {
        let label = UILabel()
        label.font = .latoRegular(ofSize: 16)
        label.textColor = .init(rgb: 0x616061)
        return label

    }()

    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 4
        imageView.layer.masksToBounds = true
        return imageView
    }()

    private let userInfoHStack: UIStackView = {
        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.alignment = .center
        return hStack
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .init(rgb: 0xDDDDDD)
        return view
    }()

    private var cancellableSubscriptions: Set<AnyCancellable> = []
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        self.model = .init()
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUpViews()
        applyModel()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpViews() {
        userInfoHStack.addArrangedSubview(avatarImageView)
        userInfoHStack.setCustomSpacing(Spacing.small + Spacing.small/2, after: avatarImageView)

        userInfoHStack.addArrangedSubview(nameLabel)
        userInfoHStack.setCustomSpacing(Spacing.small, after: nameLabel)

        userInfoHStack.addArrangedSubview(userNameLabel)
        userInfoHStack.addArrangedSubview(UIView())

        contentView.addAutoLayoutSubView(userInfoHStack)
        contentView.addAutoLayoutSubView(separatorView)
        
        contentView.backgroundColor = .white
        setUpViewConstraints()
    }

    private func setUpViewConstraints() {
        NSLayoutConstraint.activate([
            avatarImageView.widthAnchor.constraint(equalToConstant: 28),
            avatarImageView.heightAnchor.constraint(equalToConstant: 28),

            userInfoHStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.medium),
            userInfoHStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.medium),
            userInfoHStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.small),
            userInfoHStack.bottomAnchor.constraint(equalTo: separatorView.topAnchor, constant: -Spacing.small),

            separatorView.leadingAnchor.constraint(equalTo: userInfoHStack.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    private func applyModel() {
        avatarImageView.image = UIImage(data: model.avatarImage ?? Data())
        nameLabel.text = model.name
        userNameLabel.text = model.userName
    }

}

extension UserSearchListTableViewCell {
    struct Model: Hashable, Comparable, Equatable {
        var avatarUrl: String = ""
        var name: String = ""
        var userName: String = ""
        var id: Int = 0

        var avatarImage: Data? = nil
        static func == (lhs: UserSearchListTableViewCell.Model, rhs: UserSearchListTableViewCell.Model) -> Bool {
            lhs.id == rhs.id
        }

        static func < (lhs: UserSearchListTableViewCell.Model, rhs: UserSearchListTableViewCell.Model) -> Bool {
            lhs.name < rhs.name
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

}

extension UserSearchListTableViewCell.Model {
    init(userInfo: Model.User) {
        self.init(avatarUrl: userInfo.avatarURL ,
                  name: userInfo.displayName ,
                  userName: userInfo.userName ,
                  id: userInfo.id)
    }
}
