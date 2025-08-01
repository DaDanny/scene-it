import Foundation
import CoreVideo
import CoreMedia
import os.log

/// XPC client for sending video frames to the system extension
class XPCFrameTransmitter: NSObject {
    private let logger = Logger(subsystem: "com.sceneit.SceneIt", category: "XPCFrameTransmitter")
    
    private var connection: NSXPCConnection?
    private var isConnected = false
    private let connectionQueue = DispatchQueue(label: "com.sceneit.xpc.connection", qos: .userInteractive)
    
    // Connection retry logic
    private let maxRetries = 3
    private var retryCount = 0
    private var reconnectTimer: Timer?
    
    // Performance monitoring
    private var framesSent = 0
    private var lastFrameTime = Date()
    private let performanceInterval: TimeInterval = 5.0
    
    override init() {
        super.init()
        logger.info("XPCFrameTransmitter initializing...")
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - Connection Management
    
    func connect() {
        connectionQueue.async { [weak self] in
            self?._connect()
        }
    }
    
    private func _connect() {
        guard connection == nil else {
            logger.debug("XPC connection already exists")
            return
        }
        
        logger.info("Establishing XPC connection to system extension...")
        
        connection = NSXPCConnection(serviceName: "com.ritually.SceneIt.CameraExtension")
        guard let connection = connection else {
            logger.error("Failed to create XPC connection")
            handleConnectionFailure()
            return
        }
        
        // Set up the XPC interface
        connection.remoteObjectInterface = NSXPCInterface(with: SceneItXPCProtocol.self)
        
        // Set up connection handlers
        connection.interruptionHandler = { [weak self] in
            self?.logger.warning("XPC connection interrupted")
            self?.handleConnectionInterrupted()
        }
        
        connection.invalidationHandler = { [weak self] in
            self?.logger.warning("XPC connection invalidated")
            self?.handleConnectionInvalidated()
        }
        
        // Resume the connection
        connection.resume()
        
        // Test the connection
        testConnection { [weak self] success in
            if success {
                self?.isConnected = true
                self?.retryCount = 0
                self?.logger.info("✅ XPC connection established successfully")
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .xpcConnectionEstablished, object: nil)
                }
            } else {
                self?.handleConnectionFailure()
            }
        }
    }
    
    func disconnect() {
        connectionQueue.async { [weak self] in
            self?._disconnect()
        }
    }
    
    private func _disconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        connection?.invalidationHandler = nil
        connection?.interruptionHandler = nil
        connection?.invalidate()
        connection = nil
        
        isConnected = false
        logger.info("XPC connection disconnected")
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .xpcConnectionLost, object: nil)
        }
    }
    
    private func testConnection(completion: @escaping (Bool) -> Void) {
        guard let connection = connection else {
            completion(false)
            return
        }
        
        let remote = connection.remoteObjectProxyWithErrorHandler { [weak self] error in
            self?.logger.error("XPC connection test failed: \(error.localizedDescription)")
            completion(false)
        } as? SceneItXPCProtocol
        
        remote?.getExtensionStatus { isReady, status in
            completion(isReady)
        }
    }
    
    // MARK: - Connection Error Handling
    
    private func handleConnectionInterrupted() {
        isConnected = false
        logger.warning("Attempting to reconnect after interruption...")
        
        // Attempt immediate reconnection
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.connect()
        }
    }
    
    private func handleConnectionInvalidated() {
        isConnected = false
        connection = nil
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .xpcConnectionLost, object: nil)
        }
    }
    
    private func handleConnectionFailure() {
        retryCount += 1
        
        if retryCount <= maxRetries {
            let delay = TimeInterval(retryCount * 2) // Exponential backoff
            logger.info("Retrying XPC connection in \(delay) seconds (attempt \(retryCount)/\(maxRetries))")
            
            reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.connect()
            }
        } else {
            logger.error("Failed to establish XPC connection after \(maxRetries) attempts")
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .systemExtensionStatusChanged,
                    object: nil,
                    userInfo: ["status": SystemExtensionStatus.error.rawValue]
                )
            }
        }
    }
    
    // MARK: - Frame Transmission
    
    func sendFrame(_ pixelBuffer: CVPixelBuffer, completion: @escaping (Bool) -> Void = { _ in }) {
        guard isConnected, let connection = connection else {
            logger.debug("XPC connection not available for frame transmission")
            completion(false)
            return
        }
        
        do {
            let frameData = try VideoFrameData(pixelBuffer: pixelBuffer)
            
            let remote = connection.remoteObjectProxyWithErrorHandler { [weak self] error in
                self?.logger.error("Frame transmission failed: \(error.localizedDescription)")
                completion(false)
            } as? SceneItXPCProtocol
            
            remote?.sendVideoFrame(
                width: frameData.width,
                height: frameData.height,
                pixelData: frameData.data
            ) { [weak self] success in
                if success {
                    self?.updatePerformanceMetrics()
                }
                completion(success)
            }
            
        } catch {
            logger.error("Failed to create frame data: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    func updateStreamState(isActive: Bool, completion: @escaping (Bool) -> Void = { _ in }) {
        guard isConnected, let connection = connection else {
            logger.debug("XPC connection not available for stream state update")
            completion(false)
            return
        }
        
        let remote = connection.remoteObjectProxyWithErrorHandler { [weak self] error in
            self?.logger.error("Stream state update failed: \(error.localizedDescription)")
            completion(false)
        } as? SceneItXPCProtocol
        
        remote?.updateStreamState(isActive: isActive) { success in
            completion(success)
        }
    }
    
    func sendSplashScreen(_ pixelBuffer: CVPixelBuffer, completion: @escaping (Bool) -> Void = { _ in }) {
        guard isConnected, let connection = connection else {
            logger.debug("XPC connection not available for splash screen")
            completion(false)
            return
        }
        
        do {
            let frameData = try VideoFrameData(pixelBuffer: pixelBuffer)
            
            let remote = connection.remoteObjectProxyWithErrorHandler { [weak self] error in
                self?.logger.error("Splash screen transmission failed: \(error.localizedDescription)")
                completion(false)
            } as? SceneItXPCProtocol
            
            remote?.sendSplashScreen(
                width: frameData.width,
                height: frameData.height,
                imageData: frameData.data
            ) { success in
                completion(success)
            }
            
        } catch {
            logger.error("Failed to create splash screen data: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    func setVideoFormat(width: Int, height: Int, frameRate: Double, completion: @escaping (Bool) -> Void = { _ in }) {
        guard isConnected, let connection = connection else {
            logger.debug("XPC connection not available for format setting")
            completion(false)
            return
        }
        
        let remote = connection.remoteObjectProxyWithErrorHandler { [weak self] error in
            self?.logger.error("Video format setting failed: \(error.localizedDescription)")
            completion(false)
        } as? SceneItXPCProtocol
        
        remote?.setVideoFormat(width: width, height: height, frameRate: frameRate) { success in
            completion(success)
        }
    }
    
    // MARK: - Status and Monitoring
    
    func getConnectionStatus() -> Bool {
        return isConnected
    }
    
    func getExtensionStatus(completion: @escaping (Bool, String?) -> Void) {
        guard isConnected, let connection = connection else {
            completion(false, "XPC connection not available")
            return
        }
        
        let remote = connection.remoteObjectProxyWithErrorHandler { error in
            completion(false, error.localizedDescription)
        } as? SceneItXPCProtocol
        
        remote?.getExtensionStatus(completion: completion)
    }
    
    private func updatePerformanceMetrics() {
        framesSent += 1
        let now = Date()
        let interval = now.timeIntervalSince(lastFrameTime)
        
        if interval >= performanceInterval {
            let fps = Double(framesSent) / interval
            logger.debug("XPC transmission performance: \(String(format: "%.1f", fps)) fps")
            
            framesSent = 0
            lastFrameTime = now
        }
    }
    
    // MARK: - Debugging
    
    func getPerformanceInfo() -> (framesSent: Int, isConnected: Bool, retryCount: Int) {
        return (framesSent, isConnected, retryCount)
    }
}