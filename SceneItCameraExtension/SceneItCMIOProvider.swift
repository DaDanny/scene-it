import Foundation
import CoreMediaIO
import CoreMedia
import CoreVideo
import os.log

/// CoreMediaIO Extension Provider for Ritually Virtual Camera
/// This class manages the virtual camera device and its streams
class SceneItCMIOProvider: NSObject {
    
    private let logger = Logger(subsystem: "com.sceneit.SceneIt", category: "CMIOProvider")
    
    // Provider configuration
    static let providerSource = CMIOExtensionProviderSource(clientQueue: nil) { (deviceID) in
        SceneItCMIODevice(deviceID: deviceID, localizedName: "Ritually Virtual Camera")
    }
    
    private var _streamSource: SceneItCMIOStreamSource?
    private var _deviceSource: CMIOExtensionDeviceSource?
    private var isActive = false
    
    static let deviceID = UUID()
    static let streamID = UUID()
    
    override init() {
        super.init()
        logger.info("SceneItCMIOProvider initializing...")
    }
    
    // MARK: - Public Interface
    
    func startProvider() {
        guard !isActive else { return }
        
        logger.info("Starting CMIOExtension provider...")
        isActive = true
        logger.info("✅ CMIOExtension provider started")
    }
    
    func stopProvider() {
        guard isActive else { return }
        
        logger.info("Stopping CMIOExtension provider...")
        isActive = false
        logger.info("CMIOExtension provider stopped")
    }
    
    func sendFrame(_ pixelBuffer: CVPixelBuffer) {
        guard isActive else { return }
        
        // Send frame to stream source
        _streamSource?.consumeFrame(pixelBuffer)
    }
    
    func isProviderActive() -> Bool {
        return isActive
    }
}

// MARK: - CMIOExtension Device and Stream

class SceneItCMIODevice: CMIOExtensionDeviceSource {
    
    private let logger = Logger(subsystem: "com.sceneit.SceneIt", category: "CMIODevice")
    private let _localizedName: String
    private let _deviceID: UUID
    private var _streamSource: SceneItCMIOStreamSource!
    
    init(deviceID: UUID, localizedName: String) {
        self._localizedName = localizedName
        self._deviceID = deviceID
        super.init(localizedName: localizedName)
        
        let streamID = SceneItCMIOProvider.streamID
        _streamSource = SceneItCMIOStreamSource(localizedName: "Ritually Video Stream", streamID: streamID, direction: .source, clockType: .hostTime, source: self)
        
        logger.info("SceneItCMIODevice initialized")
    }
    
    var deviceID: UUID {
        return _deviceID
    }
    
    override var availableProperties: Set<CMIOExtensionProperty> {
        return [.deviceTransportType, .deviceModel]
    }
    
    override func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
        let deviceProperties = CMIOExtensionDeviceProperties(dictionary: [:])
        if properties.contains(.deviceTransportType) {
            deviceProperties.transportType = kIOAudioDeviceTransportTypeVirtual
        }
        if properties.contains(.deviceModel) {
            deviceProperties.model = "Ritually Virtual Camera v2.0"
        }
        return deviceProperties
    }
    
    override var streams: [CMIOExtensionStreamSource] {
        return [_streamSource]
    }
}

class SceneItCMIOStreamSource: CMIOExtensionStreamSource {
    
    private let logger = Logger(subsystem: "com.sceneit.SceneIt", category: "CMIOStreamSource")
    private var _videoDescription: CMFormatDescription!
    private var _bufferPool: CVPixelBufferPool!
    private var _bufferAuxAttributes: NSDictionary!
    private var _whiteStripeStartRow: UInt32 = 0
    private var _whiteStripeIsAscending: Bool = true
    
    override init(localizedName: String, streamID: UUID, direction: CMIOExtensionStreamDirection, clockType: CMIOExtensionStreamClockType, source: CMIOExtensionDeviceSource) {
        super.init(localizedName: localizedName, streamID: streamID, direction: direction, clockType: clockType, source: source)
        
        let dimensions = CMVideoDimensions(width: 1920, height: 1080)
        CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: kCVPixelFormatType_32BGRA, width: dimensions.width, height: dimensions.height, extensions: nil, formatDescriptionOut: &_videoDescription)
        
        let pixelBufferAttributes: NSDictionary = [
            kCVPixelBufferWidthKey: dimensions.width,
            kCVPixelBufferHeightKey: dimensions.height,
            kCVPixelBufferPixelFormatTypeKey: _videoDescription.mediaSubType,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, pixelBufferAttributes, &_bufferPool)
        
        let videoSettings: NSDictionary = [
            kCVPixelBufferWidthKey: dimensions.width,
            kCVPixelBufferHeightKey: dimensions.height,
            kCVPixelBufferPixelFormatTypeKey: _videoDescription.mediaSubType,
        ]
        
        _bufferAuxAttributes = [kCVPixelBufferPoolAllocationThresholdKey: 5]
        
        logger.info("SceneItCMIOStreamSource initialized")
    }
    
    override var availableProperties: Set<CMIOExtensionProperty> {
        return [.streamActiveFormatIndex, .streamFrameDuration]
    }
    
    override func streamProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionStreamProperties {
        let streamProperties = CMIOExtensionStreamProperties(dictionary: [:])
        if properties.contains(.streamActiveFormatIndex) {
            streamProperties.activeFormatIndex = 0
        }
        if properties.contains(.streamFrameDuration) {
            let frameDuration = CMTime(value: 1, timescale: 30)
            streamProperties.frameDuration = frameDuration
        }
        return streamProperties
    }
    
    override var formats: [CMIOExtensionStreamFormat] {
        let streamFormat = CMIOExtensionStreamFormat.init(formatDescription: _videoDescription, maxFrameRate: 60, minFrameRate: 1, validFrameRates: nil)
        return [streamFormat]
    }
    
    override func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool {
        logger.info("Client authorized to start stream")
        return true
    }
    
    override func startStream() throws {
        logger.info("Starting stream")
        super.streamingCounter += 1
    }
    
    override func stopStream() throws {
        logger.info("Stopping stream")
        super.streamingCounter -= 1
    }
    
    func consumeFrame(_ pixelBuffer: CVPixelBuffer) {
        guard streamingCounter > 0 else { return }
        
        var err: OSStatus = 0
        let timestamp = CMClockGetTime(CMClockGetHostTimeClock())
        
        var timingInfo = CMSampleTimingInfo()
        timingInfo.presentationTimeStamp = timestamp
        timingInfo.duration = CMTime(value: 1, timescale: 30)
        
        var sbuf: CMSampleBuffer!
        err = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: _videoDescription, sampleTiming: &timingInfo, sampleBufferOut: &sbuf)
        
        if err == 0 {
            consumeSampleBuffer(sbuf) { (err: OSStatus) -> Void in
                if err != 0 {
                    self.logger.error("consumeSampleBuffer error: \(err)")
                }
            }
        } else {
            logger.error("CMSampleBufferCreateForImageBuffer error: \(err)")
        }
    }
}