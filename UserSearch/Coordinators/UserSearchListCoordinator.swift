//
//  UserSearchListCoordinator.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 21/03/23.
//
import Combine
import Foundation
import UIKit

final class UserSearchListCoordinator: Coordinator<Void> {

    private let navigationController : UINavigationController

    private let dataSource: UsersDataSource

    private let viewController: UserSearchListViewController

    private let sharedPreferences: any KeyValueStore<[String]>

    private var cancellableSubscribers: Set<AnyCancellable> = []

    init(navigationController: UINavigationController,
         userDataSource: UsersDataSource =
         UsersDataSourceRepository(userSearchService: UserSearchNetworkServiceClient(),
                                   userSearchDBService: UserSearchCoreDataService()),
         keyValueStore: some KeyValueStore<[String]> = KeyValuePreferenceStore<[String]>()) {
        self.navigationController = navigationController
        self.dataSource = userDataSource
        self.viewController = .init(model: .init(screenTitle: "Search Slack Users",
                                                 pageSize: Configuration.pageSize,
                                                 debounceInterval: Configuration.searchWaitTimeInMilliSeconds))
        self.sharedPreferences = keyValueStore
    }

    override func start() {
        viewController.model.deniedSearchTexts = populateDenyList()
        viewController.viewDelegate = self
        viewController.coordinator = self
        viewController.model.userCells.removeAll()
        navigationController.pushViewController(viewController, animated: true)
    }

    func populateDenyList() -> Set<String> {
        if let denyList = sharedPreferences.value(forKey: SharedPrefereces.Keys.denyList) {
            return Set(denyList)
        } else {
            // read from file
            guard let filePath = Bundle.main.path(forResource: "denylist", ofType: "txt"),
                  let data = try? Data(contentsOf: URL(filePath: filePath)),
                  let fileContentStr = String(data: data, encoding: .utf8) else {
                return []
            }
            let denyList = fileContentStr.components(separatedBy: "\n").compactMap {
                let str = String($0)
                return str.isEmpty ? nil : str
            }

            sharedPreferences.set(value: denyList, forKey: SharedPrefereces.Keys.denyList)
            return Set(denyList)
        }
    }
}


extension UserSearchListCoordinator: UserSearchListViewControllerDelegate {
    /// Loads data from DataSource
    /// - Parameters:
    ///   - text: <#text description#>
    ///   - sender: <#sender description#>
    func didEnterText(_ text: String, sender: UITextField?) {
        if text.isEmpty {
            viewController.model.userCells = []
            return
        }
        viewController.model.viewState = .loading
        viewController.model.userCells = []

        dataSource.loadDataFor(searchedText: text, pageOffset: 0, pageSize: Configuration.pageSize)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }) { [weak self] users in
                let newUserCells = users.map { UserSearchListTableViewCell.Model(userInfo: $0) }
                self?.preLoadImages(forNewCellModels: newUserCells, atPageOffset: 0)
                self?.viewController.model.userCells = newUserCells
                self?.viewController.model.viewState = users.isEmpty ? .loadedWithZeroRecords : .loadedWithSuccess
                print("received from network \(users)")
            }.store(in: &cancellableSubscribers)
    }


    /// Loads data for new page offset which is about to be shown. And this delegate method is called when user scrolled to last.
    ///
    /// **Pagination implementation**
    /// This method only fetches the data from datasource's persistence store as the data is already downloaded when user wrote the search text.
    /// - Parameters:
    ///   - pageOffset: new page offset
    ///   - searchedText: search controller text
    ///   - sender: delegate's sender
    func loadDataFor(searchedText: String, pageOffset: Int, pageSize: Int, sender: UIViewController?) {
        if searchedText.isEmpty {
            viewController.model.userCells = []
            return
        }

        dataSource.loadDataFor(searchedText: searchedText, pageOffset: pageOffset, pageSize: pageSize)
            .sink(receiveCompletion: { _ in }) { [weak self] users in
                guard let self = self else { return }
                var model = self.viewController.model
                let newUserCells = users.map { UserSearchListTableViewCell.Model(userInfo: $0) }
                self.preLoadImages(forNewCellModels: newUserCells, atPageOffset: pageOffset)
                model.userCells = model.userCells + newUserCells
                self.viewController.model = model
            }.store(in: &cancellableSubscribers)
        
    }


    /// Loads the profile image either from DB or from network
    /// - Parameters:
    ///   - cellModels: cell models for which avatar image is to be loaded
    ///   - pageOffset: page offset of cell Models
    private func preLoadImages(forNewCellModels cellModels: [UserSearchListTableViewCell.Model], atPageOffset pageOffset: Int) {
        for (index, newUserCell) in cellModels.enumerated() {

            let newCellIndexPath = IndexPath(row: index + pageOffset * 20, section: 0)

            dataSource.image(fromUrl: newUserCell.avatarUrl)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }) { [weak self] avatar in
                    guard let self = self else { return }
                    guard newCellIndexPath.row < self.viewController.model.userCells.count else {
                        return
                    }
                    self.viewController.model.userCells[newCellIndexPath.row].avatarImage = avatar.image
                }.store(in: &cancellableSubscribers)
        }
    }
}
