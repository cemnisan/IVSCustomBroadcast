//
//  IVSCustomBroadcastSession.swift
//  IVSCustomBroadcast
//
//  Created by Cem Nisan on 15.07.2023.
//

import Foundation
import AmazonIVSBroadcast

struct StreamModel {
    let streamURL: URL
    let streamKey: String
}

protocol IVSCustomBroadcastSessionInterface {
    var delegate: IVSCustomBroadcastSessionDelegate? { get set }
    
    func startBroadcastSession(with url: URL, streamKey: String)
    func startCameraFocus(with devicePoint: CGPoint)
    func startCameraZoom(with pinch: UIPinchGestureRecognizer)
}

protocol IVSCustomBroadcastSessionDelegate: AnyObject {
    func attachCameraPreview(previewView: UIView)
}

final class IVSCustomBroadcastSession: NSObject, IVSCustomBroadcastSessionInterface {
    
    // MARK: - Properties
    weak var delegate: IVSCustomBroadcastSessionDelegate?
    
    // MARK: - Dependencies
    private let streamModel: StreamModel
    private var cameraService: CameraServiceInterace
    
    // MARK: - Session
    private var broadcastSession: IVSBroadcastSession?
    private var isBroadcastSessionRunning = false
    private var shouldBroadcastSessionRestart = false
    
    // MARK: - Sources
    private var customAudioSource: IVSCustomAudioSource?
    private var customImageSource: IVSCustomImageSource?
    
    // MARK: - Initializer
    init(cameraService: CameraServiceInterace = CameraService(),
         streamModel: StreamModel)
    {
        self.cameraService = cameraService
        self.streamModel = streamModel
        super.init()
    }
    
    func startBroadcastSession(with url: URL, streamKey: String) {
        switch cameraService.setupResult {
        case .success:
            let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
            handleAuthorizationStatus(status: authorizationStatus)
        case .configurationFailed: break
        }
    }
    
    func startCameraFocus(with devicePoint: CGPoint) {
        cameraService.focus(with: devicePoint)
    }
    
    func startCameraZoom(with pinch: UIPinchGestureRecognizer) {
        cameraService.zoom(with: pinch)
    }
    
    // MARK: - Private methods
    private func handleAuthorizationStatus(status: AVAuthorizationStatus) {
        switch status {
        case .authorized:
            DispatchQueue.main.async {
                self.startBroadcastSession()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (granted) in
                if granted {
                    DispatchQueue.main.async {
                        if self.broadcastSession == nil {
                            self.startBroadcastSession()
                        }
                    }
                   return
                } else {
                    // TODO: - Show Display error for permession
                }
            }
        default: break
        }
    }
    
    private func startBroadcastSession() {
        self.setupSession(isStandart: true)
        do {
            try self.broadcastSession?.start(with: self.streamModel.streamURL, streamKey: self.streamModel.streamKey)
        } catch {
            print("❌ Error starting IVSBroadcastSession: \(error)")
        }
    }
    
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
            delegate?.attachCameraPreview(previewView: previewView)
            
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
