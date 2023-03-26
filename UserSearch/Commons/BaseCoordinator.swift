//
//  BaseCoordinator.swift
//  UserSearch
//
//  Created by Rajneesh Biswal on 22/03/23.
//

import Foundation

/// Coordinator design pattern: https://khanlou.com/2015/01/the-coordinator/
public protocol Coordinatable {

    /// CoordinationResult is used to send an object (that can be closure or any object) from child coordinator to its parentCoordinator on finish.
    associatedtype CoordinationResult

    /// Starts the coordinator. Please intialise and present view controllers inside respective coordinators.
    func start()
    
    /// If we want to navigate from one screen to any detail screen. The detail screen coordinator has to be added as child coordinator in parent list coordinator.
    /// - Parameters:
    ///     - coordinator: coordinator that needs to be added as child coordinator
    func addChildCoordinator(_ coordinator: Self)

    /// set the closure to some action which has to be performed on Coordinator's finish
    var onFinish:((CoordinationResult?) -> Void)? { set get }

    /// This method deallocates the memory of the coordinator.
    /// Call this method when its corresponding view controller is deallocated. Or the coordinator flow is finished.
    func finish(_ coordinationResult: CoordinationResult?)
}

public class Coordinator<CoordinationResult>: Coordinatable {
    private let identifier = UUID()
    private var childCoordinators: [UUID: Coordinator] = [:]
    open func start() {
    }

    public var onFinish:((CoordinationResult?)-> Void)?

    public func finish(_ result: CoordinationResult? = nil) {
        onFinish?(result)
        cleanUpFromParent?()
    }

    public func addChildCoordinator(_ coordinator: Coordinator) {
        coordinator.cleanUpFromParent = { [weak self, weak coordinator] in
            self?.removeChildCoordinator(coordinator)
        }
        childCoordinators[coordinator.identifier] = coordinator
    }

    private var cleanUpFromParent: (()-> Void)?

    private  func removeChildCoordinator(_ coordinator: Coordinator?) {
        guard let coordinator = coordinator else { return }
        childCoordinators[coordinator.identifier] = nil
    }
}
