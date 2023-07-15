//
//  CameraService.swift
//  IVSCustomBroadcast
//
//  Created by Cem Nisan on 15.07.2023.
//

import Foundation
import AVFoundation
import UIKit.UIPinchGestureRecognizer

enum SessionSetupResult {
    case success
    case configurationFailed
}

protocol CameraServiceInterace {
    var delegate: CameraServiceDelegate? { get set }
    var setupResult: SessionSetupResult { get }
    
    func loadSession()
    func focus(with devicePoint: CGPoint)
    func zoom(with pinch: UIPinchGestureRecognizer)
}

protocol CameraServiceDelegate: AnyObject {
    func didCameraErrorOccured(_ delegate: CameraService, error: String)
    func didVideoCaptureOutput(_ delegate: CameraService, capturedOutput sampleBuffer: CMSampleBuffer)
    func didAudioCaptureOutput(_ delegate: CameraService, capturedOutput sampleBuffer: CMSampleBuffer)
}

final class CameraService: NSObject, CameraServiceInterace {
    
    // MARK: - Properties
    weak var delegate: CameraServiceDelegate?
   
    // MARK: - Session
    private let session = AVCaptureSession()
    private var isSessionRunning = false
    var setupResult: SessionSetupResult = .success
    
    // MARK: - Session Queue
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    // MARK: - Inputs
    @objc private dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    // MARK: - Outputs
    private var audioOutput: AVCaptureOutput!
    private var videoOutput: AVCaptureOutput!
    private var cameraOutput: AVCapturePhotoOutput?
    
    // MARK: - Zoom
    private var zoomFactor: CGFloat = 1.0
    
    // MARK: - KVO
    private var keyValueObserverations = [NSKeyValueObservation]()
    
    // MARK: - Initializer
    override init() { }
    
    // MARK: - Public Methods
    func loadSession() {
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    func focus(with devicePoint: CGPoint) {
        focus(
            with: .autoFocus,
            exposureMode: .autoExpose,
            at: devicePoint,
            monitorSubjectAreaChange: true
        )
    }
    
    func zoom(with pinch: UIPinchGestureRecognizer) {
        func minMaxZoom(_ factor: CGFloat) -> CGFloat {
            return min(
                max(factor, 1.0),
                videoDeviceInput.device.activeFormat.videoMaxZoomFactor
            )
        }
        
        func update(scale factor: CGFloat) {
            do {
                try videoDeviceInput.device.lockForConfiguration()
                videoDeviceInput.device.videoZoomFactor = factor
                videoDeviceInput.device.unlockForConfiguration()
            } catch {
                delegate?.didCameraErrorOccured(self, error: "An error has occured because of zooming: \(error.localizedDescription)")
            }
        }
        
        let newScaleFactor = minMaxZoom(pinch.scale * zoomFactor)
        
        switch pinch.state {
        case .began: fallthrough
        case .changed: update(scale: newScaleFactor)
        case .ended:
            zoomFactor = minMaxZoom(newScaleFactor)
            update(scale: zoomFactor)
        default: break
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        if output == videoOutput {
            connection.videoOrientation = .portrait
            delegate?.didVideoCaptureOutput(self, capturedOutput: sampleBuffer)
        } else if output == audioOutput {
            delegate?.didAudioCaptureOutput(self, capturedOutput: sampleBuffer)
        }
    }
    
    // MARK: - Private Methods
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        
        addVideoDeviceInput()
        addAudioInput()
        addCapturePhotoOutput()
        
        session.commitConfiguration()
        
        sessionQueue.async {
            // TODO: - Add observers.
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
        }
    }
    
    private func addVideoDeviceInput() {
        let defaultVideoDevice = getDefaultVideoDevice()
        guard let videoDevice = defaultVideoDevice else {
            setupResult = .configurationFailed
            session.commitConfiguration()
            delegate?.didCameraErrorOccured(self, error: "couldn't find any video device.")
            return
        }
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                addVideoOutput()
            } else {
                setupResult = .configurationFailed
                session.commitConfiguration()
                delegate?.didCameraErrorOccured(self, error: "couldn't add video device input to the session.")
            }
        } catch {
            setupResult = .configurationFailed
            session.commitConfiguration()
            delegate?.didCameraErrorOccured(self, error: "couldn't initialize video device input: \(videoDevice.localizedName)")
        }
    }
    
    private func addVideoOutput() {
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(
            self,
            queue: sessionQueue
        )
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            self.videoOutput = videoOutput
        } else {
            setupResult = .configurationFailed
            session.commitConfiguration()
            delegate?.didCameraErrorOccured(self, error: "couldn't add video output to the session.")
        }
    }
    
    private func addAudioInput() {
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            setupResult = .configurationFailed
            session.commitConfiguration()
            delegate?.didCameraErrorOccured(self, error: "couldn't find any default audio device.")
            return
        }
        do {
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
                addAudioOutput()
            } else {
                setupResult = .configurationFailed
                session.commitConfiguration()
                delegate?.didCameraErrorOccured(self, error: "couldn't add audio input to the session")
            }
        } catch {
            delegate?.didCameraErrorOccured(self, error: "couldn't initialize audio device input: \(audioDevice.localizedName)")
        }
    }
    
    private func addAudioOutput() {
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(
            self,
            queue: sessionQueue
        )
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
            self.audioOutput = audioOutput
        } else {
            setupResult = .configurationFailed
            session.commitConfiguration()
            delegate?.didCameraErrorOccured(self, error: "couldn't add audio output to the session.")
        }
    }
    
    private func addCapturePhotoOutput() {
        let capturePhotoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(capturePhotoOutput) {
            session.addOutput(capturePhotoOutput)
            self.cameraOutput = capturePhotoOutput
        }
    }
    
    private func getDefaultVideoDevice() -> AVCaptureDevice? {
        var defaultVideoDevice: AVCaptureDevice?
        
        if let backCameraDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) {
            defaultVideoDevice = backCameraDevice
        } else if let dualWideCameraDevice = AVCaptureDevice.default(
            .builtInDualWideCamera,
            for: .video,
            position: .back
        ) {
            defaultVideoDevice = dualWideCameraDevice
        } else if let dualCameraDevice = AVCaptureDevice.default(
            .builtInDualCamera,
            for: .video,
            position: .back
        ) {
            defaultVideoDevice = dualCameraDevice
        } else if let frontCameraDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) {
            defaultVideoDevice = frontCameraDevice
        }
        return defaultVideoDevice
    }
    
    private func focus(
        with focusMode: AVCaptureDevice.FocusMode,
        exposureMode: AVCaptureDevice.ExposureMode,
        at devicePoint: CGPoint,
        monitorSubjectAreaChange: Bool
    ) {
        sessionQueue.async {
            let device = self.videoDeviceInput.device
            do {
                try device.lockForConfiguration()
                
                if device.isFocusPointOfInterestSupported &&
                    device.isFocusModeSupported(focusMode)
                {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = focusMode
                }
                
                if device.isExposurePointOfInterestSupported &&
                    device.isExposureModeSupported(exposureMode)
                {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = exposureMode
                }
                
                device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                device.unlockForConfiguration()
            } catch {
                print("couldn't lock device for configuration: \(error)")
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate
extension CameraService: AVCaptureAudioDataOutputSampleBufferDelegate {}
