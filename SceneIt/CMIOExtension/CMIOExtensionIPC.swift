import Foundation
import CoreVideo
import CoreMedia
import os.log

/// Modern IPC bridge for CMIOExtension communication
/// Replaces the deprecated DAL plugin shared memory approach
class CMIOExtensionIPC {
    
    private let logger = Logger(subsystem: "com.sceneit.SceneIt", category: "CMIOExtensionIPC")
    
    // CMIOExtension provider
    private var provider: SceneItCMIOProvider?
    private var isInitialized = false
    
    // Frame processing
    private let frameQueue = DispatchQueue(label: "com.sceneit.cmio.ipc", qos: .userInteractive)
    private var frameCount: UInt32 = 0
    private var lastFrameTime = Date()
    
    init() {
        logger.info("CMIOExtensionIPC initializing...")
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Initialization
    
    func initialize() -> Bool {
        guard !isInitialized else {
            logger.info("CMIOExtension IPC already initialized")
            return true
        }
        
        logger.info("Initializing CMIOExtension IPC...")
        
        // Create and start CMIOExtension provider
        provider = SceneItCMIOProvider()
        provider?.startProvider()
        
        isInitialized = true
        logger.info("✅ CMIOExtension IPC initialized successfully")
        return true
    }
    
    func cleanup() {
        guard isInitialized else { return }
        
        logger.info("Cleaning up CMIOExtension IPC...")
        
        // Stop the provider
        provider?.stopProvider()
        provider = nil
        
        isInitialized = false
        logger.info("CMIOExtension IPC cleaned up")
    }
    
    // MARK: - Frame Handling
    
    /// Send a pixel buffer to the CMIOExtension virtual camera
    func sendFrame(_ pixelBuffer: CVPixelBuffer) -> Bool {
        guard isInitialized, let provider = provider else {
            return false
        }
        
        // Send frame to provider
        frameQueue.async { [weak self, weak provider] in
            provider?.sendFrame(pixelBuffer)
            self?.frameCount += 1
            self?.lastFrameTime = Date()
        }
        
        return true
    }
    
    // MARK: - Status and Monitoring
    
    /// Check if the CMIOExtension is connected and ready
    func isPluginConnected() -> Bool {
        guard let provider = provider else { return false }
        return provider.isProviderActive()
    }
    
    /// Legacy compatibility methods
    func installPlugin() -> Bool {
        // CMIOExtension is integrated with the app
        return initialize()
    }
    
    func outputSplashScreen(_ splashImage: CVPixelBuffer) -> Bool {
        return sendFrame(splashImage)
    }
}