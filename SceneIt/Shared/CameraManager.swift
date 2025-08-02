//
//  CameraManager.swift
//  SceneIt
//
//  Created by Claude on 8/2/25.
//  Copyright © 2025 dannyfrancken. All rights reserved.
//

import Foundation
import AVFoundation
import CoreMediaIO
import CoreVideo
import os.log

// MARK: - Camera Manager

class CameraManager: NSObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.dannyfrancken.sceneit", category: "CameraManager")
    private var captureSession: AVCaptureSession?
    private var videoInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let outputQueue = DispatchQueue(label: "camera.output.queue", qos: .userInteractive)
    
    // Video processing properties
    private var currentPixelBuffer: CVPixelBuffer?
    private var isProcessing = false
    
    // Effect properties
    var overlayEnabled = true
    var currentEffect: VideoEffect = .none
    
    // Callbacks
    var onFrameProcessed: ((CVPixelBuffer) -> Void)?
    var onError: ((Error) -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    deinit {
        stopCapture()
    }
    
    // MARK: - Public Methods
    
    func startCapture() {
        logger.info("[SceneIt] Starting camera capture...")
        
        guard let captureSession = captureSession else {
            logger.error("[SceneIt] No capture session available")
            return
        }
        
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
                self.logger.info("[SceneIt] Camera capture started")
            }
        }
    }
    
    func stopCapture() {
        logger.info("[SceneIt] Stopping camera capture...")
        
        guard let captureSession = captureSession else { return }
        
        if captureSession.isRunning {
            captureSession.stopRunning()
            logger.info("[SceneIt] Camera capture stopped")
        }
    }
    
    func updateEffect(_ effect: VideoEffect) {
        logger.info("[SceneIt] Updating video effect to: \(effect.rawValue)")
        currentEffect = effect
    }
    
    func toggleOverlay() {
        overlayEnabled.toggle()
        logger.info("[SceneIt] Overlay \(self.overlayEnabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Private Methods
    
    private func setupCaptureSession() {
        logger.info("[SceneIt] Setting up capture session...")
        
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { return }
        
        // Configure session preset
        if captureSession.canSetSessionPreset(.hd1920x1080) {
            captureSession.sessionPreset = .hd1920x1080
        } else if captureSession.canSetSessionPreset(.hd1280x720) {
            captureSession.sessionPreset = .hd1280x720
        } else {
            captureSession.sessionPreset = .high
        }
        
        // Setup video input
        setupVideoInput()
        
        // Setup video output
        setupVideoOutput()
        
        logger.info("[SceneIt] Capture session setup complete")
    }
    
    private func setupVideoInput() {
        guard let captureSession = captureSession else { return }
        
        // Get default camera device
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
                AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            logger.error("[SceneIt] No camera device available")
            return
        }
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if let videoInput = videoInput, captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                logger.info("[SceneIt] Video input added: \(videoDevice.localizedName)")
            } else {
                logger.error("[SceneIt] Cannot add video input")
            }
        } catch {
            logger.error("[SceneIt] Error creating video input: \(error.localizedDescription)")
            onError?(error)
        }
    }
    
    private func setupVideoOutput() {
        guard let captureSession = captureSession else { return }
        
        videoOutput = AVCaptureVideoDataOutput()
        guard let videoOutput = videoOutput else { return }
        
        // Configure output settings
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            logger.info("[SceneIt] Video output added")
        } else {
            logger.error("[SceneIt] Cannot add video output")
        }
        
        // Configure video connection
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
            // Video stabilization is not available on macOS
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard !isProcessing else { return }
        isProcessing = true
        
        defer { isProcessing = false }
        
        // Get pixel buffer from sample buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            logger.error("[SceneIt] Failed to get pixel buffer from sample buffer")
            return
        }
        
        // Apply video processing
        let processedBuffer = processVideoFrame(pixelBuffer)
        
        // Deliver processed frame
        onFrameProcessed?(processedBuffer)
    }
    
    private func processVideoFrame(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer {
        // For now, return the original buffer
        // Video effects will be implemented in the next step
        return pixelBuffer
    }
}

// MARK: - Video Effects
// Note: VideoEffect enum is defined in VideoProcessor.swift