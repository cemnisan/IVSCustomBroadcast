//
//  IVSCustomBroadcastViewModel.swift
//  IVSCustomBroadcast
//
//  Created by Cem Nisan on 15.07.2023.
//

import Foundation
import UIKit.UIView

protocol IVSCustomBroadcastViewModelInterafce {
    var view: IVSCustomBroadcastViewController? { get set }
    
    func viewDidLoad()
    func viewDidAppear()
    func viewWillDisappear()
}

final class IVSCustomBroadcastViewModel {
    
    // MARK: - Properties
    weak var view: IVSCustomBroadcastViewController?
    
    // MARK: - Dependencies
    private let broadcastSession: IVSCustomBroadcastSession
    
    // MARK: - Initializer
    init(broadcastSession: IVSCustomBroadcastSession) {
        self.broadcastSession = broadcastSession
    }
}

// MARK: - IVSCustomBroadcastViewModel Interafce
extension IVSCustomBroadcastViewModel: IVSCustomBroadcastViewModelInterafce {
    func viewDidLoad() {
        broadcastSession.delegate = self
    }
    
    func viewDidAppear() {
        guard let url = URL(string: K.streamURLString) else { return }
        broadcastSession.startBroadcastSession(with: url, streamKey: K.streamKey)
    }
    
    func viewWillDisappear() {}
}

// MARK: - IVSCustomBroadcastSession Delegate
extension IVSCustomBroadcastViewModel: IVSCustomBroadcastSessionDelegate {
    func attachCameraPreview(previewView: UIView) {
        view?.attachCameraPreview(previewView: previewView)
    }
}
