import Foundation
import CoreMedia
import CoreVideo

// Temporary type definitions for CMIOExtension until framework is properly linked
// These will be replaced with actual CMIOExtension types later

/// Placeholder for CMIOExtension until framework is available
class CMIOExtension: NSObject {
    override init() {
        super.init()
    }
}

/// Placeholder for CMIOExtensionProvider protocol
protocol CMIOExtensionProvider: NSObject {
    var providerProperties: [String: Any] { get }
    var availableDevices: [CMIOExtensionDevice] { get }
    func deviceProperties(for device: CMIOExtensionDevice) -> [String: Any]
    func streamProperties(for stream: CMIOExtensionStream) -> [String: Any]
}

/// Placeholder for CMIOExtensionDevice
class CMIOExtensionDevice: NSObject {
    var deviceID: UUID { return UUID() }
    var name: String { return "Ritually Virtual Camera" }
    var manufacturer: String { return "Ritually" }
    var model: String { return "Virtual Camera v2.0" }
    var streams: [CMIOExtensionStream] { return [] }
    
    override init() {
        super.init()
    }
    
    init(localizedName: String, deviceID: UUID) {
        super.init()
    }
}

/// Placeholder for CMIOExtensionStream
class CMIOExtensionStream: NSObject {
    var streamID: UUID { return UUID() }
    var direction: CMIOExtensionStreamDirection { return .source }
    var clockType: CMIOExtensionStreamClockType { return .hostTime }
    var formats: [CMIOExtensionStreamFormat] { return [] }
    var activeFormatIndex: Int { return 0 }
    
    override init() {
        super.init()
    }
    
    init(localizedName: String, streamID: UUID, direction: CMIOExtensionStreamDirection, clockType: CMIOExtensionStreamClockType, source: CMIOExtensionStreamSource?) {
        super.init()
    }
    
    func consumeSampleBuffer(_ sampleBuffer: CMSampleBuffer, completionHandler: @escaping (Result<Void, Error>) -> Void) {
        // Placeholder implementation
        completionHandler(.success(()))
    }
}

/// Placeholder enums and types
enum CMIOExtensionStreamDirection: Int {
    case source = 0
    case sink = 1
}

enum CMIOExtensionStreamClockType: Int {
    case hostTime = 0
    case deviceTime = 1
}

class CMIOExtensionStreamFormat: NSObject {
    init(formatDescription: CMVideoFormatDescription, maxFrameRate: Double, minFrameRate: Double, validFrameRates: [Double]?) {
        super.init()
    }
}

class CMIOExtensionStreamSource: NSObject {
    override init() {
        super.init()
    }
}

// Placeholder property types
enum CMIOExtensionProperty: String {
    case providerName = "providerName"
    case providerManufacturer = "providerManufacturer"
    case providerVersion = "providerVersion"
    case deviceName = "deviceName"
    case deviceManufacturer = "deviceManufacturer"
    case deviceModel = "deviceModel"
    case deviceUID = "deviceUID"
    case streamName = "streamName"
    case streamDirection = "streamDirection"
    case streamFrameRate = "streamFrameRate"
}

class CMIOExtensionPropertyValue: NSObject {
    private let value: Any
    
    init(_ value: Any) {
        self.value = value
        super.init()
    }
}

// Extension-specific types
// Note: CMIOExtensionStreamID = UUID can be defined locally where needed