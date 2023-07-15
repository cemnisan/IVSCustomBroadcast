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
    func stopSession()
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
    override init() {}
    
    // MARK: - Public Methods
    func loadSession() {
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    func stopSession() {
        sessionQueue.async {
            self.removeObservers()
            self.session.stopRunning()
            self.isSessionRunning = self.session.isRunning
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
            sessionQueue.async {
                do {
                    try self.videoDeviceInput.device.lockForConfiguration()
                    self.videoDeviceInput.device.videoZoomFactor = factor
                    self.videoDeviceInput.device.unlockForConfiguration()
                } catch {
                    self.delegate?.didCameraErrorOccured(self, error: "An error has occured because of zooming: \(error.localizedDescription)")
                }
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
        
        addObservers()
        session.startRunning()
        isSessionRunning = self.session.isRunning
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
    
    private func addObservers() {
        let sessionRunningObservation = session.observe(\.isRunning, options: .new) { _, change in
            guard let isSessionRunning = change.newValue else { return }
            // call delegate method for session running value has changed.
        }
        keyValueObserverations.append(sessionRunningObservation)
        
        let systemPressureStateObservation = observe(\.videoDeviceInput?.device.systemPressureState, options: .new) { _, change in
            guard let systemPressureState = change.newValue else { return }
            // call setFrameRate method
        }
        keyValueObserverations.append(systemPressureStateObservation)
        
        let cameraChangingObservation = observe(\.videoDeviceInput?.device, options: .new) { _, change in
            guard let chosenCamera = change.newValue else { return }
            print(chosenCamera!)
            // call delegate method for the video device has changed
        }
        keyValueObserverations.append(cameraChangingObservation)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(subjectAreaDidChanged(_:)),
            name: .AVCaptureDeviceSubjectAreaDidChange,
            object: videoDeviceInput.device
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionDidRunTimeError(_:)),
            name: .AVCaptureSessionRuntimeError,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterruped(_:)),
            name: .AVCaptureSessionWasInterrupted,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded(_:)),
            name: .AVCaptureSessionInterruptionEnded,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMicrophoneRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        for keyValueObservation in keyValueObserverations {
            keyValueObservation.invalidate()
        }
        keyValueObserverations.removeAll()
    }
    
    private func setRecommendedFrameRateRangeForPressureState(systemPressureState: AVCaptureDevice.SystemPressureState) {
        let pressureLevel = systemPressureState.level
        switch pressureLevel {
        case .critical, .serious:
            /*
             The frame rates used here are only for demonstration purposes.
             Your frame rate throttling may be different depending on your app's camera configuration.
             */
            sessionQueue.async {
                do {
                    try self.videoDeviceInput.device.lockForConfiguration()
                    print("WARNING: Reached elevated system pressure level: \(pressureLevel). Throttling frame rate.")
                    self.videoDeviceInput.device.activeVideoMinFrameDuration = CMTime(
                        value: 1,
                        timescale: 20
                    )
                    self.videoDeviceInput.device.activeVideoMaxFrameDuration = CMTime(
                        value: 1,
                        timescale: 15
                    )
                    self.videoDeviceInput.device.unlockForConfiguration()
                } catch {
                    print("Could not lock device for configuration: \(error)")
                }
            }
        case .shutdown:
            print("session stopped running due to shutdown system pressue level.")
        default: break
        }
    }
 
    private func loadImage(data: Data) {
        guard let dataProvider = CGDataProvider(data: data as CFData),
              let cgImageRef: CGImage = CGImage(
                jpegDataProviderSource: dataProvider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else { return }
        let image = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: .right)
        // call delegate method for captured image
    }
    
    @objc
    private func subjectAreaDidChanged(_ sender: Notification) {
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        focus(
            with: .continuousAutoFocus,
            exposureMode: .continuousAutoExposure,
            at: devicePoint,
            monitorSubjectAreaChange: false
        )
    }
    
    @objc
    private func sessionDidRunTimeError(_ sender: Notification) {
        guard let error = sender.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        print("Capture session runtime error:\(error)")
        if error.code == .mediaServicesWereReset {
            // if media services were reset and the last start succeeded, restart the session.
            sessionQueue.async {
                if self.isSessionRunning {
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                } else {
                    print("show alert or something?")
                }
            }
        }
    }
    
    // MARK: - Handle Interruption
    @objc
    private func sessionWasInterruped(_ sender: Notification) {
        if let userInfoValue = sender.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
           let reasonIntegerValue = userInfoValue.integerValue,
           let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue)
        {
            switch reason {
            case .audioDeviceInUseByAnotherClient:
                print("An interruption caused by the audio hardware temporarily being made unavailable(for ex, for a phone call or alarm.")
                break
            case .videoDeviceInUseByAnotherClient:
                print("an interruption caused by the video device temporarily being made unavailable(for ex, when used by another capture session.")
                break
            case .videoDeviceNotAvailableDueToSystemPressure:
                print("An interruption due to system pressure, such as thermal duress.")
                break
            case .videoDeviceNotAvailableInBackground:
                print("An interruption caused by the app being sent to the background while using a camera.")
                break
            case .videoDeviceNotAvailableWithMultipleForegroundApps:
                print("An interruption caused when your ap is running in Slide Overi Split View, or PiP mode")
                break
            @unknown default: break
            }
        }
    }
    
    @objc
    private func sessionInterruptionEnded(_ sender: Notification) {
        print("capture session interruption ended.")
    }
        
    @objc
    private func handleMicrophoneRouteChange(_ sender: Notification) {
        guard let userInfo = sender.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        switch reason {
        case .newDeviceAvailable: print("new device available.")
        case .oldDeviceUnavailable: print("old device unavailable.")
        default: break
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate
extension CameraService: AVCaptureAudioDataOutputSampleBufferDelegate {}

// MARK: - AVCapturePhotoCapture Delegate
extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let outputData = photo.fileDataRepresentation() else {
            delegate?.didCameraErrorOccured(self, error: "Photo Error: \(String(describing: error))")
            return
        }
        loadImage(data: outputData)
    }
}
