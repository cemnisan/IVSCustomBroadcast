//
//  NetworkManager.swift
//  IVSCustomBroadcast
//
//  Created by Cem Nisan on 15.07.2023.
//

import Alamofire

enum ReachabilityType: String {
    case wifi
    case cellular
    case none
}

final class NetworkManager {
    
    // MARK: - Singleton Object
    static let shared = NetworkManager()
    
    // MARK: - Properties
    private(set) var reachabilityManager: NetworkReachabilityManager!
    
    var reachabilityType: ReachabilityType {
        guard reachabilityManager.isReachable else {
            return .none
        }
        if reachabilityManager.isReachableOnCellular {
            return .cellular
        }
        return .wifi
    }
    
    // MARK: - Private Initializer
    private init() {}
    
    // MARK: - Configuration
    func configureReachability() {
        reachabilityManager = NetworkReachabilityManager(host: "www.google.com")
        reachabilityManager.startListening { [weak self] (status) in
            guard let self = self else { return }
            NotificationCenter.default.post(name: .networkReachability, object: status)
        }
    }
}
