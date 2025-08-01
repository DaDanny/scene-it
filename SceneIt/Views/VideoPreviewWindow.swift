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
                NSWorkspace.shared.launchApplication("QuickTime Player")
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
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.cgColor
        containerView.layer?.cornerRadius = 16
        
        // Add subtle inner shadow for depth
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOffset = NSSize(width: 0, height: 2)
        containerView.layer?.shadowRadius = 4
        containerView.layer?.shadowOpacity = 0.3
        
        // Set up preview layer
        setupPreviewLayer(in: containerView, context: context)
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update preview layer frame when view size changes
        if let previewLayer = context.coordinator.previewLayer {
            previewLayer.frame = nsView.bounds
        }
        
        // Create preview layer if capture session becomes available
        if context.coordinator.previewLayer == nil && virtualCameraManager.captureSession != nil {
            setupPreviewLayer(in: nsView, context: context)
        }
    }
    
    private func setupPreviewLayer(in view: NSView, context: Context) {
        guard let captureSession = virtualCameraManager.captureSession else {
            // Show placeholder content
            showPlaceholder(in: view)
            return
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspect
        previewLayer.frame = view.bounds
        previewLayer.cornerRadius = 16
        
        // Add smooth animation when adding layer
        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0.0
        fadeIn.toValue = 1.0
        fadeIn.duration = 0.3
        previewLayer.add(fadeIn, forKey: "fadeIn")
        
        view.layer?.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
    }
    
    private func showPlaceholder(in view: NSView) {
        // Create a placeholder view with modern styling
        let placeholderLayer = CATextLayer()
        placeholderLayer.string = "Camera Preview\nConnect a camera to see live preview"
        placeholderLayer.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        placeholderLayer.fontSize = 16
        placeholderLayer.foregroundColor = NSColor.secondaryLabelColor.cgColor
        placeholderLayer.alignmentMode = .center
        placeholderLayer.isWrapped = true
        placeholderLayer.frame = view.bounds
        placeholderLayer.contentsScale = view.layer?.contentsScale ?? 2.0
        
        view.layer?.addSublayer(placeholderLayer)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
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
        window.center()
        window.setFrameAutosaveName("SceneItPreviewWindow")
        
        // Set minimum size
        window.minSize = NSSize(width: 600, height: 500)
        
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
}

extension VideoPreviewWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        print("Preview window closing")
        // Notify the status bar controller to clean up the reference
        statusBarController?.previewWindowDidClose()
    }
}