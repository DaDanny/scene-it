import SwiftUI
import AVFoundation

struct StatusBarMenuView: View {
    @ObservedObject var statusBarController: StatusBarController
    @ObservedObject var overlayManager: OverlayManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "video.circle.fill")
                    .foregroundColor(.blue)
                Text("Scene It")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            Divider()
            
            // Virtual Camera Status
            HStack {
                Circle()
                    .fill(statusBarController.isVirtualCameraActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(statusBarController.isVirtualCameraActive ? "Virtual Camera Active" : "Virtual Camera Inactive")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Controls
            VStack(spacing: 4) {
                Button(action: {
                    statusBarController.toggleVirtualCamera()
                }) {
                    HStack {
                        Image(systemName: statusBarController.isVirtualCameraActive ? "stop.circle" : "play.circle")
                        Text(statusBarController.isVirtualCameraActive ? "Stop Virtual Camera" : "Start Virtual Camera")
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.clear)
                .cornerRadius(4)
                
                // Preview Window Toggle
                Button(action: {
                    statusBarController.togglePreviewWindow()
                }) {
                    HStack {
                        Image(systemName: "eye")
                        Text("Show Preview")
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.clear)
                .cornerRadius(4)
                
                Divider()
                
                // Camera Selection
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Camera")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    if statusBarController.virtualCameraManager.availableCameras.isEmpty {
                        Text("No cameras detected")
                            .foregroundColor(.secondary)
                            .italic()
                            .font(.caption)
                            .padding(.horizontal, 8)
                    } else {
                        Picker("Select Camera", selection: Binding(
                            get: { statusBarController.virtualCameraManager.selectedCamera },
                            set: { newCamera in
                                if let camera = newCamera {
                                    statusBarController.virtualCameraManager.selectCamera(camera)
                                }
                            }
                        )) {
                            ForEach(statusBarController.virtualCameraManager.availableCameras, id: \.uniqueID) { camera in
                                Text(camera.localizedName).tag(camera as AVCaptureDevice?)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 8)
                        
                        Button("Refresh Cameras") {
                            statusBarController.virtualCameraManager.refreshCameras()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal)
            }
            
            Divider()
            
            // Plugin Status
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(statusBarController.virtualCameraManager.isPluginConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(statusBarController.virtualCameraManager.isPluginConnected ? "Plugin: Connected" : "Plugin: Disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                if !statusBarController.virtualCameraManager.isPluginConnected {
                    Button("Install Virtual Camera Plugin") {
                        statusBarController.installPlugin()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            VStack(spacing: 4) {
                // Overlay Selection
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Overlays")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    // No Overlay Option
                    OverlayMenuItem(
                        title: "No Overlay",
                        isSelected: statusBarController.selectedOverlay == nil,
                        action: {
                            statusBarController.selectOverlay(nil)
                        }
                    )
                    
                    // Available Overlays
                    ForEach(overlayManager.availableOverlays) { overlay in
                        OverlayMenuItem(
                            title: overlay.name,
                            isSelected: statusBarController.selectedOverlay?.id == overlay.id,
                            action: {
                                statusBarController.selectOverlay(overlay)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            Divider()
            
            // Settings Button
            Button("Settings...") {
                openSettings()
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            .padding(.vertical, 2)
            
            // Quit Button
            Button("Quit Scene It") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
        .frame(width: 220)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Actions
    
    private func openSettings() {
        let settingsView = SettingsView(virtualCameraManager: statusBarController.virtualCameraManager)
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Scene It Settings"
        window.contentViewController = hostingController
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // Keep window in front
        window.level = .floating
    }
}

struct OverlayMenuItem: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}

struct StatusBarMenuView_Previews: PreviewProvider {
    static var previews: some View {
        StatusBarMenuView(
            statusBarController: StatusBarController(virtualCameraManager: VirtualCameraManager()),
            overlayManager: OverlayManager()
        )
    }
}