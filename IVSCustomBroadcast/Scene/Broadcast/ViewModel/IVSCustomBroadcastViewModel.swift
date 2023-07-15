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
    
    func didTappedPreviewView(devicePoint point: CGPoint)
    func didZoomingBegan(_ sender: UIPinchGestureRecognizer)
}

final class IVSCustomBroadcastViewModel {
    
    // MARK: - Properties
    weak var view: IVSCustomBroadcastViewController?
    
    // MARK: - Dependencies
    private var broadcastSession: IVSCustomBroadcastSessionInterface
    
    // MARK: - Initializer
    init(broadcastSession: IVSCustomBroadcastSessionInterface) {
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
    
    func didTappedPreviewView(devicePoint point: CGPoint) {
        broadcastSession.startCameraFocus(with: point)
    }
    
    func didZoomingBegan(_ sender: UIPinchGestureRecognizer) {
        broadcastSession.startCameraZoom(with: sender)
    }
}

// MARK: - IVSCustomBroadcastSession Delegate
extension IVSCustomBroadcastViewModel: IVSCustomBroadcastSessionDelegate {
    func attachCameraPreview(previewView: UIView) {
        view?.attachCameraPreview(previewView: previewView)
    }
}
