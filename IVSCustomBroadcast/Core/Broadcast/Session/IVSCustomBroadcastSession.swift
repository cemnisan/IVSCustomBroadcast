//
//  IVSCustomBroadcastSession.swift
//  IVSCustomBroadcast
//
//  Created by Cem Nisan on 15.07.2023.
//

import Foundation
import AmazonIVSBroadcast

protocol IVSCustomBroadcastSessionDelegate: AnyObject {
    func attachCameraPreview(container: UIView, preview: UIView)
}

final class IVSCustomBroadcastSession: NSObject {
    
    // MARK: - Properties
    weak var delegate: IVSCustomBroadcastSessionDelegate?
    
    // MARK: - Dependencies
    private let previewContainerView: UIView
    private let cameraService: CameraService
    
    // MARK: - Session
    private var broadcastSession: IVSBroadcastSession?
    private var isBroadcastSessionRunning = false
    private var shouldBroadcastSessionRestart = false
    
    // MARK: - Sources
    private var customAudioSource: IVSCustomAudioSource?
    private var customImageSource: IVSCustomImageSource?
    
    // MARK: - Initializer
    init(previewContainerView: UIView,
         cameraService: CameraService = CameraService())
    {
        self.previewContainerView = previewContainerView
        self.cameraService = cameraService
        super.init()
    }
    
    func startBroadcastSession(with url: URL, streamKey: String) {
        switch cameraService.setupResult {
        case .success:
            setupSession(isStandart: true)
            do {
                try broadcastSession?.start(with: url, streamKey: streamKey)
            } catch {
                print("❌ Error starting IVSBroadcastSession: \(error)")
            }
        case .notAuthorized: break
        case .configurationFailed: break
        }
    }
    
    // MARK: - Private methods
    private func setupSession(isStandart: Bool) {
        do {
            let configuration = isStandart ?
            IVSPresets.configurations().standardPortrait() :
            IVSPresets.configurations().basicPortrait()
            
            let customSlot = IVSMixerSlotConfiguration()
            customSlot.size = configuration.video.size
            customSlot.position = CGPoint(x: 0, y: 0)
            customSlot.preferredAudioInput = .userAudio
            customSlot.preferredVideoInput = .userImage
            try customSlot.setName("custom-slot")
            configuration.mixer.slots = [customSlot]
            
            IVSBroadcastSession.applicationAudioSessionStrategy = .noAction
            
            let broadcastSession = try IVSBroadcastSession(
                configuration: configuration,
                descriptors: nil,
                delegate: self
            )
            
            let customAudioService = broadcastSession.createAudioSource(withName: "custom-audio")
            broadcastSession.attach(customAudioService, toSlotWithName: "custom-slot")
            self.customAudioSource = customAudioService
            
            let customImageSource = broadcastSession.createImageSource(withName: "custom-image")
            broadcastSession.attach(customImageSource, toSlotWithName: "custom-slot")
            self.customImageSource = customImageSource
            
            let previewView = try customImageSource.previewView(with: .fit)
            delegate?.attachCameraPreview(
                container: previewContainerView,
                preview: previewView
            )
            
            self.broadcastSession = broadcastSession
            
            cameraService.delegate = self
            cameraService.loadSession()
        } catch {
            print("couldn't set up IVSBroadcast session: \(error)")
        }
    }
}

// MARK: - CameraService Delegate
extension IVSCustomBroadcastSession: CameraServiceDelegate {
    func didCameraErrorOccured(_ delegate: CameraService, error: String) {
        print(error)
    }
    
    func didVideoCaptureOutput(_ delegate: CameraService, capturedOutput sampleBuffer: CMSampleBuffer) {
        customImageSource?.onSampleBuffer(sampleBuffer)
    }
    
    func didAudioCaptureOutput(_ delegate: CameraService, capturedOutput sampleBuffer: CMSampleBuffer) {
        customAudioSource?.onSampleBuffer(sampleBuffer)
    }
}

// MARK: - IVSBroadcastSession Delegate
extension IVSCustomBroadcastSession: IVSBroadcastSession.Delegate {
    func broadcastSession(_ session: IVSBroadcastSession, didChange state: IVSBroadcastSession.State) {}
    func broadcastSession(_ session: IVSBroadcastSession, didEmitError error: Error) {}
}
