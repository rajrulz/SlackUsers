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

    private let usersDataSource: UsersRemoteDataSource

    private let imageDataSource: UserImageDataSource

    private let viewController: UserSearchListViewController

    private let sharedPreferences: UserDefaults

    private var denyList: Set<String>!

    private var cancellableSubscribers: Set<AnyCancellable> = []

    init(navigationController: UINavigationController,
         usersSearchNetworkService: UserSearchNetworkService = UserSearchNetworkServiceClient(),
         userSearchDataStorageService: UserSearchDataStorageService = UserSearchCoreDataService(),
         sharedPreferences: UserDefaults = UserDefaults.standard) {

        self.navigationController = navigationController

        self.usersDataSource = UsersDataSourceRepository(userSearchService: usersSearchNetworkService,
                                                         userSearchDBService: userSearchDataStorageService)

        self.imageDataSource = UserImageDataSourceRepository(userSearchService: usersSearchNetworkService,
                                                             userSearchDBService: userSearchDataStorageService)

        self.viewController = .init(model: .init(screenTitle: Constants.ScreenTitle.searchUsers,
                                                 pageSize: Configuration.pageSize,
                                                 debounceInterval: Configuration.searchWaitTimeInMilliSeconds))

        self.sharedPreferences = sharedPreferences
        super.init()

        self.denyList = populateDenyList()

        addObserverToSaveDenyList()
    }

    override func start() {
        viewController.viewDelegate = self
        viewController.coordinator = self
        viewController.model.userCells.removeAll()
        navigationController.pushViewController(viewController, animated: true)
    }

    private func populateDenyList() -> Set<String> {
        if let denyList = sharedPreferences.value(forKey: SharedPrefereces.Keys.denyList) as? [String] {
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

            return Set(denyList)
        }
    }

    private func addObserverToSaveDenyList() {
        NotificationCenter.default.publisher(for:
            UIApplication.willResignActiveNotification)
        .sink { [weak self] _ in
            guard let self = self else { return }
            self.sharedPreferences.set(Array(self.denyList), forKey: SharedPrefereces.Keys.denyList)
        }
        .store(in: &cancellableSubscribers)
    }
}


extension UserSearchListCoordinator: UserSearchListViewControllerDelegate {

    /// Loads data from network and returns first set of page size records
    /// - Parameters:
    ///   - text: searched text
    ///   - sender: sender of delegate
    func didEnterText(_ text: String, sender: UITextField?) {
        
        // check if text is empty.
        // There needs to be some value in search text in order to make API call.
        if text.isEmpty {
            var model = viewController.model
            model.userCells = []
            model.viewState = .loadedWithSuccess
            viewController.model = model
            return
        }

        // check if serched text is not present in denied list.
        if denyList.contains(text.lowercased()) {
            var model = viewController.model
            model.userCells = []
            model.viewState = .loadedWithZeroRecords
            viewController.model = model
            return
        }

        // prepare for api call
        viewController.model.viewState = .loading
        viewController.model.userCells = []

        // make api call
        usersDataSource.loadDataFor(searchedText: text, pageOffset: 0, pageSize: Configuration.pageSize)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                switch result {
                case .failure(let error):
                    self?.viewController.model.viewState = .loadedWithFailure(pageOffset: 0, error: error)
                case .finished:
                    break
                }
            }) { [weak self] users in
                guard let self = self else { return }

                // convert user model to cell view models
                let newUserCells = users.map { UserSearchListTableViewCell.Model(userInfo: $0) }

                // preload the images for new user cells
                self.preLoadImages(forNewCellModels: newUserCells, atPageOffset: 0)

                // create the newViewModel
                var model = self.viewController.model
                model.userCells = newUserCells
                if users.isEmpty {
                    model.viewState = .loadedWithZeroRecords
                    self.denyList.insert(text.lowercased())
                } else {
                    model.viewState = .loadedWithSuccess
                }

                // assign the new view model
                self.viewController.model = model
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

        usersDataSource.loadDataFor(searchedText: searchedText, pageOffset: pageOffset, pageSize: pageSize)
            .sink(receiveCompletion: { _ in }) { [weak self] users in
                guard let self = self else { return }

                // create the new view model
                var model = self.viewController.model
                let newUserCells = users.map { UserSearchListTableViewCell.Model(userInfo: $0) }

                // preload the images for new user cells
                self.preLoadImages(forNewCellModels: newUserCells, atPageOffset: pageOffset)

                model.userCells = model.userCells + newUserCells

                // assign new view model
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

            imageDataSource.image(fromUrl: newUserCell.avatarUrl)
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
