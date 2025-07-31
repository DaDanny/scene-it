import SwiftUI
import AVFoundation
import CoreVideo

struct VideoPreviewWindow: View {
    @ObservableObject var virtualCameraManager: VirtualCameraManager
    @State private var previewLayer: AVCaptureVideoPreviewLayer?
    @State private var isWindowVisible = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "video.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("Scene It Preview")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(virtualCameraManager.isActive ? "Virtual Camera Active" : "Virtual Camera Inactive")
                        .font(.caption)
                        .foregroundColor(virtualCameraManager.isActive ? .green : .secondary)
                }
                
                Spacer()
                
                Button(action: {
                    // Close preview window
                    NSApplication.shared.keyWindow?.close()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Video Preview Area
            VideoPreviewView(virtualCameraManager: virtualCameraManager)
                .frame(width: 640, height: 480)
                .background(Color.black)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            // Controls
            VStack(spacing: 12) {
                // Camera Controls
                HStack(spacing: 16) {
                    Button(action: {
                        if virtualCameraManager.isActive {
                            virtualCameraManager.stopVirtualCamera()
                        } else {
                            virtualCameraManager.startVirtualCamera(with: nil)
                        }
                    }) {
                        HStack {
                            Image(systemName: virtualCameraManager.isActive ? "stop.circle.fill" : "play.circle.fill")
                            Text(virtualCameraManager.isActive ? "Stop Camera" : "Start Camera")
                        }
                        .frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Test with QuickTime") {
                        // Launch QuickTime Player for testing
                        NSWorkspace.shared.launchApplication("QuickTime Player")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                
                // Stats
                HStack {
                    Label("Resolution: \(Int(virtualCameraManager.getCurrentVideoSize().width))×\(Int(virtualCameraManager.getCurrentVideoSize().height))", systemImage: "tv")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if virtualCameraManager.isActive {
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("30 FPS")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 720, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct VideoPreviewView: NSViewRepresentable {
    @ObservableObject var virtualCameraManager: VirtualCameraManager
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        
        // Set up preview layer
        if let captureSession = virtualCameraManager.captureSession {
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.videoGravity = .resizeAspect
            previewLayer.frame = view.bounds
            view.layer?.addSublayer(previewLayer)
            
            // Store reference for updates
            context.coordinator.previewLayer = previewLayer
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update preview layer frame when view size changes
        if let previewLayer = context.coordinator.previewLayer {
            previewLayer.frame = nsView.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// Preview window controller
class VideoPreviewWindowController: NSWindowController {
    private var virtualCameraManager: VirtualCameraManager
    
    init(virtualCameraManager: VirtualCameraManager) {
        self.virtualCameraManager = virtualCameraManager
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        window.title = "Scene It - Video Preview"
        window.center()
        window.setFrameAutosaveName("SceneItPreviewWindow")
        
        // Set up SwiftUI content
        let contentView = VideoPreviewWindow(virtualCameraManager: virtualCameraManager)
        window.contentView = NSHostingView(rootView: contentView)
        
        // Window delegate for cleanup
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension VideoPreviewWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Clean up when window is closed
        print("Preview window closing")
    }
}