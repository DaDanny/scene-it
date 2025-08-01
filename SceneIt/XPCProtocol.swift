import Foundation
import CoreVideo
import CoreMedia

/// Protocol for XPC communication between main app and system extension
@objc protocol SceneItXPCProtocol {
    /// Send a video frame to the virtual camera
    func sendVideoFrame(width: Int, height: Int, pixelData: Data, completion: @escaping (Bool) -> Void)
    
    /// Update stream state (active/inactive)
    func updateStreamState(isActive: Bool, completion: @escaping (Bool) -> Void)
    
    /// Send splash screen when app is inactive
    func sendSplashScreen(width: Int, height: Int, imageData: Data, completion: @escaping (Bool) -> Void)
    
    /// Get extension status
    func getExtensionStatus(completion: @escaping (Bool, String?) -> Void)
    
    /// Set video format
    func setVideoFormat(width: Int, height: Int, frameRate: Double, completion: @escaping (Bool) -> Void)
}

/// Notification names for system extension communication
extension Notification.Name {
    static let virtualCameraStateChanged = Notification.Name("VirtualCameraStateChanged")
    static let systemExtensionStatusChanged = Notification.Name("SystemExtensionStatusChanged")
    static let xpcConnectionEstablished = Notification.Name("XPCConnectionEstablished")
    static let xpcConnectionLost = Notification.Name("XPCConnectionLost")
}

/// Extension status enumeration
enum SystemExtensionStatus: String, CaseIterable {
    case notInstalled = "Not Installed"
    case installing = "Installing"
    case active = "Active"
    case inactive = "Inactive"
    case needsApproval = "Needs Approval"
    case error = "Error"
    
    var displayName: String {
        return self.rawValue
    }
    
    var isOperational: Bool {
        return self == .active
    }
}

/// Video frame data structure for XPC transmission
struct VideoFrameData {
    let width: Int
    let height: Int
    let pixelFormat: OSType
    let data: Data
    let timestamp: CMTime
    
    init(pixelBuffer: CVPixelBuffer) throws {
        self.width = CVPixelBufferGetWidth(pixelBuffer)
        self.height = CVPixelBufferGetHeight(pixelBuffer)
        self.pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        self.timestamp = CMTime.zero // Will be set by receiver
        
        // Lock the pixel buffer for reading
        let lockFlags = CVPixelBufferLockFlags.readOnly
        let lockResult = CVPixelBufferLockBaseAddress(pixelBuffer, lockFlags)
        
        guard lockResult == kCVReturnSuccess else {
            throw VideoFrameError.lockFailed
        }
        
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, lockFlags)
        }
        
        // Get pixel buffer data
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw VideoFrameError.noBaseAddress
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let totalBytes = bytesPerRow * height
        
        // Copy pixel data
        self.data = Data(bytes: baseAddress, count: totalBytes)
    }
    
    func createPixelBuffer() throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        
        let attributes: [String: Any] = [
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        let result = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            pixelFormat,
            attributes as CFDictionary,
            &pixelBuffer
        )
        
        guard result == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw VideoFrameError.creationFailed
        }
        
        // Lock buffer for writing
        let lockResult = CVPixelBufferLockBaseAddress(buffer, [])
        guard lockResult == kCVReturnSuccess else {
            throw VideoFrameError.lockFailed
        }
        
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, [])
        }
        
        // Copy data to buffer
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            throw VideoFrameError.noBaseAddress
        }
        
        data.withUnsafeBytes { bytes in
            memcpy(baseAddress, bytes.baseAddress, data.count)
        }
        
        return buffer
    }
}

/// Video frame processing errors
enum VideoFrameError: Error, LocalizedError {
    case lockFailed
    case noBaseAddress
    case creationFailed
    case invalidFormat
    case insufficientData
    
    var errorDescription: String? {
        switch self {
        case .lockFailed:
            return "Failed to lock pixel buffer"
        case .noBaseAddress:
            return "Pixel buffer has no base address"
        case .creationFailed:
            return "Failed to create pixel buffer"
        case .invalidFormat:
            return "Invalid pixel format"
        case .insufficientData:
            return "Insufficient pixel data"
        }
    }
}