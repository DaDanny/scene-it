import SwiftUI
import AVFoundation

struct StatusBarMenuView: View {
    @ObservedObject var statusBarController: StatusBarController
    @ObservedObject var overlayManager: OverlayManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header - optimized for fast rendering
            HStack {
                Image(systemName: "video.circle.fill")
                    .foregroundColor(.blue)
                    .imageScale(.medium) // Prevent dynamic scaling
                Text("Ritually")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
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
                VStack(alignment: .leading, spacing: 6) {
                    Text("Camera")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    if statusBarController.virtualCameraManager.availableCameras.isEmpty {
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("No cameras detected")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Spacer()
                            Button("Refresh") {
                                statusBarController.virtualCameraManager.refreshCameras()
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.mini)
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 4) {
                            // Camera Picker
                            Menu {
                                ForEach(statusBarController.virtualCameraManager.availableCameras, id: \.uniqueID) { camera in
                                    Button(camera.localizedName) {
                                        statusBarController.virtualCameraManager.selectCamera(camera)
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "camera.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text(statusBarController.virtualCameraManager.selectedCamera?.localizedName ?? "Select Camera")
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                            
                            // Refresh Button
                            Button {
                                statusBarController.virtualCameraManager.refreshCameras()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption2)
                                    Text("Refresh Cameras")
                                        .font(.caption2)
                                }
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            
            Divider()
            
            // Plugin Status
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Circle()
                        .fill(statusBarController.virtualCameraManager.isPluginConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(statusBarController.virtualCameraManager.isPluginConnected ? "Plugin: Connected" : "Plugin: Disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                
                if !statusBarController.virtualCameraManager.isPluginConnected {
                    Button {
                        statusBarController.installPlugin()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .font(.caption)
                            Text("Install Virtual Camera Plugin")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
            
            Divider()
            
            // Overlay Selection
            VStack(alignment: .leading, spacing: 6) {
                Text("Overlays")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                VStack(spacing: 2) {
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
            
            // Bottom Actions
            VStack(spacing: 8) {
                Button {
                    openSettings()
                } label: {
                    HStack {
                        Image(systemName: "gear")
                            .font(.caption)
                        Text("Settings...")
                            .font(.system(size: 12))
                        Spacer()
                    }
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack {
                        Image(systemName: "power")
                            .font(.caption)
                        Text("Quit Ritually")
                            .font(.system(size: 12))
                        Spacer()
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 240)
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
        
        window.title = "Ritually Settings"
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
                    .foregroundColor(isSelected ? .blue : .primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
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