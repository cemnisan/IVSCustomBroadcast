//
//  IVSCustomVeiwControllerBuilder.swift
//  IVSCustomBroadcast
//
//  Created by Cem Nisan on 15.07.2023.
//

import UIKit.UINavigationController

final class IVSCustomVeiwControllerBuilder {
    static func build() -> UINavigationController {
        let broadcastSession = IVSCustomBroadcastSession()
        let viewModel = IVSCustomBroadcastViewModel(broadcastSession: broadcastSession)
        let viewController = IVSCustomBroadcastViewController(viewModel: viewModel)
        let rootViewController = UINavigationController(rootViewController: viewController)
        return rootViewController
    }
}
