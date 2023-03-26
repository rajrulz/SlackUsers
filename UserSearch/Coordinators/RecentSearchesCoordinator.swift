//
//  RecentSearchesCoordinator.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 26/03/23.
//
import Combine
import Foundation
import UIKit

final class RecentSerchesCoordinator: Coordinator<Void> {

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
        self.viewController = .init(model: .init(screenTitle: "Recent Searches",
                                                 isSearchButtonShown: true,
                                                 pageSize: Configuration.pageSize,
                                                 debounceInterval: Configuration.searchWaitTimeInMilliSeconds))
        self.sharedPreferences = keyValueStore
    }

    override func start() {
        loadDataFor(searchedText: "", pageOffset: 0, pageSize: Configuration.pageSize, sender: nil)
        viewController.viewDelegate = self
        viewController.coordinator = self
        navigationController.pushViewController(viewController, animated: true)
    }
}


extension RecentSerchesCoordinator: UserSearchListViewControllerDelegate {

    func didTapOnSearchButton() {
        let coordinator = UserSearchListCoordinator(navigationController: navigationController)
        addChildCoordinator(coordinator)
        coordinator.start()
    }

    /// Loads data from DataSource
    /// - Parameters:
    ///   - text: <#text description#>
    ///   - sender: <#sender description#>
    func didEnterText(_ text: String, sender: UITextField?) {
        viewController.model.userCells = []

        dataSource.loadSavedDataFor(searchedText: text, pageOffset: 0, pageSize: Configuration.pageSize)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }) { [weak self] users in
                let newUserCells = users.map { UserSearchListTableViewCell.Model(userInfo: $0) }
                self?.preLoadImages(forNewCellModels: newUserCells, atPageOffset: 0)
                self?.viewController.model.userCells = newUserCells
                self?.viewController.model.viewState = users.isEmpty ? .loadedWithZeroRecords : .loadedWithSuccess
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
        dataSource.loadSavedDataFor(searchedText: searchedText, pageOffset: pageOffset, pageSize: pageSize)
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
    }}
