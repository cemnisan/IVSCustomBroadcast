//
//  CameraService.swift
//  IVSCustomBroadcast
//
//  Created by Cem Nisan on 15.07.2023.
//

import Foundation
import AVFoundation

protocol CameraServiceDelegate: AnyObject {
    func didVideoCaptureOutput(_ delegate: CameraService, capturedOutput sampleBuffer: CMSampleBuffer)
    func didAudioCaptureOutput(_ delegate: CameraService, capturedOutput sampleBuffer: CMSampleBuffer)
}

final class CameraService: NSObject {
    
    // MARK: - Properties
    private weak var delegate: CameraServiceDelegate?
   
    // MARK: - Session
    private let session = AVCaptureSession()
    private var isSessionRunning = false
    private var setupResult: SessionSetupResult = .success
    
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
    
    // MARK: - Nested Types
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    // MARK: - Initializer
    init(delegate: CameraServiceDelegate) {
        self.delegate = delegate
        super.init()
    }
    
    // MARK: - Public Methods
    func loadSession() {
        let videoAuthrozationStatus = AVCaptureDevice.authorizationStatus(for: .video)
      
        handleAuthorizationStatus(status: videoAuthrozationStatus)
        
        sessionQueue.async {
            self.configureSession()
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
    private func handleAuthorizationStatus(status: AVAuthorizationStatus) {
        switch status {
        case .authorized: break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { (granted) in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            }
        default:
            setupResult = .notAuthorized
        }
    }
    
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        
        addVideoDeviceInput()
        addAudioInput()
        addCapturePhotoOutput()
        
        session.commitConfiguration()
    }
    
    private func addVideoDeviceInput() {
        let defaultVideoDevice = getDefaultVideoDevice()
        guard let videoDevice = defaultVideoDevice else {
            setupResult = .configurationFailed
            session.commitConfiguration()
            print("couldn't find any video device.")
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
                print("couldn't add video device input to the session.")
            }
        } catch {
            setupResult = .configurationFailed
            session.commitConfiguration()
            print("couldn't initialize video device input: \(videoDevice.localizedName)")
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
            print("couldn't add video output to the session.")
        }
    }
    
    private func addAudioInput() {
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            setupResult = .configurationFailed
            session.commitConfiguration()
            print("couldn't find any default audio device.")
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
                print("couldn't add audio input to the session")
            }
        } catch {
            print("couldn't initialize audio device input: \(audioDevice.localizedName)")
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
            print("couldn't add audio output to the session.")
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
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate
extension CameraService: AVCaptureAudioDataOutputSampleBufferDelegate {}
