import Foundation
import CoreVideo
import CoreMedia
import CoreMediaIO
import os.log

/// XPC service implementation for the system extension
/// Receives video frames from the main app and feeds them to the CMIO stream
class XPCFrameReceiver: NSObject, SceneItXPCProtocol {
    private let logger = Logger(subsystem: "com.ritually.SceneIt.CameraExtension", category: "XPCFrameReceiver")
    
    private var cmioProvider: SceneItCMIOProvider?
    private var isActive = false
    private var currentVideoFormat: (width: Int, height: Int, frameRate: Double)?
    
    // Frame processing
    private let frameQueue = DispatchQueue(label: "com.sceneit.extension.frames", qos: .userInteractive)
    private var framesReceived = 0
    private var lastFrameTime = Date()
    
    override init() {
        super.init()
        logger.info("XPCFrameReceiver initializing...")
        
        // Initialize the CMIO provider
        cmioProvider = SceneItCMIOProvider()
        cmioProvider?.startProvider()
        
        logger.info("✅ XPCFrameReceiver initialized with CMIO provider")
    }
    
    deinit {
        cmioProvider?.stopProvider()
        logger.info("XPCFrameReceiver deinitialized")
    }
    
    // MARK: - SceneItXPCProtocol Implementation
    
    func sendVideoFrame(width: Int, height: Int, pixelData: Data, completion: @escaping (Bool) -> Void) {
        frameQueue.async { [weak self] in
            self?._sendVideoFrame(width: width, height: height, pixelData: pixelData, completion: completion)
        }
    }
    
    private func _sendVideoFrame(width: Int, height: Int, pixelData: Data, completion: @escaping (Bool) -> Void) {
        guard isActive, let provider = cmioProvider else {
            logger.debug("Cannot send frame - provider inactive")
            completion(false)
            return
        }
        
        do {
            // Create pixel buffer from received data
            let pixelBuffer = try createPixelBuffer(width: width, height: height, data: pixelData)
            
            // Send frame to CMIO provider
            provider.sendFrame(pixelBuffer)
            
            // Update performance metrics
            updatePerformanceMetrics()
            
            completion(true)
            
        } catch {
            logger.error("Failed to process video frame: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    func updateStreamState(isActive: Bool, completion: @escaping (Bool) -> Void) {
        logger.info("Stream state update: \(isActive ? "active" : "inactive")")
        
        self.isActive = isActive
        
        if isActive {
            cmioProvider?.startProvider()
        } else {
            // Don't stop provider completely, just mark as inactive
            // The provider should continue running to maintain device registration
        }
        
        completion(true)
    }
    
    func sendSplashScreen(width: Int, height: Int, imageData: Data, completion: @escaping (Bool) -> Void) {
        frameQueue.async { [weak self] in
            self?._sendSplashScreen(width: width, height: height, imageData: imageData, completion: completion)
        }
    }
    
    private func _sendSplashScreen(width: Int, height: Int, imageData: Data, completion: @escaping (Bool) -> Void) {
        guard let provider = cmioProvider else {
            completion(false)
            return
        }
        
        do {
            // Create pixel buffer from splash screen data
            let pixelBuffer = try createPixelBuffer(width: width, height: height, data: imageData)
            
            // Send splash screen to CMIO provider
            provider.sendFrame(pixelBuffer)
            
            logger.debug("Splash screen sent to CMIO provider")
            completion(true)
            
        } catch {
            logger.error("Failed to send splash screen: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    func getExtensionStatus(completion: @escaping (Bool, String?) -> Void) {
        guard let provider = cmioProvider else {
            completion(false, "CMIO provider not available")
            return
        }
        
        let isReady = provider.isProviderActive()
        let status = isReady ? "Extension active and ready" : "Extension inactive"
        
        logger.debug("Extension status check: \(status)")
        completion(isReady, status)
    }
    
    func setVideoFormat(width: Int, height: Int, frameRate: Double, completion: @escaping (Bool) -> Void) {
        logger.info("Setting video format: \(width)x\(height)@\(frameRate)fps")
        
        currentVideoFormat = (width, height, frameRate)
        
        // Configure the CMIO provider with the new format
        // This would typically involve updating stream properties
        completion(true)
    }
    
    // MARK: - Private Methods
    
    private func createPixelBuffer(width: Int, height: Int, data: Data) throws -> CVPixelBuffer {
        let expectedDataSize = width * height * 4 // BGRA = 4 bytes per pixel
        guard data.count >= expectedDataSize else {
            throw VideoFrameError.insufficientData
        }
        
        var pixelBuffer: CVPixelBuffer?
        
        let attributes: [String: Any] = [
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        let result = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
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
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let sourceBytes = data.withUnsafeBytes { $0.baseAddress! }
        
        // Copy row by row to handle potential padding
        for row in 0..<height {
            let srcOffset = row * width * 4
            let dstOffset = row * bytesPerRow
            memcpy(baseAddress + dstOffset, sourceBytes + srcOffset, width * 4)
        }
        
        return buffer
    }
    
    private func updatePerformanceMetrics() {
        framesReceived += 1
        let now = Date()
        let interval = now.timeIntervalSince(lastFrameTime)
        
        if interval >= 5.0 { // Log every 5 seconds
            let fps = Double(framesReceived) / interval
            logger.debug("Extension performance: \(String(format: "%.1f", fps)) fps received")
            
            framesReceived = 0
            lastFrameTime = now
        }
    }
    
    // MARK: - Public Interface
    
    func getPerformanceInfo() -> (framesReceived: Int, isActive: Bool) {
        return (framesReceived, isActive)
    }
}