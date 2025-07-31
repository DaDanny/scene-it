import Foundation
import CoreVideo
import System

/// IPC Bridge for communicating with the DAL plugin
class VirtualCameraIPC {
    
    // Constants matching the C++ plugin
    private static let sharedMemoryName = "com.sceneit.virtualcamera.sharedmem"
    private static let semaphoreName = "com.sceneit.virtualcamera.semaphore"
    private static let maxFrameSize = 1920 * 1080 * 4 // RGBA32
    private static let frameRingBufferSize = 8
    
    // Shared memory structure matching C++
    private struct SceneItFrameMetadata {
        var width: UInt32
        var height: UInt32
        var bytesPerRow: UInt32
        var pixelFormat: UInt32
        var timestamp: UInt64
        var frameIndex: UInt32
        var isValid: Bool
        
        init() {
            width = 0
            height = 0
            bytesPerRow = 0
            pixelFormat = 0
            timestamp = 0
            frameIndex = 0
            isValid = false
        }
    }
    
    private struct SceneItSharedMemory {
        var writeIndex: UInt32
        var readIndex: UInt32
        var frameCount: UInt32
        var frames: [SceneItFrameMetadata]
        // Note: frameData is handled separately due to large size
        
        init() {
            writeIndex = 0
            readIndex = 0
            frameCount = 0
            frames = Array(repeating: SceneItFrameMetadata(), count: VirtualCameraIPC.frameRingBufferSize)
        }
    }
    
    // IPC state
    private var sharedMemoryFD: Int32 = -1
    private var sharedMemoryPtr: UnsafeMutableRawPointer?
    private var semaphore: DispatchSemaphore?
    private var isInitialized = false
    
    // Initialization
    func initialize() -> Bool {
        guard !isInitialized else { return true }
        
        // Create/open shared memory
        sharedMemoryFD = shm_open(VirtualCameraIPC.sharedMemoryName, O_CREAT | O_RDWR, 0o666)
        guard sharedMemoryFD != -1 else {
            print("Failed to create shared memory: \(String(cString: strerror(errno)))")
            return false
        }
        
        // Calculate total shared memory size
        let metadataSize = MemoryLayout<SceneItSharedMemory>.size
        let frameDataSize = VirtualCameraIPC.maxFrameSize * VirtualCameraIPC.frameRingBufferSize
        let totalSize = metadataSize + frameDataSize
        
        // Set shared memory size
        if ftruncate(sharedMemoryFD, Int64(totalSize)) != 0 {
            print("Failed to set shared memory size: \(String(cString: strerror(errno)))")
            cleanup()
            return false
        }
        
        // Map shared memory
        sharedMemoryPtr = mmap(nil, totalSize, PROT_READ | PROT_WRITE, MAP_SHARED, sharedMemoryFD, 0)
        guard sharedMemoryPtr != MAP_FAILED else {
            print("Failed to map shared memory: \(String(cString: strerror(errno)))")
            cleanup()
            return false
        }
        
        // Initialize shared memory structure
        sharedMemoryPtr?.initializeMemory(as: UInt8.self, repeating: 0, count: totalSize)
        
        // Initialize semaphore
        semaphore = DispatchSemaphore(value: 0)
        
        isInitialized = true
        print("✅ VirtualCameraIPC initialized successfully")
        return true
    }
    
    func cleanup() {
        if let ptr = sharedMemoryPtr, ptr != MAP_FAILED {
            let metadataSize = MemoryLayout<SceneItSharedMemory>.size
            let frameDataSize = VirtualCameraIPC.maxFrameSize * VirtualCameraIPC.frameRingBufferSize
            let totalSize = metadataSize + frameDataSize
            
            munmap(ptr, totalSize)
            sharedMemoryPtr = nil
        }
        
        if sharedMemoryFD != -1 {
            close(sharedMemoryFD)
            shm_unlink(VirtualCameraIPC.sharedMemoryName)
            sharedMemoryFD = -1
        }
        
        semaphore = nil
        isInitialized = false
        
        print("VirtualCameraIPC cleaned up")
    }
    
    deinit {
        cleanup()
    }
    
    /// Send a pixel buffer to the virtual camera plugin
    func sendFrame(_ pixelBuffer: CVPixelBuffer) -> Bool {
        guard isInitialized, let sharedMemoryPtr = sharedMemoryPtr else {
            return false
        }
        
        // Get pixel buffer properties
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        
        // Validate frame size
        let frameSize = height * bytesPerRow
        guard frameSize <= VirtualCameraIPC.maxFrameSize else {
            print("Frame too large: \(frameSize) bytes (max: \(VirtualCameraIPC.maxFrameSize))")
            return false
        }
        
        // Lock pixel buffer for reading
        guard CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) == kCVReturnSuccess else {
            return false
        }
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return false
        }
        
        // Get shared memory pointers
        let metadataPtr = sharedMemoryPtr.assumingMemoryBound(to: SceneItSharedMemory.self)
        let frameDataPtr = sharedMemoryPtr.advanced(by: MemoryLayout<SceneItSharedMemory>.size)
        
        // Get current write index
        let writeIndex = metadataPtr.pointee.writeIndex
        let nextWriteIndex = (writeIndex + 1) % UInt32(VirtualCameraIPC.frameRingBufferSize)
        
        // Check if buffer is full
        if metadataPtr.pointee.frameCount >= UInt32(VirtualCameraIPC.frameRingBufferSize) {
            // Buffer full, skip frame
            return false
        }
        
        // Copy frame data
        let frameOffset = Int(writeIndex) * VirtualCameraIPC.maxFrameSize
        let destinationPtr = frameDataPtr.advanced(by: frameOffset)
        memcpy(destinationPtr, baseAddress, frameSize)
        
        // Update metadata
        let metadataOffset = MemoryLayout<SceneItFrameMetadata>.stride * Int(writeIndex)
        let frameMetadataPtr = sharedMemoryPtr.advanced(by: metadataOffset).assumingMemoryBound(to: SceneItFrameMetadata.self)
        
        frameMetadataPtr.pointee.width = UInt32(width)
        frameMetadataPtr.pointee.height = UInt32(height)
        frameMetadataPtr.pointee.bytesPerRow = UInt32(bytesPerRow)
        frameMetadataPtr.pointee.pixelFormat = pixelFormat
        frameMetadataPtr.pointee.timestamp = mach_absolute_time()
        frameMetadataPtr.pointee.frameIndex = metadataPtr.pointee.frameCount
        frameMetadataPtr.pointee.isValid = true
        
        // Update write index and frame count atomically
        OSAtomicIncrement32(&metadataPtr.pointee.frameCount)
        metadataPtr.pointee.writeIndex = nextWriteIndex
        
        // Signal frame availability
        semaphore?.signal()
        
        return true
    }
    
    /// Check if the plugin is connected and consuming frames
    func isPluginConnected() -> Bool {
        guard isInitialized, let sharedMemoryPtr = sharedMemoryPtr else {
            return false
        }
        
        let metadataPtr = sharedMemoryPtr.assumingMemoryBound(to: SceneItSharedMemory.self)
        
        // Check if frames are being consumed (frame count should be reasonable)
        let frameCount = metadataPtr.pointee.frameCount
        return frameCount < UInt32(VirtualCameraIPC.frameRingBufferSize)
    }
    
    /// Get current buffer status for debugging
    func getBufferStatus() -> (writeIndex: UInt32, readIndex: UInt32, frameCount: UInt32) {
        guard isInitialized, let sharedMemoryPtr = sharedMemoryPtr else {
            return (0, 0, 0)
        }
        
        let metadataPtr = sharedMemoryPtr.assumingMemoryBound(to: SceneItSharedMemory.self)
        return (
            writeIndex: metadataPtr.pointee.writeIndex,
            readIndex: metadataPtr.pointee.readIndex,
            frameCount: metadataPtr.pointee.frameCount
        )
    }
}

// MARK: - C Function Imports

private func shm_open(_ name: UnsafePointer<CChar>, _ oflag: Int32, _ mode: mode_t) -> Int32 {
    return Darwin.shm_open(name, oflag, mode)
}

private func shm_unlink(_ name: UnsafePointer<CChar>) -> Int32 {
    return Darwin.shm_unlink(name)
}