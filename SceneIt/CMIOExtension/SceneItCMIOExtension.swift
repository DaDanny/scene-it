import Foundation
import CoreMediaIO
import CoreMedia
import CoreVideo
import os.log

/// Modern CMIOExtension-based virtual camera device for Scene It
class SceneItCMIOExtension: CMIOExtension {
    
    private let logger = Logger(subsystem: "com.sceneit.SceneIt", category: "CMIOExtension")
    
    // Extension configuration
    private let deviceID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!
    private let sourceID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440001")!
    
    // Virtual camera properties
    private let deviceName = "Scene It Virtual Camera"
    private let deviceManufacturer = "Scene It"
    private let deviceModel = "Virtual Camera v2.0"
    
    // Video format configuration
    private let videoFormat = CMFormatDescription.create(
        mediaType: .video,
        mediaSubType: .init("420v"), // kCVPixelFormatType_420YpCbCr8BiPlanar
        formatSpecificExtensions: nil
    )
    
    // Frame rate and timing
    private let frameRate: Double = 30.0
    private var clockSource: CMClockRef?
    
    override init() {
        super.init()
        logger.info("SceneItCMIOExtension initializing...")
        setupClockSource()
    }
    
    private func setupClockSource() {
        var clock: Unmanaged<CMClock>?
        let status = CMClockGetHostTimeClock(&clock)
        if status == noErr {
            clockSource = clock?.takeRetainedValue()
            logger.info("Clock source configured successfully")
        } else {
            logger.error("Failed to setup clock source: \(status)")
        }
    }
    
    // MARK: - CMIOExtension Delegate Methods
    
    override func availableStreamProperties(for streamID: CMIOStreamID) -> Set<CMIOObjectPropertyAddress> {
        var properties = Set<CMIOObjectPropertyAddress>()
        
        // Add required stream properties
        properties.insert(CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOObjectPropertyName),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        ))
        
        properties.insert(CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOStreamPropertyFormatDescription),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        ))
        
        properties.insert(CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOStreamPropertyFrameRate),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        ))
        
        logger.debug("Available stream properties: \(properties.count)")
        return properties
    }
    
    override func availableDeviceProperties(for deviceID: CMIODeviceID) -> Set<CMIOObjectPropertyAddress> {
        var properties = Set<CMIOObjectPropertyAddress>()
        
        // Add required device properties
        properties.insert(CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOObjectPropertyName),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        ))
        
        properties.insert(CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOObjectPropertyManufacturer),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        ))
        
        properties.insert(CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyStreams),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        ))
        
        logger.debug("Available device properties: \(properties.count)")
        return properties
    }
    
    override func devicePropertyValue(for property: CMIOObjectPropertyAddress, 
                                    deviceID: CMIODeviceID) throws -> Any {
        logger.debug("Getting device property: \(property.mSelector)")
        
        switch property.mSelector {
        case CMIOObjectPropertySelector(kCMIOObjectPropertyName):
            return deviceName
            
        case CMIOObjectPropertySelector(kCMIOObjectPropertyManufacturer):
            return deviceManufacturer
            
        case CMIOObjectPropertySelector(kCMIOObjectPropertyModelUID):
            return deviceModel
            
        case CMIOObjectPropertySelector(kCMIODevicePropertyStreams):
            return [sourceID]
            
        default:
            logger.warning("Unknown device property requested: \(property.mSelector)")
            throw CMIOExtensionError(.unknown)
        }
    }
    
    override func streamPropertyValue(for property: CMIOObjectPropertyAddress, 
                                    streamID: CMIOStreamID) throws -> Any {
        logger.debug("Getting stream property: \(property.mSelector)")
        
        switch property.mSelector {
        case CMIOObjectPropertySelector(kCMIOObjectPropertyName):
            return "Scene It Video Stream"
            
        case CMIOObjectPropertySelector(kCMIOStreamPropertyFormatDescription):
            guard let formatDescription = videoFormat else {
                throw CMIOExtensionError(.invalidPropertyData)
            }
            return formatDescription
            
        case CMIOObjectPropertySelector(kCMIOStreamPropertyFrameRate):
            return frameRate
            
        case CMIOObjectPropertySelector(kCMIOStreamPropertyMinimumFrameRate):
            return 1.0
            
        case CMIOObjectPropertySelector(kCMIOStreamPropertyMaximumFrameRate):
            return 60.0
            
        default:
            logger.warning("Unknown stream property requested: \(property.mSelector)")
            throw CMIOExtensionError(.unknown)
        }
    }
    
    // MARK: - Stream Management
    
    override func startStream(streamID: CMIOStreamID) throws {
        logger.info("Starting stream: \(streamID)")
        
        guard streamID == sourceID else {
            logger.error("Invalid stream ID: \(streamID)")
            throw CMIOExtensionError(.invalidStreamID)
        }
        
        // Notify the main app that streaming has started
        NotificationCenter.default.post(
            name: .cmioExtensionStreamStarted,
            object: nil,
            userInfo: ["streamID": streamID]
        )
        
        logger.info("Stream started successfully")
    }
    
    override func stopStream(streamID: CMIOStreamID) throws {
        logger.info("Stopping stream: \(streamID)")
        
        guard streamID == sourceID else {
            logger.error("Invalid stream ID: \(streamID)")
            throw CMIOExtensionError(.invalidStreamID)
        }
        
        // Notify the main app that streaming has stopped
        NotificationCenter.default.post(
            name: .cmioExtensionStreamStopped,
            object: nil,
            userInfo: ["streamID": streamID]
        )
        
        logger.info("Stream stopped successfully")
    }
    
    // MARK: - Frame Output
    
    /// Send a frame to the virtual camera stream
    func sendFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        guard let clockSource = clockSource else {
            logger.error("No clock source available for frame timing")
            return
        }
        
        let sampleBuffer = createSampleBuffer(from: pixelBuffer, timestamp: timestamp)
        
        // Deliver frame to CMIOExtension
        deliverSampleBuffer(sampleBuffer, to: sourceID) { [weak self] result in
            switch result {
            case .success():
                self?.logger.debug("Frame delivered successfully")
            case .failure(let error):
                self?.logger.error("Failed to deliver frame: \(error)")
            }
        }
    }
    
    private func createSampleBuffer(from pixelBuffer: CVPixelBuffer, timestamp: CMTime) -> CMSampleBuffer {
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: Int32(frameRate)),
            presentationTimeStamp: timestamp,
            decodeTimeStamp: .invalid
        )
        
        let status = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: videoFormat!,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        guard status == noErr, let buffer = sampleBuffer else {
            logger.error("Failed to create sample buffer: \(status)")
            // Return empty sample buffer as fallback
            fatalError("Unable to create sample buffer")
        }
        
        return buffer
    }
    
    // MARK: - Device Management
    
    func getDeviceID() -> UUID {
        return deviceID
    }
    
    func getSourceID() -> UUID {
        return sourceID
    }
    
    func isStreamActive() -> Bool {
        // Check if the stream is currently active
        // This would be determined by CMIOExtension framework
        return true // Simplified for now
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let cmioExtensionStreamStarted = Notification.Name("CMIOExtensionStreamStarted")
    static let cmioExtensionStreamStopped = Notification.Name("CMIOExtensionStreamStopped")
}

// MARK: - CMIOExtensionError

enum CMIOExtensionError: Error {
    case unknown
    case invalidPropertyData
    case invalidStreamID
    case streamNotFound
    case deviceNotFound
    
    var localizedDescription: String {
        switch self {
        case .unknown:
            return "Unknown CMIOExtension error"
        case .invalidPropertyData:
            return "Invalid property data"
        case .invalidStreamID:
            return "Invalid stream ID"
        case .streamNotFound:
            return "Stream not found"
        case .deviceNotFound:
            return "Device not found"
        }
    }
}