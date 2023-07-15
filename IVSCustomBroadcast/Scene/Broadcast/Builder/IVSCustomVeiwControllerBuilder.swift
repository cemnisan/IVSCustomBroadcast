//
//  IVSCustomVeiwControllerBuilder.swift
//  IVSCustomBroadcast
//
//  Created by Cem Nisan on 15.07.2023.
//

import UIKit.UINavigationController

final class IVSCustomVeiwControllerBuilder {
    static func build() -> UINavigationController {
        let streamModel = StreamModel(
            streamURL: URL(string: K.streamURLString)!,
            streamKey: K.streamKey
        )
        let broadcastSession = IVSCustomBroadcastSession(streamModel: streamModel)
        let viewModel = IVSCustomBroadcastViewModel(broadcastSession: broadcastSession)
        let viewController = IVSCustomBroadcastViewController(viewModel: viewModel)
        let rootViewController = UINavigationController(rootViewController: viewController)
        return rootViewController
    }
}
