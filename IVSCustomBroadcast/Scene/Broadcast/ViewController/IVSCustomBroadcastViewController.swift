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
    
    // MARK: - Methods
    private func configureUI() {
        prepareSubviews()
        prepareUIAnchor()
        viewModel.view = self
    }
    
    private func prepareSubviews() {
        view.addSubview(previewContainerView)
    }
    
    private func prepareUIAnchor() {
        previewContainerView.snp.makeConstraints { (maker) in
            maker.edges.equalToSuperview()
        }
    }
    
    // MARK: - Actions
}

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
