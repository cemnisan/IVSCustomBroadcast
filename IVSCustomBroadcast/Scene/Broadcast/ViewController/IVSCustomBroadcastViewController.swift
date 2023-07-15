//
//  IVSCustomBroadcastViewController.swift
//  IVSCustomBroadcast
//
//  Created by Cem Nisan on 15.07.2023.
//

import UIKit
import SnapKit
import Alamofire

protocol IVSCustomBroadcastViewControllerInterface {
    func attachCameraPreview(previewView: UIView)
}

final class IVSCustomBroadcastViewController: UIViewController {
    
    // MARK: - Properties
    private var viewModel: IVSCustomBroadcastViewModelInterafce
        
    // MARK: - Initializer
    init(viewModel: IVSCustomBroadcastViewModelInterafce) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Properties
    lazy var previewContainerView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        return view
    }()
    
    // MARK: - Life Cycles
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        configurePreviewGestures()
        addObservers()
        viewModel.view = self
        viewModel.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.viewWillDisappear()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.viewDidAppear()
    }
}

// MARK: - Configuration
extension IVSCustomBroadcastViewController {
    private func configureUI() {
        prepareSubviews()
        prepareUIAnchor()
    }
    
    private func prepareSubviews() {
        view.addSubview(previewContainerView)
    }
    
    private func prepareUIAnchor() {
        previewContainerView.snp.makeConstraints { (maker) in
            maker.edges.equalToSuperview()
        }
    }
    
    private func configurePreviewGestures() {
        let singleTap = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTapGesture(_:))
        )
        singleTap.numberOfTapsRequired = 1
        previewContainerView.addGestureRecognizer(singleTap)
        
        let pinch = UIPinchGestureRecognizer(
            target: self,
            action: #selector(handlePinchGesture(_:))
        )
        pinch.delegate = self
        previewContainerView.addGestureRecognizer(pinch)
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkReachability(_:)),
            name: .networkReachability,
            object: nil
        )
    }
}

// MARK: - Actions
extension IVSCustomBroadcastViewController {
    @objc
    private func handleTapGesture(_ sender: UITapGestureRecognizer) {
        let screenSize = previewContainerView.bounds.size
        let x = sender.location(in: previewContainerView).y / screenSize.height
        let y = 1.0 - sender.location(in: previewContainerView).x / screenSize.width
        let devicePoint = CGPoint(x: x, y: y)
        viewModel.didTappedPreviewView(devicePoint: devicePoint)
    }
    
    @objc
    private func handlePinchGesture(_ sender: UIPinchGestureRecognizer) {
        viewModel.didZoomingBegan(sender)
    }
    
    @objc
    private func handleNetworkReachability(_ sender: Notification) {
        guard let status = sender.object as? NetworkReachabilityManager.NetworkReachabilityStatus else { return }
        
        switch status {
        case .notReachable: print("not reachable")
        case .reachable(.cellular), .reachable(.ethernetOrWiFi):
            print("reachable :\(status)")
        case .unknown: print("unkown")
        }
    }
}

// MARK: - IVSCustomBroadcastViewController Interface
extension IVSCustomBroadcastViewController: IVSCustomBroadcastViewControllerInterface {
    func attachCameraPreview(previewView: UIView) {
        previewContainerView.subviews.forEach { $0.removeFromSuperview() }
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewContainerView.addSubview(previewView)
        previewView.snp.makeConstraints { (maker) in
            maker.edges.equalToSuperview()
        }
    }
}

// MARK: - UIGestureRecognizer Delegate
extension IVSCustomBroadcastViewController: UIGestureRecognizerDelegate {}
