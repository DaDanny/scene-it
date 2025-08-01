//
//  SceneItCameraExtensionProvider.swift
//  SceneItCameraExtension
//
//  Created by Danny Francken on 8/1/25.
//  Copyright © 2025 dannyfrancken. All rights reserved.
//

import Foundation
import CoreMediaIO
import IOKit.audio
import os.log
import CoreMedia
import CoreVideo

// MARK: - Provider Source

class SceneItCameraExtensionProviderSource: NSObject, CMIOExtensionProviderSource {
    
    private let logger = Logger(subsystem: "com.dannyfrancken.sceneit.cameraextension", category: "ProviderSource")
    
    private(set) var provider: CMIOExtensionProvider!
    
    init(clientQueue: DispatchQueue?) {
        super.init()
        
        provider = CMIOExtensionProvider(source: self, clientQueue: clientQueue)
        logger.info("SceneItCameraExtensionProviderSource initialized")
    }
    
    // MARK: CMIOExtensionProviderSource
    
    func connect(to client: CMIOExtensionClient) throws {
        logger.info("Client connected: \(client)")
    }
    
    func disconnect(from client: CMIOExtensionClient) {
        logger.info("Client disconnected: \(client)")
    }
    
    var availableProperties: Set<CMIOExtensionProperty> {
        return [.providerManufacturer, .providerName]
    }
    
    func providerProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionProviderProperties {
        let providerProperties = CMIOExtensionProviderProperties(dictionary: [:])
        if properties.contains(.providerManufacturer) {
            providerProperties.manufacturer = "Ritually"
        }
        if properties.contains(.providerName) {
            providerProperties.name = "SceneIt Virtual Camera Provider"
        }
        return providerProperties
    }
    
    func setProviderProperties(_ providerProperties: CMIOExtensionProviderProperties) throws {
        // Handle property changes if needed
    }
    
    var devices: [CMIOExtensionDeviceSource] {
        return [_deviceSource]
    }
    
    private lazy var _deviceSource: SceneItCameraExtensionDeviceSource = {
        return SceneItCameraExtensionDeviceSource(localizedName: "SceneIt Virtual Camera")
    }()
}

// MARK: - Device Source

class SceneItCameraExtensionDeviceSource: NSObject, CMIOExtensionDeviceSource {
    
    private let logger = Logger(subsystem: "com.dannyfrancken.sceneit.cameraextension", category: "DeviceSource")
    
    private(set) var device: CMIOExtensionDevice!
    private var _streamSource: SceneItCameraExtensionStreamSource!
    private var _streamingCounter: UInt32 = 0
    private var _timer: DispatchSourceTimer?
    private let _timerQueue = DispatchQueue(label: "timerQueue", qos: .userInteractive, attributes: [], autoreleaseFrequency: .workItem, target: .global(qos: .userInteractive))
    
    private var _videoDescription: CMFormatDescription!
    private var _bufferPool: CVPixelBufferPool!
    private var _bufferAuxAttributes: NSDictionary!
    
    init(localizedName: String) {
        super.init()
        
        let deviceID = UUID()
        self.device = CMIOExtensionDevice(localizedName: localizedName, deviceID: deviceID, legacyDeviceID: nil, source: self)
        
        // Set up video format (1920x1080 BGRA)
        let dims = CMVideoDimensions(width: 1920, height: 1080)
        CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: kCVPixelFormatType_32BGRA, width: dims.width, height: dims.height, extensions: nil, formatDescriptionOut: &_videoDescription)
        
        let pixelBufferAttributes: NSDictionary = [
            kCVPixelBufferWidthKey: dims.width,
            kCVPixelBufferHeightKey: dims.height,
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, pixelBufferAttributes, &_bufferPool)
        
        let videoStreamFormat = CMIOExtensionStreamFormat.init(formatDescription: _videoDescription, maxFrameDuration: CMTime(value: 1, timescale: Int32(kFrameRate)), minFrameDuration: CMTime(value: 1, timescale: Int32(kFrameRate)), validFrameDurations: nil)
        _bufferAuxAttributes = [kCVPixelBufferPoolAllocationThresholdKey: 5]
        
        let videoID = UUID()
        _streamSource = SceneItCameraExtensionStreamSource(localizedName: "SceneIt Video Stream", streamID: videoID, direction: .source, clockType: .hostTime, source: self)
        // Stream format is handled in the formats property of the stream source
        
        logger.info("SceneItCameraExtensionDeviceSource initialized")
    }
    
    var availableProperties: Set<CMIOExtensionProperty> {
        return [.deviceTransportType, .deviceModel]
    }
    
    func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
        let deviceProperties = CMIOExtensionDeviceProperties(dictionary: [:])
        if properties.contains(.deviceTransportType) {
            deviceProperties.transportType = kIOAudioDeviceTransportTypeVirtual
        }
        if properties.contains(.deviceModel) {
            deviceProperties.model = "SceneIt Virtual Camera v1.0"
        }
        return deviceProperties
    }
    
    func setDeviceProperties(_ deviceProperties: CMIOExtensionDeviceProperties) throws {
        // Handle property changes if needed
    }
    
    var streams: [CMIOExtensionStreamSource] {
        return [_streamSource]
    }
    
    // MARK: - Stream Management
    
    func startStreaming(to clients: Set<CMIOExtensionClient>) {
        logger.info("Stream starting for \(clients.count) clients")
        
        guard _timer == nil else {
            return
        }
        
        _timer = DispatchSource.makeTimerSource(flags: .strict, queue: _timerQueue)
        _timer!.schedule(deadline: .now(), repeating: 1.0 / Double(kFrameRate), leeway: .seconds(0))
        
        _timer!.setEventHandler { [weak self] in
            self?._generateAndSendFrame()
        }
        
        _timer!.resume()
    }
    
    func stopStreaming(from clients: Set<CMIOExtensionClient>) {
        logger.info("Stream stopping for \(clients.count) clients")
        
        if clients.isEmpty {
            _timer?.cancel()
            _timer = nil
        }
    }
    
    private func _generateAndSendFrame() {
        var pixelBuffer: CVPixelBuffer?
        
        let ret = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, _bufferPool, _bufferAuxAttributes, &pixelBuffer)
        
        guard let pixelBuffer = pixelBuffer, ret == kCVReturnSuccess else {
            logger.error("Failed to create pixel buffer")
            return
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        // Generate a simple test pattern (can be replaced with actual video frames)
        _fillPixelBufferWithTestPattern(pixelBuffer)
        
        _streamSource.consumeBuffer(pixelBuffer, timestamp: CMClockGetTime(CMClockGetHostTimeClock()), discontinuity: [], noDataMarker: false)
        _streamingCounter += 1
    }
    
    private func _fillPixelBufferWithTestPattern(_ pixelBuffer: CVPixelBuffer) {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        
        let buffer = baseAddress.assumingMemoryBound(to: UInt32.self)
        
        // Create a simple gradient pattern
        for y in 0..<height {
            for x in 0..<width {
                let index = y * (bytesPerRow / 4) + x
                let red = UInt32((x * 255) / width)
                let green = UInt32((y * 255) / height)
                let blue = UInt32(128)
                let alpha = UInt32(255)
                
                // BGRA format
                buffer[index] = (alpha << 24) | (red << 16) | (green << 8) | blue
            }
        }
    }
}

// MARK: - Stream Source

class SceneItCameraExtensionStreamSource: NSObject, CMIOExtensionStreamSource {
    
    private let logger = Logger(subsystem: "com.dannyfrancken.sceneit.cameraextension", category: "StreamSource")
    
    private(set) var stream: CMIOExtensionStream!
    
    let streamFormat: CMIOExtensionStreamFormat
    
    // MARK: - CMIOExtensionStreamSource Required Properties
    
    var formats: [CMIOExtensionStreamFormat] {
        return [streamFormat]
    }
    
    init(localizedName: String, streamID: UUID, direction: CMIOExtensionStream.Direction, clockType: CMIOExtensionStream.ClockType, source: CMIOExtensionDeviceSource) {
        
        // Create a basic stream format for now
        let dims = CMVideoDimensions(width: 1920, height: 1080)
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: kCVPixelFormatType_32BGRA, width: dims.width, height: dims.height, extensions: nil, formatDescriptionOut: &formatDescription)
        
        streamFormat = CMIOExtensionStreamFormat.init(formatDescription: formatDescription!, maxFrameDuration: CMTime(value: 1, timescale: Int32(kFrameRate)), minFrameDuration: CMTime(value: 1, timescale: Int32(kFrameRate)), validFrameDurations: nil)
        
        super.init()
        
        self.stream = CMIOExtensionStream(localizedName: localizedName, streamID: streamID, direction: direction, clockType: clockType, source: self)
        
        logger.info("SceneItCameraExtensionStreamSource initialized")
    }
    
    // Note: addStreamFormat is not available in current API
    
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
        // Handle property changes if needed
    }
    
    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool {
        return true
    }
    
    func startStream() throws {
        logger.info("Stream started")
    }
    
    func stopStream() throws {
        logger.info("Stream stopped")
    }
    
    func consumeBuffer(_ buffer: CVPixelBuffer, timestamp: CMTime, discontinuity: CMIOExtensionStream.DiscontinuityFlags, noDataMarker: Bool) {
        // Create a sample buffer from the pixel buffer
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime.invalid,
            presentationTimeStamp: timestamp,
            decodeTimeStamp: CMTime.invalid
        )
        
        var formatDescription: CMFormatDescription?
        let status1 = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            formatDescriptionOut: &formatDescription
        )
        
        guard status1 == noErr, let formatDescription = formatDescription else {
            logger.error("Failed to create format description")
            return
        }
        
        let status = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            formatDescription: formatDescription,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        guard status == noErr, let sampleBuffer = sampleBuffer else {
            logger.error("Failed to create sample buffer: \(status)")
            return
        }
        
        let hostTime = mach_absolute_time()
        stream.send(sampleBuffer, discontinuity: discontinuity, hostTimeInNanoseconds: hostTime)
    }
    
    // MARK: - CMIOExtensionStreamSource Protocol Methods
    
    func send(_ sampleBuffer: CMSampleBuffer, discontinuity: CMIOExtensionStream.DiscontinuityFlags, hostTimeInNanoseconds: UInt64) {
        // Send sample buffer to the stream
        stream.send(sampleBuffer, discontinuity: discontinuity, hostTimeInNanoseconds: hostTimeInNanoseconds)
    }
    
    func notifyScheduledOutputChanged(_ scheduledOutput: CMIOExtensionScheduledOutput) {
        // Handle scheduled output changes
    }
}

// MARK: - Constants

let kFrameRate: Int = 30