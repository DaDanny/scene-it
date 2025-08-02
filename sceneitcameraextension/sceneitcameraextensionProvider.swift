//
//  sceneitcameraextensionProvider.swift
//  sceneitcameraextension
//
//  Created by Danny Francken on 8/1/25.
//  Copyright © 2025 dannyfrancken. All rights reserved.
//

import Foundation
import CoreMediaIO
import AVFoundation
import CoreVideo
import os.log
import IOKit

let kFrameRate: Int = 30

// MARK: - Device Source

class sceneitcameraextensionDeviceSource: NSObject, CMIOExtensionDeviceSource {
    
    private(set) var device: CMIOExtensionDevice!
    private var _streamSource: sceneitcameraextensionStreamSource!
    private var _streamingCounter: UInt32 = 0
    
    // Real camera components
    private var captureSession: AVCaptureSession?
    private var videoInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let captureQueue = DispatchQueue(label: "camera.capture.queue", qos: .userInteractive)
    
    // Video processing
    private var _videoDescription: CMFormatDescription!
    private let logger = Logger(subsystem: "com.dannyfrancken.sceneit.extension", category: "DeviceSource")
    
    init(localizedName: String) {
        os_log(.info, "[SceneIt Extension] DeviceSource initializing with name: %@", localizedName)
        super.init()
        
        let deviceID = UUID()
        self.device = CMIOExtensionDevice(localizedName: localizedName, deviceID: deviceID, legacyDeviceID: nil, source: self)
        
        // Setup video format description
        let dims = CMVideoDimensions(width: 1920, height: 1080)
        CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCVPixelFormatType_32BGRA,
            width: dims.width,
            height: dims.height,
            extensions: nil,
            formatDescriptionOut: &_videoDescription
        )
        
        // Create stream
        let videoStreamFormat = CMIOExtensionStreamFormat(
            formatDescription: _videoDescription,
            maxFrameDuration: CMTime(value: 1, timescale: Int32(kFrameRate)),
            minFrameDuration: CMTime(value: 1, timescale: Int32(kFrameRate)),
            validFrameDurations: nil
        )
        
        let videoID = UUID()
        _streamSource = sceneitcameraextensionStreamSource(
            localizedName: "Scene It Video Stream",
            streamID: videoID,
            streamFormat: videoStreamFormat,
            device: device
        )
        
        do {
            try device.addStream(_streamSource.stream)
            os_log(.info, "[SceneIt Extension] Successfully added stream to device")
        } catch {
            os_log(.error, "[SceneIt Extension] Failed to add stream: %@", error.localizedDescription)
            fatalError("Failed to add stream: \(error.localizedDescription)")
        }
        
        // Setup real camera
        setupCamera()
    }
    
    deinit {
        stopCamera()
    }
    
    // MARK: - Camera Setup
    
    private func setupCamera() {
        logger.info("[SceneIt Extension] Setting up real camera...")
        
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
        
        // Setup input
        setupCameraInput()
        
        // Setup output
        setupCameraOutput()
        
        logger.info("[SceneIt Extension] Camera setup complete")
    }
    
    private func setupCameraInput() {
        guard let captureSession = captureSession else { return }
        
        // Try to get front camera first, then back camera
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
                AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            logger.error("[SceneIt Extension] No camera device available")
            return
        }
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if let videoInput = videoInput, captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                logger.info("[SceneIt Extension] Added video input: \(videoDevice.localizedName)")
            }
        } catch {
            logger.error("[SceneIt Extension] Error creating video input: \(error.localizedDescription)")
        }
    }
    
    private func setupCameraOutput() {
        guard let captureSession = captureSession else { return }
        
        videoOutput = AVCaptureVideoDataOutput()
        guard let videoOutput = videoOutput else { return }
        
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            logger.info("[SceneIt Extension] Added video output")
        }
        
        // Configure video connection
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
    }
    
    private func startCamera() {
        logger.info("[SceneIt Extension] Starting real camera...")
        
        guard let captureSession = captureSession else { return }
        
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
                self.logger.info("[SceneIt Extension] Real camera started")
            }
        }
    }
    
    private func stopCamera() {
        logger.info("[SceneIt Extension] Stopping real camera...")
        
        guard let captureSession = captureSession else { return }
        
        if captureSession.isRunning {
            captureSession.stopRunning()
            logger.info("[SceneIt Extension] Real camera stopped")  
        }
    }
    
    // MARK: - CMIOExtensionDeviceSource Protocol
    
    var availableProperties: Set<CMIOExtensionProperty> {
        return [.deviceTransportType, .deviceModel]
    }
    
    func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
        let deviceProperties = CMIOExtensionDeviceProperties(dictionary: [:])
        
        if properties.contains(.deviceTransportType) {
            deviceProperties.transportType = 2 // Virtual transport type
        }
        
        if properties.contains(.deviceModel) {
            deviceProperties.model = "Scene It Virtual Camera"
        }
        
        return deviceProperties
    }
    
    func setDeviceProperties(_ deviceProperties: CMIOExtensionDeviceProperties) throws {
        // Handle settable properties here
    }
    
    func startStreaming() {
        os_log(.info, "[SceneIt Extension] Starting virtual camera streaming...")
        _streamingCounter += 1
        
        if _streamingCounter == 1 {
            startCamera()
        }
    }
    
    func stopStreaming() {
        os_log(.info, "[SceneIt Extension] Stopping virtual camera streaming...")
        
        if _streamingCounter > 1 {
            _streamingCounter -= 1
        } else {
            _streamingCounter = 0
            stopCamera()
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension sceneitcameraextensionDeviceSource: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            logger.error("[SceneIt Extension] Failed to get pixel buffer")
            return
        }
        
        // Apply simple overlay
        let processedBuffer = applySimpleOverlay(to: pixelBuffer)
        
        // Send processed frame to virtual camera stream
        let timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: Int32(kFrameRate)),
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: CMTime.invalid
        )
        
        var newSampleBuffer: CMSampleBuffer?
        var timingInfo = timing
        
        let result = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: processedBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: _videoDescription,
            sampleTiming: &timingInfo,
            sampleBufferOut: &newSampleBuffer
        )
        
        if result == noErr, let sampleBuffer = newSampleBuffer {
            _streamSource.stream.send(
                sampleBuffer,
                discontinuity: [],
                hostTimeInNanoseconds: UInt64(timingInfo.presentationTimeStamp.seconds * Double(NSEC_PER_SEC))
            )
        }
    }
    
    private func applySimpleOverlay(to pixelBuffer: CVPixelBuffer) -> CVPixelBuffer {
        // Create a copy of the pixel buffer for processing
        guard let processedBuffer = copyPixelBuffer(pixelBuffer) else { return pixelBuffer }
        
        // Lock the pixel buffer for direct memory access
        CVPixelBufferLockBaseAddress(processedBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(processedBuffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(processedBuffer) else { return pixelBuffer }
        
        let width = CVPixelBufferGetWidth(processedBuffer)
        let height = CVPixelBufferGetHeight(processedBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(processedBuffer)
        
        // Add a simple overlay rectangle in the bottom-right corner
        let overlayWidth = 200
        let overlayHeight = 60
        let overlayX = max(0, width - overlayWidth - 20)  
        let overlayY = max(0, height - overlayHeight - 20)
        
        // Draw overlay background (semi-transparent black)
        for y in overlayY..<min(height, overlayY + overlayHeight) {
            for x in overlayX..<min(width, overlayX + overlayWidth) {
                let pixelIndex = y * bytesPerRow + x * 4
                let pixelPtr = baseAddress.advanced(by: pixelIndex).assumingMemoryBound(to: UInt8.self)
                
                // BGRA format: Blue, Green, Red, Alpha
                pixelPtr[0] = UInt8(pixelPtr[0] / 2) // Blue
                pixelPtr[1] = UInt8(pixelPtr[1] / 2) // Green
                pixelPtr[2] = UInt8(pixelPtr[2] / 2) // Red
                pixelPtr[3] = 255 // Alpha (opaque)
            }
        }
        
        // Add text overlay (simplified - just a colored rectangle for now)
        let textX = overlayX + 10
        let textY = overlayY + 10
        let textWidth = overlayWidth - 20
        let textHeight = 20
        
        for y in textY..<min(height, textY + textHeight) {
            for x in textX..<min(width, textX + textWidth) {
                let pixelIndex = y * bytesPerRow + x * 4
                let pixelPtr = baseAddress.advanced(by: pixelIndex).assumingMemoryBound(to: UInt8.self)
                
                // Scene It brand color (blue-ish)
                pixelPtr[0] = 255 // Blue
                pixelPtr[1] = 100 // Green
                pixelPtr[2] = 50  // Red
                pixelPtr[3] = 255 // Alpha
            }
        }
        
        return processedBuffer
    }
    
    private func copyPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var newPixelBuffer: CVPixelBuffer?
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        let result = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            pixelBufferAttributes as CFDictionary,
            &newPixelBuffer
        )
        
        guard result == kCVReturnSuccess, let destBuffer = newPixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(destBuffer, [])
        
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            CVPixelBufferUnlockBaseAddress(destBuffer, [])
        }
        
        guard let sourceData = CVPixelBufferGetBaseAddress(pixelBuffer),
              let destData = CVPixelBufferGetBaseAddress(destBuffer) else {
            return nil
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let dataSize = height * bytesPerRow
        
        memcpy(destData, sourceData, dataSize)
        
        return destBuffer
    }
}

// MARK: - Stream Source

class sceneitcameraextensionStreamSource: NSObject, CMIOExtensionStreamSource {
    
    private(set) var stream: CMIOExtensionStream!
    let device: CMIOExtensionDevice
    private let _streamFormat: CMIOExtensionStreamFormat
    
    init(localizedName: String, streamID: UUID, streamFormat: CMIOExtensionStreamFormat, device: CMIOExtensionDevice) {
        self.device = device
        self._streamFormat = streamFormat
        super.init()
        self.stream = CMIOExtensionStream(localizedName: localizedName, streamID: streamID, direction: .source, clockType: .hostTime, source: self)
    }
    
    var formats: [CMIOExtensionStreamFormat] {
        return [_streamFormat]
    }
    
    var activeFormatIndex: Int = 0 {
        didSet {
            if activeFormatIndex >= 1 {
                os_log(.error, "[SceneIt Extension] Invalid format index")
            }
        }
    }
    
    var availableProperties: Set<CMIOExtensionProperty> {
        return [.streamActiveFormatIndex, .streamFrameDuration]
    }
    
    func streamProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionStreamProperties {
        let streamProperties = CMIOExtensionStreamProperties(dictionary: [:])
        
        if properties.contains(.streamActiveFormatIndex) {
            streamProperties.activeFormatIndex = 0
        }
        
        if properties.contains(.streamFrameDuration) {
            let frameDuration = CMTime(value: 1, timescale: Int32(kFrameRate))
            streamProperties.frameDuration = frameDuration
        }
        
        return streamProperties
    }
    
    func setStreamProperties(_ streamProperties: CMIOExtensionStreamProperties) throws {
        if let activeFormatIndex = streamProperties.activeFormatIndex {
            self.activeFormatIndex = activeFormatIndex
        }
    }
    
    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool {
        return true
    }
    
    func startStream() throws {
        guard let deviceSource = device.source as? sceneitcameraextensionDeviceSource else {
            fatalError("Unexpected source type \(String(describing: device.source))")
        }
        deviceSource.startStreaming()
    }
    
    func stopStream() throws {
        guard let deviceSource = device.source as? sceneitcameraextensionDeviceSource else {
            fatalError("Unexpected source type \(String(describing: device.source))")
        }
        deviceSource.stopStreaming()
    }
}

// MARK: - Provider Source

class sceneitcameraextensionProviderSource: NSObject, CMIOExtensionProviderSource {
    
    private(set) var provider: CMIOExtensionProvider!
    private var deviceSource: sceneitcameraextensionDeviceSource!
    
    init(clientQueue: DispatchQueue?) {
        os_log(.info, "[SceneIt Extension] ProviderSource initializing...")
        super.init()
        
        provider = CMIOExtensionProvider(source: self, clientQueue: clientQueue)
        os_log(.info, "[SceneIt Extension] Created CMIOExtensionProvider")
        
        deviceSource = sceneitcameraextensionDeviceSource(localizedName: "Scene It Virtual Camera")
        os_log(.info, "[SceneIt Extension] Created device source")
        
        do {
            try provider.addDevice(deviceSource.device)
            os_log(.info, "[SceneIt Extension] Successfully added device to provider")
        } catch {
            os_log(.error, "[SceneIt Extension] Failed to add device to provider: %@", error.localizedDescription)
            fatalError("Failed to add device: \(error.localizedDescription)")
        }
    }
    
    func connect(to client: CMIOExtensionClient) throws {
        // Handle client connect
    }
    
    func disconnect(from client: CMIOExtensionClient) {
        // Handle client disconnect
    }
    
    var availableProperties: Set<CMIOExtensionProperty> {
        return [.providerManufacturer]
    }
    
    func providerProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionProviderProperties {
        let providerProperties = CMIOExtensionProviderProperties(dictionary: [:])
        
        if properties.contains(.providerManufacturer) {
            providerProperties.manufacturer = "Scene It"
        }
        
        return providerProperties
    }
    
    func setProviderProperties(_ providerProperties: CMIOExtensionProviderProperties) throws {
        // Handle settable properties
    }
}