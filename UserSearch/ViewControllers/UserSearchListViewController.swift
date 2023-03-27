//
//  ViewController.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 21/03/23.
//

import UIKit
import Combine

protocol UserSearchListViewControllerDelegate: AnyObject {
    func didTapOnSearchButton()
    func didEnterText(_ text: String, sender: UITextField?)
    func loadDataFor(searchedText: String, pageOffset: Int, pageSize: Int, sender: UIViewController?)
}

extension UserSearchListViewControllerDelegate {
    func didTapOnSearchButton() { }
}

class UserSearchListViewController: UIViewController {
    
    var model: Model {
        didSet {
            applyModel()
        }
    }

    private let searchTextField: PaddedTextField = {
        let textField = PaddedTextField(edgeInsets: .init(top: Spacing.small,
                                                          left: Spacing.small,
                                                          bottom: Spacing.small,
                                                          right: Spacing.small))
        textField.font = .latoRegular(ofSize: 18)
        textField.textColor = .black
        textField.layer.cornerRadius = 4
        textField.layer.masksToBounds = true
        textField.backgroundColor = .lightGray
        return textField
    }()

    private let searchResultsTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(UserSearchListTableViewCell.self,
                           forCellReuseIdentifier: UserSearchListTableViewCell.identifier)
        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorEffect = .none
        return tableView
    }()

    private let activityLoaderView: UIActivityIndicatorView = {
        let activityIndicatorView = UIActivityIndicatorView(style: .medium)
        return activityIndicatorView
    }()

    private let searchButton: UIButton = {
        let button = UIButton()
        button.titleLabel?.font = .latoRegular(ofSize: 18)
        button.setTitleColor(.blue, for: .normal)
        return button
    }()

    private let searchController = UISearchController(searchResultsController: nil)

    private var cancellables = Set<AnyCancellable>()

    weak var viewDelegate: UserSearchListViewControllerDelegate?

    weak var coordinator: Coordinator<Void>?

    private var loadedPageOffsets: Set<Int> = []

    init(model: Model = .init()) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        setUpViews()
        applyModel()
        print("new instance created")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var cancellableSubscribers: Set<AnyCancellable> = []

    override func viewDidLoad() {
        super.viewDidLoad()
        searchResultsTableView.dataSource = self
        searchResultsTableView.delegate = self

        addTextFieldObserver()
        view.backgroundColor = .white
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.rightBarButtonItem = .init(customView: searchButton)
        loadedPageOffsets.removeAll()
        loadedPageOffsets.insert(0)
        viewDelegate?.didEnterText("", sender: nil)
    }

    deinit {
        coordinator?.finish()
    }

    private func setUpNavigationBarView() {
        searchController.obscuresBackgroundDuringPresentation = false
//        self.navigationItem.searchController = searchController
        searchResultsTableView.tableHeaderView = searchController.searchBar
        searchController.delegate = self
    }

    private func setUpViews() {
        view.backgroundColor = .white

        searchButton.addTarget(self, action: #selector(searchUsersTapped), for: .touchUpInside)

        setUpNavigationBarView()
        view.addAutoLayoutSubView(searchResultsTableView)

        view.addAutoLayoutSubView(activityLoaderView)
        setUpViewConstraints()
    }

    private func setUpViewConstraints() {
        NSLayoutConstraint.activate([
            searchResultsTableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchResultsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchResultsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchResultsTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityLoaderView.centerXAnchor.constraint(equalTo: searchResultsTableView.centerXAnchor),
            activityLoaderView.centerYAnchor.constraint(equalTo: searchResultsTableView.centerYAnchor)
        ])
    }

    @objc private func searchUsersTapped() {
        viewDelegate?.didTapOnSearchButton()
    }

    private func showActivityLoaderView() {
        activityLoaderView.isHidden = false
        activityLoaderView.startAnimating()
    }

    private func hideActivityLoaderView() {
        activityLoaderView.isHidden = true
        activityLoaderView.stopAnimating()
    }

    private func applyModel() {
        searchController.searchBar.searchTextField.placeholder = model.searchTextPlaceHolder
        searchButton.setTitle(model.searchButtonTitle, for: .normal)
        if !model.isSearchButtonShown {
            searchButton.isHidden = true
        }
        title = model.screenTitle
        switch model.viewState {
        case .loading:
            showActivityLoaderView()
        case .loadedWithSuccess:
            hideActivityLoaderView()
        case .loadedWithZeroRecords:
            hideActivityLoaderView()
            // show toast mssg
            showAlertForZeroRecords()
        case .loadedWithFailure(let pageOffset, let error):
            hideActivityLoaderView()
            loadedPageOffsets.remove(pageOffset)
            showAlertForError(error)
        }
        searchResultsTableView.reloadData()
    }

    private func showAlertForZeroRecords() {
        let alertController = UIAlertController(title: "Alert!", message: model.noRecordsFoundErrorMssg,
                                                preferredStyle: .actionSheet)
        searchController.present(alertController, animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alertController.dismiss(animated: true)
        }
    }

    private func showAlertForError(_ error: Error) {
        let alertController = UIAlertController(title: "Alert!",
                                                message: model.genericErrorMssg,
                                                preferredStyle: .actionSheet)
        if let error = error as? NetworkingError,
           case NetworkingError.noInternet = error {
            alertController.message = model.noInternetConnectionErrorMssg
        }
        let okAction = UIAlertAction(title: "Ok", style: .cancel)
        alertController.addAction(okAction)
        searchController.present(alertController, animated: true)
    }
}

extension UserSearchListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        model.userCells.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: UserSearchListTableViewCell.identifier,
                                                       for: indexPath) as? UserSearchListTableViewCell else {
            return UITableViewCell()
        }
        cell.model = model.userCells[indexPath.row]
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        searchController.searchBar.searchTextField.resignFirstResponder()
        if scrollView.frame.height + scrollView.contentOffset.y >= scrollView.contentSize.height {
            let lastPageOffset = (model.userCells.count / model.pageSize) - 1
            if !loadedPageOffsets.contains(lastPageOffset + 1) {
                loadedPageOffsets.insert(lastPageOffset + 1)
                viewDelegate?.loadDataFor(searchedText: searchController.searchBar.searchTextField.text ?? "",
                            pageOffset: lastPageOffset + 1,
                            pageSize: model.pageSize, sender: self)
            }
        }
    }
}

extension UserSearchListViewController: UISearchControllerDelegate {
    func didDismissSearchController(_ searchController: UISearchController) {
        loadedPageOffsets.insert(0)
        viewDelegate?.didEnterText("", sender: searchController.searchBar.searchTextField)
    }

    private func addTextFieldObserver() {
        NotificationCenter
            .default
            .publisher(for: UITextField.textDidChangeNotification,
                       object: searchController.searchBar.searchTextField)
            .compactMap { ($0.object as? UITextField)?.text }
            .debounce(for: .milliseconds(model.debounceInterval),
                      scheduler: RunLoop.main)
            .sink(receiveValue: { [unowned self] (value) in
                self.loadedPageOffsets.removeAll()
                loadedPageOffsets.insert(0)
                print("User searched \(value)")
                self.viewDelegate?.didEnterText(value, sender: self.searchTextField)
            })
            .store(in: &cancellableSubscribers)
    }
}
extension UserSearchListViewController {
    enum ViewState {
        case loading
        case loadedWithSuccess
        case loadedWithZeroRecords
        case loadedWithFailure(pageOffset: Int, error: Error)
    }

    struct Model {
        var screenTitle: String = "Slack Users"
        var searchTextPlaceHolder: String = "Search user names"
        var userCells: [UserSearchListTableViewCell.Model] = []
        var viewState: ViewState = .loadedWithSuccess
        var isSearchButtonShown: Bool = false
        var searchButtonTitle: String = "Search"
        var pageSize: Int = 0
        var debounceInterval: Int = 0
        let noInternetConnectionErrorMssg: String = "No internet connection. Please search users when online."
        let genericErrorMssg: String = "Something went wrong!"
        let noRecordsFoundErrorMssg: String = "Users not found. Searched Text is blacklisted."
    }
}

