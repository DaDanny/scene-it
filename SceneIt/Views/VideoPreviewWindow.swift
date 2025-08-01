import SwiftUI
import AVFoundation
import Combine
import CoreVideo

struct VideoPreviewWindow: View {
    @ObservedObject var virtualCameraManager: VirtualCameraManager
    @State private var isFullscreen = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            // Modern Header with Glass Effect
            headerView
            
            // Main Preview Area
            previewAreaView
            
            // Modern Controls Section
            controlsView
            
            // Stats and Info
            statsView
        }
        .frame(minWidth: 800, minHeight: 650)
        .background(backgroundView)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "video.fill")
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ritually Preview")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(virtualCameraManager.isActive ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(virtualCameraManager.isActive ? "Live" : "Inactive")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(virtualCameraManager.isActive ? .green : .secondary)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: { isFullscreen.toggle() }) {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle Fullscreen")
                
                Button(action: { NSApplication.shared.keyWindow?.close() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close Preview")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    private var previewAreaView: some View {
        ModernVideoPreviewView(virtualCameraManager: virtualCameraManager)
            .id(refreshID) // Force refresh when refreshID changes
            .frame(width: isFullscreen ? 1280 : 720, height: isFullscreen ? 720 : 405)
            .background(Color.black)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                        .stroke(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    @State private var refreshID = UUID()
    
    private var controlsView: some View {
        HStack(spacing: 20) {
            // Start/Stop Button
            Button(action: {
                if virtualCameraManager.isActive {
                    virtualCameraManager.stopVirtualCamera()
                } else {
                    virtualCameraManager.startVirtualCamera(with: nil)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: virtualCameraManager.isActive ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title3)
                    Text(virtualCameraManager.isActive ? "Stop Camera" : "Start Camera")
                        .fontWeight(.medium)
                }
                .frame(minWidth: 140, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            // Test Button
            Button("Test with QuickTime") {
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.QuickTimePlayerX") {
                    NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            
            // Refresh Preview Button
            Button("Refresh Preview") {
                refreshID = UUID()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            
            Spacer()
            
            // Camera Selector
            if !virtualCameraManager.availableCameras.isEmpty {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Camera Source")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Camera", selection: Binding(
                        get: { virtualCameraManager.selectedCamera },
                        set: { newCamera in
                            if let camera = newCamera {
                                virtualCameraManager.selectCamera(camera)
                            }
                        }
                    )) {
                        ForEach(virtualCameraManager.availableCameras, id: \.uniqueID) { camera in
                            Text(camera.localizedName).tag(camera as AVCaptureDevice?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minWidth: 200)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var statsView: some View {
        HStack(spacing: 20) {
            // Resolution Info
            HStack(spacing: 6) {
                Image(systemName: "tv")
                    .foregroundColor(.blue)
                Text("Resolution: \(Int(virtualCameraManager.getCurrentVideoSize().width))×\(Int(virtualCameraManager.getCurrentVideoSize().height))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Frame Rate
            if virtualCameraManager.isActive {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("30 FPS")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Camera Info
            if let selectedCamera = virtualCameraManager.selectedCamera {
                HStack(spacing: 6) {
                    Image(systemName: "camera")
                        .foregroundColor(.purple)
                    Text(selectedCamera.localizedName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    private var backgroundView: some View {
        ZStack {
            // Base background
            Rectangle()
                .fill(colorScheme == .dark ? Color.black : Color.white)
            
            // Subtle gradient overlay
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.05),
                    Color.purple.opacity(0.05),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Modern Video Preview View

struct ModernVideoPreviewView: NSViewRepresentable {
    @ObservedObject var virtualCameraManager: VirtualCameraManager
    @State private var refreshID = UUID()
    
    func makeNSView(context: Context) -> NSView {
        print("🎥 VideoPreviewWindow: Creating NSView for camera preview")
        
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.cgColor
        containerView.layer?.cornerRadius = 16
        containerView.layer?.masksToBounds = true
        
        // Ensure proper layer configuration
        containerView.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        containerView.layer?.isOpaque = true
        
        // Add subtle inner shadow for depth
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOffset = NSSize(width: 0, height: 2)
        containerView.layer?.shadowRadius = 4
        containerView.layer?.shadowOpacity = 0.3
        
        print("🎥 VideoPreviewWindow: Container view created with bounds: \(containerView.bounds)")
        
        // Don't create preview layer here - wait for proper bounds in updateNSView
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Check if view has valid bounds before creating preview layer
        let hasValidBounds = nsView.bounds.width > 0 && nsView.bounds.height > 0
        print("🎥 VideoPreviewWindow: updateNSView - bounds: \(nsView.bounds), valid: \(hasValidBounds)")
        
        // Update existing preview layer frame when view size changes
        if let previewLayer = context.coordinator.previewLayer {
            if hasValidBounds {
                previewLayer.frame = nsView.bounds
                print("🎥 VideoPreviewWindow: Updated preview layer frame to \(nsView.bounds)")
            }
        }
        
        // If virtual camera state changed, refresh the preview
        if context.coordinator.lastActiveState != virtualCameraManager.isActive {
            print("🎥 VideoPreviewWindow: Virtual camera state changed to \(virtualCameraManager.isActive)")
            context.coordinator.lastActiveState = virtualCameraManager.isActive
            
            // Only recreate if we don't have a preview layer
            if context.coordinator.previewLayer == nil && hasValidBounds {
                print("🎥 VideoPreviewWindow: No existing preview layer, creating new one")
                setupPreviewLayer(in: nsView, context: context)
            } else {
                print("🎥 VideoPreviewWindow: Preview layer exists, updating session reference")
                // Update the existing layer's session if needed
                if let newSession = virtualCameraManager.captureSession,
                   context.coordinator.previewLayer?.session !== newSession {
                    context.coordinator.previewLayer?.session = newSession
                    print("🎥 VideoPreviewWindow: Updated preview layer session")
                }
            }
        }
        
        // Create preview layer if we have valid bounds, capture session, and no existing layer
        if context.coordinator.previewLayer == nil && 
           virtualCameraManager.captureSession != nil && 
           hasValidBounds {
            print("🎥 VideoPreviewWindow: Ready to create preview layer - valid bounds and session available")
            setupPreviewLayer(in: nsView, context: context)
        } else if context.coordinator.previewLayer == nil {
            print("🎥 VideoPreviewWindow: Not ready for preview layer - bounds: \(hasValidBounds), session: \(virtualCameraManager.captureSession != nil)")
        }
    }
    
    private func setupPreviewLayer(in view: NSView, context: Context) {
        print("🎥 VideoPreviewWindow: Setting up preview layer...")
        
        // Prevent duplicate layer creation
        if context.coordinator.previewLayer != nil {
            print("🎥 VideoPreviewWindow: Preview layer already exists, skipping setup")
            return
        }
        
        guard let captureSession = virtualCameraManager.captureSession else {
            print("🎥 VideoPreviewWindow: No capture session available, showing placeholder")
            showPlaceholder(in: view)
            return
        }
        
        print("🎥 VideoPreviewWindow: Capture session found, creating preview layer")
        print("🎥 VideoPreviewWindow: Session is running: \(captureSession.isRunning)")
        print("🎥 VideoPreviewWindow: Session inputs: \(captureSession.inputs.count)")
        print("🎥 VideoPreviewWindow: Session outputs: \(captureSession.outputs.count)")
        
        // Clear any existing sublayers first
        view.layer?.sublayers?.removeAll()
        
        // Ensure the view is layer-backed and configured properly
        view.wantsLayer = true
        view.layer?.masksToBounds = false
        
        print("🎥 VideoPreviewWindow: View bounds: \(view.bounds)")
        print("🎥 VideoPreviewWindow: View layer: \(view.layer != nil)")
        
        // Ensure we have valid bounds before creating the layer
        guard view.bounds.width > 0 && view.bounds.height > 0 else {
            print("🎥 VideoPreviewWindow: Invalid view bounds \(view.bounds), cannot create preview layer")
            return
        }
        
        // Create preview layer with more specific configuration
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspect  // Back to aspect to see full frame
        previewLayer.frame = view.bounds
        previewLayer.cornerRadius = 16
        
        // More specific layer configuration
        previewLayer.backgroundColor = NSColor.clear.cgColor  // Try clear background
        previewLayer.opacity = 1.0
        previewLayer.isHidden = false
        previewLayer.masksToBounds = true
        previewLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        // Try forcing the connection orientation
        if let connection = previewLayer.connection {
            print("🎥 VideoPreviewWindow: Found preview connection: \(connection)")
            print("🎥 VideoPreviewWindow: Connection enabled: \(connection.isEnabled)")
            print("🎥 VideoPreviewWindow: Connection active: \(connection.isActive)")
            
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .landscapeLeft
                print("🎥 VideoPreviewWindow: Set video orientation to landscapeLeft")
            } else {
                print("🎥 VideoPreviewWindow: Video orientation not supported")
            }
        } else {
            print("🎥 VideoPreviewWindow: NO PREVIEW CONNECTION - This might be the issue!")
        }
        
        print("🎥 VideoPreviewWindow: Preview layer frame: \(previewLayer.frame)")
        print("🎥 VideoPreviewWindow: Preview layer bounds: \(previewLayer.bounds)")
        
        // Store the layer BEFORE adding to prevent duplicates
        context.coordinator.previewLayer = previewLayer
        
        // Add layer to view immediately (no async)
        view.layer?.addSublayer(previewLayer)
        
        // Force layer updates
        previewLayer.setNeedsDisplay()
        view.layer?.setNeedsDisplay()
        view.needsDisplay = true
        
        print("🎥 VideoPreviewWindow: Preview layer added to view hierarchy")
        print("🎥 VideoPreviewWindow: View sublayers count: \(view.layer?.sublayers?.count ?? 0)")
        
        // Additional debugging for video content
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🎥 VideoPreviewWindow: Delayed check - layer bounds: \(previewLayer.bounds)")
            print("🎥 VideoPreviewWindow: Delayed check - layer frame: \(previewLayer.frame)")
            print("🎥 VideoPreviewWindow: Delayed check - session running: \(captureSession.isRunning)")
            print("🎥 VideoPreviewWindow: Delayed check - layer contents: \(previewLayer.contents != nil)")
            print("🎥 VideoPreviewWindow: Delayed check - layer hidden: \(previewLayer.isHidden)")
            print("🎥 VideoPreviewWindow: Delayed check - layer opacity: \(previewLayer.opacity)")
            print("🎥 VideoPreviewWindow: Delayed check - layer in hierarchy: \(previewLayer.superlayer != nil)")
            print("🎥 VideoPreviewWindow: Delayed check - session inputs: \(captureSession.inputs.count)")
            print("🎥 VideoPreviewWindow: Delayed check - session outputs: \(captureSession.outputs.count)")
            
            // Check if layer connection exists
            if let connection = previewLayer.connection {
                print("🎥 VideoPreviewWindow: Delayed check - connection enabled: \(connection.isEnabled)")
                print("🎥 VideoPreviewWindow: Delayed check - connection active: \(connection.isActive)")
                print("🎥 VideoPreviewWindow: Delayed check - connection video orientation: \(connection.videoOrientation.rawValue)")
            } else {
                print("🎥 VideoPreviewWindow: Delayed check - NO CONNECTION FOUND!")
            }
            
            // Try to force a redraw
            previewLayer.setNeedsLayout()
            previewLayer.layoutIfNeeded()
            previewLayer.setNeedsDisplay()
        }
        
        print("🎥 VideoPreviewWindow: Preview layer setup complete")
    }
    
    private func showPlaceholder(in view: NSView) {
        print("🎥 VideoPreviewWindow: Showing placeholder content")
        
        // Clear any existing sublayers
        view.layer?.sublayers?.removeAll()
        
        // Create a background layer
        let backgroundLayer = CALayer()
        backgroundLayer.backgroundColor = NSColor.controlBackgroundColor.cgColor
        backgroundLayer.frame = view.bounds
        backgroundLayer.cornerRadius = 16
        view.layer?.addSublayer(backgroundLayer)
        
        // Create a placeholder view with modern styling
        let placeholderLayer = CATextLayer()
        placeholderLayer.string = "Camera Preview\nConnect a camera to see live preview\n\nVirtual Camera Status: \(virtualCameraManager.isActive ? "Active" : "Inactive")"
        placeholderLayer.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        placeholderLayer.fontSize = 16
        placeholderLayer.foregroundColor = NSColor.labelColor.cgColor
        placeholderLayer.alignmentMode = .center
        placeholderLayer.isWrapped = true
        placeholderLayer.frame = CGRect(
            x: 20,
            y: view.bounds.height / 2 - 60,
            width: view.bounds.width - 40,
            height: 120
        )
        placeholderLayer.contentsScale = view.layer?.contentsScale ?? 2.0
        
        view.layer?.addSublayer(placeholderLayer)
        
        print("🎥 VideoPreviewWindow: Placeholder added to view")
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
        var lastActiveState: Bool = false
    }
}

// Preview window controller with modern styling
class VideoPreviewWindowController: NSWindowController {
    private var virtualCameraManager: VirtualCameraManager
    weak var statusBarController: StatusBarController?
    
    init(virtualCameraManager: VirtualCameraManager, statusBarController: StatusBarController? = nil) {
        self.virtualCameraManager = virtualCameraManager
        self.statusBarController = statusBarController
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 650),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        // Modern window styling
        window.title = "Ritually - Video Preview"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        
        // Set minimum size first
        window.minSize = NSSize(width: 600, height: 500)
        
        // Safe window positioning with frame validation
        setupWindowPosition(window)
        
        // Use autosave name with validation
        setupFrameAutosave(window)
        
        // Set up SwiftUI content with modern styling
        let contentView = VideoPreviewWindow(virtualCameraManager: virtualCameraManager)
        window.contentView = NSHostingView(rootView: contentView)
        
        // Window delegate for cleanup
        window.delegate = self
        
        // Add subtle vibrancy effect
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .hudWindow
        window.contentView?.addSubview(visualEffect, positioned: .below, relativeTo: nil)
        visualEffect.frame = window.contentView?.bounds ?? .zero
        visualEffect.autoresizingMask = [.width, .height]
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindowPosition(_ window: NSWindow) {
        // Get the main screen bounds
        guard let mainScreen = NSScreen.main else {
            window.center()
            return
        }
        
        let screenFrame = mainScreen.visibleFrame
        let windowSize = window.frame.size
        
        // Calculate centered position
        let x = screenFrame.origin.x + (screenFrame.width - windowSize.width) / 2
        let y = screenFrame.origin.y + (screenFrame.height - windowSize.height) / 2
        
        let centeredFrame = NSRect(
            x: x,
            y: y,
            width: windowSize.width,
            height: windowSize.height
        )
        
        // Ensure the frame is within screen bounds
        let constrainedFrame = constrainFrameToScreen(centeredFrame, screen: mainScreen)
        window.setFrame(constrainedFrame, display: false)
        
        print("🪟 VideoPreviewWindow: Positioned at \(constrainedFrame)")
    }
    
    private func setupFrameAutosave(_ window: NSWindow) {
        // Set autosave name for future sessions
        window.setFrameAutosaveName("RituallyPreviewWindow")
        
        // If there's a saved frame, validate it before using
        if let savedFrameString = UserDefaults.standard.string(forKey: "NSWindow Frame RituallyPreviewWindow") {
            print("🪟 VideoPreviewWindow: Found saved frame: \(savedFrameString)")
            
            // Try to parse and validate the saved frame
            let savedFrame = NSRectFromString(savedFrameString)
            if isFrameValid(savedFrame) {
                window.setFrame(savedFrame, display: false)
                print("🪟 VideoPreviewWindow: Restored to saved frame")
            } else {
                print("🪟 VideoPreviewWindow: Saved frame invalid, keeping centered position")
                // Clear invalid saved frame
                UserDefaults.standard.removeObject(forKey: "NSWindow Frame RituallyPreviewWindow")
            }
        }
    }
    
    private func constrainFrameToScreen(_ frame: NSRect, screen: NSScreen) -> NSRect {
        let screenFrame = screen.visibleFrame
        var constrainedFrame = frame
        
        // Ensure window is not larger than screen
        constrainedFrame.size.width = min(constrainedFrame.width, screenFrame.width - 40)
        constrainedFrame.size.height = min(constrainedFrame.height, screenFrame.height - 40)
        
        // Ensure window is within screen bounds
        if constrainedFrame.maxX > screenFrame.maxX {
            constrainedFrame.origin.x = screenFrame.maxX - constrainedFrame.width
        }
        if constrainedFrame.minX < screenFrame.minX {
            constrainedFrame.origin.x = screenFrame.minX
        }
        if constrainedFrame.maxY > screenFrame.maxY {
            constrainedFrame.origin.y = screenFrame.maxY - constrainedFrame.height
        }
        if constrainedFrame.minY < screenFrame.minY {
            constrainedFrame.origin.y = screenFrame.minY
        }
        
        return constrainedFrame
    }
    
    private func isFrameValid(_ frame: NSRect) -> Bool {
        // Check if frame has valid dimensions
        guard frame.width > 0 && frame.height > 0 else { return false }
        
        // Check if frame intersects with any available screen
        for screen in NSScreen.screens {
            if screen.visibleFrame.intersects(frame) {
                return true
            }
        }
        
        return false
    }
}

extension VideoPreviewWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        print("Preview window closing")
        // Notify the status bar controller to clean up the reference
        statusBarController?.previewWindowDidClose()
    }
}