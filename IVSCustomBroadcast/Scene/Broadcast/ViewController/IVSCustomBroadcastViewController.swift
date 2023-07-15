//
//  IVSCustomBroadcastViewController.swift
//  IVSCustomBroadcast
//
//  Created by Cem Nisan on 15.07.2023.
//

import UIKit
import SnapKit

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
