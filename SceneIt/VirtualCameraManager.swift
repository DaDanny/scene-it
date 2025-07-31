import AVFoundation
import CoreMediaIO
import CoreMedia
import CoreImage
import CoreVideo
import Foundation
import AppKit

enum VirtualCameraError: Error {
    case sessionCreationFailed
    case noVideoDeviceAvailable
    case videoInputCreationFailed(Error)
    case videoOutputSetupFailed
    case permissionDenied
    
    var localizedDescription: String {
        switch self {
        case .sessionCreationFailed:
            return "Failed to create capture session"
        case .noVideoDeviceAvailable:
            return "No video device available"
        case .videoInputCreationFailed(let error):
            return "Failed to create video input: \(error.localizedDescription)"
        case .videoOutputSetupFailed:
            return "Failed to set up video output"
        case .permissionDenied:
            return "Camera permission denied"
        }
    }
}

class VirtualCameraManager: NSObject, ObservableObject {
    @Published var isActive = false
    @Published var errorMessage: String?
    @Published var isPluginConnected = false
    @Published var frameRate: Double = 0.0
    
    var captureSession: AVCaptureSession? { return privateCaptureSession }
    
    private var privateCaptureSession: AVCaptureSession?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var virtualCameraOutput: AVCaptureVideoDataOutput?
    
    private var currentOverlay: Overlay?
    private let videoQueue = DispatchQueue(label: "com.sceneit.video", qos: .userInteractive)
    
    // Core Image processing
    private let ciContext = CIContext()
    private var splashImage: CIImage?
    private var videoSize = CGSize(width: 1920, height: 1080)
    
    // IPC Bridge
    private let ipcBridge = VirtualCameraIPC()
    
    // Performance monitoring
    private var frameCount: Int = 0
    private var lastFrameRateUpdate = Date()
    private let frameRateUpdateInterval: TimeInterval = 1.0
    
    // Virtual camera device ID
    private let virtualCameraDeviceID = "com.sceneit.virtualcamera"
    
    override init() {
        super.init()
        setupVirtualCameraExtensions()
        createSplashScreen()
        
        // Initialize IPC bridge
        if ipcBridge.initialize() {
            print("✅ IPC bridge initialized")
            checkPluginConnection()
        } else {
            print("❌ Failed to initialize IPC bridge")
        }
        
        // Monitor plugin connection status
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkPluginConnection()
        }
    }
    
    deinit {
        ipcBridge.cleanup()
    }
    
    func requestCameraAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            completion(granted)
        }
    }
    
    func startVirtualCamera(with overlay: Overlay?) {
        guard !isActive else { return }
        
        currentOverlay = overlay
        
        do {
            try setupCaptureSession()
            captureSession?.startRunning()
            isActive = true
            errorMessage = nil
            print("Virtual camera started successfully")
        } catch {
            errorMessage = "Failed to start virtual camera: \(error.localizedDescription)"
            print("Error starting virtual camera: \(error)")
        }
        
        NotificationCenter.default.post(name: .virtualCameraStateChanged, object: nil)
    }
    
    func stopVirtualCamera() {
        guard isActive else { return }
        
        privateCaptureSession?.stopRunning()
        privateCaptureSession = nil
        videoDeviceInput = nil
        videoOutput = nil
        virtualCameraOutput = nil
        
        isActive = false
        frameRate = 0.0
        
        NotificationCenter.default.post(name: .virtualCameraStateChanged, object: nil)
        print("Virtual camera stopped")
    }
    
    func updateOverlay(_ overlay: Overlay?) {
        currentOverlay = overlay
        // Overlay is applied in real-time in the video processing pipeline
        print("Overlay updated to: \(overlay?.name ?? "None")")
    }
    
    private func setupVirtualCameraExtensions() {
        // Enable virtual camera extensions
        var property = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        
        var allow: UInt32 = 1
        let dataSize: UInt32 = 4
        let zero: UInt32 = 0
        
        CMIOObjectSetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject),
            &property,
            zero,
            nil,
            dataSize,
            &allow
        )
    }
    
    private func createSplashScreen() {
        // Create a splash screen image for when the virtual camera is selected but app is inactive
        let splashRect = CGRect(origin: .zero, size: videoSize)
        
        // Create a gradient background
        let startColor = CIColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0) // Dark blue
        let endColor = CIColor(red: 0.2, green: 0.2, blue: 0.4, alpha: 1.0)   // Lighter blue
        
        let gradientFilter = CIFilter(name: "CILinearGradient")!
        gradientFilter.setValue(CIVector(x: 0, y: 0), forKey: "inputPoint0")
        gradientFilter.setValue(CIVector(x: 0, y: videoSize.height), forKey: "inputPoint1")
        gradientFilter.setValue(startColor, forKey: "inputColor0")
        gradientFilter.setValue(endColor, forKey: "inputColor1")
        
        guard let gradientImage = gradientFilter.outputImage?.cropped(to: splashRect) else {
            // Fallback to solid color if gradient fails
            splashImage = CIImage(color: CIColor(red: 0.15, green: 0.15, blue: 0.3, alpha: 1.0))
                .cropped(to: splashRect)
            return
        }
        
        // Add text overlay to the splash screen
        let textImage = createTextImage(
            text: "Scene It\nVirtual Camera\n\nCamera Not Active\n\nStart Scene It to enable virtual camera",
            size: videoSize
        )
        
        if let textImage = textImage {
            // Composite text over gradient
            let compositeFilter = CIFilter(name: "CISourceOverCompositing")!
            compositeFilter.setValue(textImage, forKey: "inputImage")
            compositeFilter.setValue(gradientImage, forKey: "inputBackgroundImage")
            splashImage = compositeFilter.outputImage
        } else {
            splashImage = gradientImage
        }
    }
    
    private func createTextImage(text: String, size: CGSize) -> CIImage? {
        // Create an NSAttributedString with styling
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 48, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        // Calculate text size
        let textSize = attributedString.size()
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        // Create a bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // Clear the context
        context.clear(CGRect(origin: .zero, size: size))
        
        // Draw the text
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext
        
        attributedString.draw(in: textRect)
        
        NSGraphicsContext.restoreGraphicsState()
        
        // Create CIImage from the context
        guard let cgImage = context.makeImage() else { return nil }
        return CIImage(cgImage: cgImage)
    }
    
    private func setupCaptureSession() throws {
        privateCaptureSession = AVCaptureSession()
        guard let captureSession = privateCaptureSession else { 
            throw VirtualCameraError.sessionCreationFailed
        }
        
        captureSession.beginConfiguration()
        
        // Configure for high quality
        if captureSession.canSetSessionPreset(.hd1920x1080) {
            captureSession.sessionPreset = .hd1920x1080
            videoSize = CGSize(width: 1920, height: 1080)
        } else if captureSession.canSetSessionPreset(.hd1280x720) {
            captureSession.sessionPreset = .hd1280x720
            videoSize = CGSize(width: 1280, height: 720)
        } else {
            captureSession.sessionPreset = .vga640x480
            videoSize = CGSize(width: 640, height: 480)
        }
        
        // Setup video input (webcam)
        try setupVideoInput()
        
        // Setup video output
        try setupVideoOutput()
        
        captureSession.commitConfiguration()
    }
    
    private func setupVideoInput() throws {
        guard let captureSession = privateCaptureSession else { 
            throw VirtualCameraError.sessionCreationFailed
        }
        
        // Get default video device (built-in camera)
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
                AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw VirtualCameraError.noVideoDeviceAvailable
        }
        
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            guard let videoDeviceInput = videoDeviceInput else {
                throw VirtualCameraError.videoInputCreationFailed(NSError(domain: "VirtualCamera", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create input"]))
            }
            
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
            } else {
                throw VirtualCameraError.videoInputCreationFailed(NSError(domain: "VirtualCamera", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot add input to session"]))
            }
        } catch {
            throw VirtualCameraError.videoInputCreationFailed(error)
        }
    }
    
    private func setupVideoOutput() throws {
        guard let captureSession = privateCaptureSession else { 
            throw VirtualCameraError.sessionCreationFailed
        }
        
        videoOutput = AVCaptureVideoDataOutput()
        guard let videoOutput = videoOutput else { 
            throw VirtualCameraError.videoOutputSetupFailed
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            throw VirtualCameraError.videoOutputSetupFailed
        }
        
        // Configure video output connection
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
            // Ensure proper orientation
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension VirtualCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Process the video frame here
        // In a complete implementation, this would:
        // 1. Apply the selected overlay to the video frame
        // 2. Output the processed frame to the virtual camera device
        // 3. Handle fallback screens when app is not running
        
        // For now, this is a placeholder for the video processing pipeline
        processVideoFrame(sampleBuffer)
    }
    
    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer")
            return
        }
        
        // Convert to CIImage for processing
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        // Process the frame with overlay if available
        let processedImage: CIImage
        if let overlay = currentOverlay {
            processedImage = applyOverlay(overlay, to: ciImage)
        } else {
            processedImage = ciImage
        }
        
        // Convert back to CVPixelBuffer and output to virtual camera
        outputProcessedFrame(processedImage, originalSampleBuffer: sampleBuffer)
    }
    
    private func applyOverlay(_ overlay: Overlay, to inputImage: CIImage) -> CIImage {
        let imageRect = inputImage.extent
        
        // Create overlay based on overlay type
        let overlayImage = createOverlayImage(overlay, for: imageRect.size)
        
        guard let overlayImage = overlayImage else {
            print("Failed to create overlay image for \(overlay.name)")
            return inputImage
        }
        
        // Composite the overlay onto the input image
        let compositeFilter = CIFilter(name: "CISourceOverCompositing")!
        compositeFilter.setValue(overlayImage, forKey: "inputImage")
        compositeFilter.setValue(inputImage, forKey: "inputBackgroundImage")
        
        return compositeFilter.outputImage ?? inputImage
    }
    
    private func createOverlayImage(_ overlay: Overlay, for size: CGSize) -> CIImage? {
        switch overlay.name {
        case "Professional Frame":
            return createProfessionalFrameOverlay(size: size)
        case "Casual Border":
            return createCasualBorderOverlay(size: size)
        case "Minimalist":
            return createMinimalistOverlay(size: size)
        case "Branded":
            return createBrandedOverlay(size: size)
        default:
            // Try to load from overlay image if available
            if let nsImage = overlay.image {
                return convertNSImageToCIImage(nsImage, targetSize: size)
            }
            return nil
        }
    }
    
    private func createProfessionalFrameOverlay(size: CGSize) -> CIImage {
        let rect = CGRect(origin: .zero, size: size)
        
        // Create a subtle frame border
        let borderWidth: CGFloat = 8
        let borderColor = CIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.8)
        
        // Create border rectangles
        let topBorder = CGRect(x: 0, y: size.height - borderWidth, width: size.width, height: borderWidth)
        let bottomBorder = CGRect(x: 0, y: 0, width: size.width, height: borderWidth)
        let leftBorder = CGRect(x: 0, y: 0, width: borderWidth, height: size.height)
        let rightBorder = CGRect(x: size.width - borderWidth, y: 0, width: borderWidth, height: size.height)
        
        // Create the border image
        let borderImage = CIImage(color: borderColor)
        
        var overlayImage = CIImage(color: CIColor.clear).cropped(to: rect)
        
        // Add each border
        for borderRect in [topBorder, bottomBorder, leftBorder, rightBorder] {
            let croppedBorder = borderImage.cropped(to: borderRect)
            let compositeFilter = CIFilter(name: "CISourceOverCompositing")!
            compositeFilter.setValue(croppedBorder, forKey: "inputImage")
            compositeFilter.setValue(overlayImage, forKey: "inputBackgroundImage")
            overlayImage = compositeFilter.outputImage ?? overlayImage
        }
        
        return overlayImage
    }
    
    private func createCasualBorderOverlay(size: CGSize) -> CIImage {
        let rect = CGRect(origin: .zero, size: size)
        
        // Create a colorful gradient border
        let borderWidth: CGFloat = 12
        
        // Create a rainbow gradient
        let colors = [
            CIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.7), // Red
            CIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 0.7), // Orange
            CIColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 0.7), // Green
            CIColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 0.7)  // Blue
        ]
        
        var overlayImage = CIImage(color: CIColor.clear).cropped(to: rect)
        
        for (index, color) in colors.enumerated() {
            let offset = CGFloat(index) * (borderWidth / CGFloat(colors.count))
            let currentWidth = borderWidth - offset
            
            let topBorder = CGRect(x: offset, y: size.height - currentWidth - offset, width: size.width - 2*offset, height: currentWidth)
            let bottomBorder = CGRect(x: offset, y: offset, width: size.width - 2*offset, height: currentWidth)
            let leftBorder = CGRect(x: offset, y: offset, width: currentWidth, height: size.height - 2*offset)
            let rightBorder = CGRect(x: size.width - currentWidth - offset, y: offset, width: currentWidth, height: size.height - 2*offset)
            
            let colorImage = CIImage(color: color)
            
            for borderRect in [topBorder, bottomBorder, leftBorder, rightBorder] {
                let croppedBorder = colorImage.cropped(to: borderRect)
                let compositeFilter = CIFilter(name: "CISourceOverCompositing")!
                compositeFilter.setValue(croppedBorder, forKey: "inputImage")
                compositeFilter.setValue(overlayImage, forKey: "inputBackgroundImage")
                overlayImage = compositeFilter.outputImage ?? overlayImage
            }
        }
        
        return overlayImage
    }
    
    private func createMinimalistOverlay(size: CGSize) -> CIImage {
        let rect = CGRect(origin: .zero, size: size)
        
        // Create a subtle corner indicator
        let cornerSize: CGFloat = 20
        let cornerColor = CIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.3)
        
        // Create corner rectangles
        let topLeft = CGRect(x: 0, y: size.height - cornerSize, width: cornerSize, height: cornerSize)
        let topRight = CGRect(x: size.width - cornerSize, y: size.height - cornerSize, width: cornerSize, height: cornerSize)
        let bottomLeft = CGRect(x: 0, y: 0, width: cornerSize, height: cornerSize)
        let bottomRight = CGRect(x: size.width - cornerSize, y: 0, width: cornerSize, height: cornerSize)
        
        var overlayImage = CIImage(color: CIColor.clear).cropped(to: rect)
        let cornerImage = CIImage(color: cornerColor)
        
        for cornerRect in [topLeft, topRight, bottomLeft, bottomRight] {
            let croppedCorner = cornerImage.cropped(to: cornerRect)
            let compositeFilter = CIFilter(name: "CISourceOverCompositing")!
            compositeFilter.setValue(croppedCorner, forKey: "inputImage")
            compositeFilter.setValue(overlayImage, forKey: "inputBackgroundImage")
            overlayImage = compositeFilter.outputImage ?? overlayImage
        }
        
        return overlayImage
    }
    
    private func createBrandedOverlay(size: CGSize) -> CIImage {
        let rect = CGRect(origin: .zero, size: size)
        
        // Create a branded overlay with logo area
        let logoAreaSize = CGSize(width: 200, height: 80)
        let logoRect = CGRect(
            x: size.width - logoAreaSize.width - 20,
            y: 20,
            width: logoAreaSize.width,
            height: logoAreaSize.height
        )
        
        // Create semi-transparent background for logo area
        let logoBackground = CIImage(color: CIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5))
            .cropped(to: logoRect)
        
        // Add text overlay for branding
        let brandText = createTextImage(text: "Scene It", size: logoAreaSize)
        
        var overlayImage = CIImage(color: CIColor.clear).cropped(to: rect)
        
        // Add logo background
        let backgroundComposite = CIFilter(name: "CISourceOverCompositing")!
        backgroundComposite.setValue(logoBackground, forKey: "inputImage")
        backgroundComposite.setValue(overlayImage, forKey: "inputBackgroundImage")
        overlayImage = backgroundComposite.outputImage ?? overlayImage
        
        // Add brand text if available
        if let brandText = brandText {
            let textTransform = CGAffineTransform(translationX: logoRect.minX, y: logoRect.minY)
            let transformedText = brandText.transformed(by: textTransform)
            
            let textComposite = CIFilter(name: "CISourceOverCompositing")!
            textComposite.setValue(transformedText, forKey: "inputImage")
            textComposite.setValue(overlayImage, forKey: "inputBackgroundImage")
            overlayImage = textComposite.outputImage ?? overlayImage
        }
        
        return overlayImage
    }
    
    private func convertNSImageToCIImage(_ nsImage: NSImage, targetSize: CGSize) -> CIImage? {
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // Scale to target size if needed
        let scaleX = targetSize.width / ciImage.extent.width
        let scaleY = targetSize.height / ciImage.extent.height
        let scale = min(scaleX, scaleY)
        
        if scale != 1.0 {
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            return ciImage.transformed(by: transform)
        }
        
        return ciImage
    }
    
    private func outputProcessedFrame(_ image: CIImage, originalSampleBuffer: CMSampleBuffer) {
        // Get the pixel buffer from the original sample buffer
        guard let originalPixelBuffer = CMSampleBufferGetImageBuffer(originalSampleBuffer) else {
            print("Failed to get pixel buffer from original sample buffer")
            return
        }
        
        // Create a new pixel buffer for the processed image
        var newPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(image.extent.width),
            Int(image.extent.height),
            kCVPixelFormatType_32BGRA,
            nil,
            &newPixelBuffer
        )
        
        guard status == kCVReturnSuccess, let pixelBuffer = newPixelBuffer else {
            print("Failed to create new pixel buffer")
            return
        }
        
        // Render the processed image to the pixel buffer
        ciContext.render(image, to: pixelBuffer)
        
        // In a real implementation, this processed frame would be sent to the virtual camera output
        // For now, we'll just log that processing occurred
        print("Processed frame with overlay: \(currentOverlay?.name ?? "none")")
        
        // TODO: Send processed frame to virtual camera device
        // This would require implementing the DAL plugin or virtual camera backend
        sendToVirtualCamera(pixelBuffer: pixelBuffer, originalSampleBuffer: originalSampleBuffer)
    }
    
    private func sendToVirtualCamera(pixelBuffer: CVPixelBuffer, originalSampleBuffer: CMSampleBuffer) {
        // Send frame to DAL plugin via IPC
        let success = ipcBridge.sendFrame(pixelBuffer)
        
        if success {
            // Update frame rate statistics
            updateFrameRate()
        } else {
            // Handle failed frame send
            if isPluginConnected {
                print("⚠️ Failed to send frame to plugin (buffer full?)")
            }
        }
    }
    
    // MARK: - Public Interface for Virtual Camera Backend
    
    /// Gets the current splash screen image for inactive camera state
    func getSplashScreenImage() -> CIImage? {
        return splashImage
    }
    
    /// Gets the current video size being used
    func getCurrentVideoSize() -> CGSize {
        return videoSize
    }
    
    /// Gets the virtual camera device identifier
    func getVirtualCameraDeviceID() -> String {
        return virtualCameraDeviceID
    }
    
    /// Outputs splash screen to virtual camera when app is inactive
    func outputSplashScreen() {
        guard let splashImage = splashImage else {
            print("No splash screen available")
            return
        }
        
        // Create pixel buffer for splash screen
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(videoSize.width),
            Int(videoSize.height),
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("Failed to create pixel buffer for splash screen")
            return
        }
        
        // Render splash screen to pixel buffer
        ciContext.render(splashImage, to: buffer)
        
        // Send to virtual camera
        print("Outputting splash screen to virtual camera")
        
        // Send splash screen to virtual camera via IPC
        let success = ipcBridge.sendFrame(buffer)
        if !success {
            print("Failed to send splash screen to virtual camera")
        }
    }
    
    // MARK: - Plugin Connection Management
    
    private func checkPluginConnection() {
        let wasConnected = isPluginConnected
        isPluginConnected = ipcBridge.isPluginConnected()
        
        if wasConnected != isPluginConnected {
            DispatchQueue.main.async {
                if self.isPluginConnected {
                    print("✅ Virtual camera plugin connected")
                } else {
                    print("❌ Virtual camera plugin disconnected")
                }
            }
        }
    }
    
    private func updateFrameRate() {
        frameCount += 1
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastFrameRateUpdate)
        
        if timeSinceLastUpdate >= frameRateUpdateInterval {
            let fps = Double(frameCount) / timeSinceLastUpdate
            DispatchQueue.main.async {
                self.frameRate = fps
            }
            
            frameCount = 0
            lastFrameRateUpdate = now
        }
    }
    
    // MARK: - Public Interface for Plugin Management
    
    /// Install the virtual camera plugin
    func installPlugin() -> Bool {
        // This would run the plugin installation process
        let process = Process()
        process.launchPath = "/usr/bin/make"
        process.arguments = ["-C", "SceneItVirtualCamera.plugin/Contents/Resources", "install"]
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("Failed to install plugin: \(error)")
            return false
        }
    }
    
    /// Get IPC buffer status for debugging
    func getIPCStatus() -> (writeIndex: UInt32, readIndex: UInt32, frameCount: UInt32) {
        return ipcBridge.getBufferStatus()
    }
}