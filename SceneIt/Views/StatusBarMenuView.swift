import SwiftUI

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
                    // Toggle virtual camera
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
                
                Divider()
                
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
                            statusBarController.selectedOverlay = nil
                        }
                    )
                    
                    // Available Overlays
                    ForEach(overlayManager.availableOverlays) { overlay in
                        OverlayMenuItem(
                            title: overlay.name,
                            isSelected: statusBarController.selectedOverlay?.id == overlay.id,
                            action: {
                                statusBarController.selectedOverlay = overlay
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            Divider()
            
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