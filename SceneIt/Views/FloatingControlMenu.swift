import SwiftUI
import Cocoa

class FloatingControlWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 100, y: 100, width: 200, height: 300),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.level = .floating
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        
        // Make window stay on top but not steal focus
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
    }
}

class FloatingControlWindowController: NSWindowController, ObservableObject {
    @Published var isVisible = false
    
    convenience init(statusBarController: StatusBarController, overlayManager: OverlayManager) {
        let window = FloatingControlWindow()
        self.init(window: window)
        
        let contentView = FloatingControlMenu(
            statusBarController: statusBarController,
            overlayManager: overlayManager,
            windowController: self
        )
        
        window.contentView = NSHostingView(rootView: contentView)
        window.delegate = self
    }
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
        isVisible = true
    }
    
    func hide() {
        window?.orderOut(nil)
        isVisible = false
    }
    
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
}

extension FloatingControlWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        isVisible = false
    }
}

struct FloatingControlMenu: View {
    @ObservedObject var statusBarController: StatusBarController
    @ObservedObject var overlayManager: OverlayManager
    @ObservedObject var windowController: FloatingControlWindowController
    @State private var aspectRatio = "16:9"
    @State private var showPreview = false
    @State private var isCollapsed = false
    
    private let aspectRatios = ["16:9", "4:3"]
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            if !isCollapsed {
                mainControlsView
            }
        }
        .background(backgroundView)
        .frame(width: 200)
        .fixedSize(horizontal: true, vertical: true)
    }
    
    private var headerView: some View {
        HStack {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.quaternaryLabelColor))
                .frame(width: 20, height: 4)
            
            Spacer()
            
            // Collapse/expand button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isCollapsed.toggle()
                }
            }) {
                Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.controlBackgroundColor))
    }
    
    private var mainControlsView: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(spacing: 16) {
                virtualCameraSection
                Divider()
                overlaySection
                Divider()
                quickActionsSection
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
        }
    }
    
    private var virtualCameraSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Virtual Camera")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusBarController.isVirtualCameraActive ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(statusBarController.isVirtualCameraActive ? "Active" : "Inactive")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(statusBarController.isVirtualCameraActive ? "Stop" : "Start") {
                statusBarController.toggleVirtualCamera()
            }
            .buttonStyle(PlainButtonStyle())
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        statusBarController.isVirtualCameraActive ? 
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.red.opacity(0.1),
                                Color.red.opacity(0.05)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor,
                                Color.accentColor.opacity(0.8)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .foregroundColor(statusBarController.isVirtualCameraActive ? .red : .white)
        }
    }
    
    private var overlaySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Overlays")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Menu {
                    Button("None") {
                        statusBarController.selectedOverlay = nil
                    }
                    
                    ForEach(overlayManager.availableOverlays, id: \.id) { overlay in
                        Button(overlay.name) {
                            statusBarController.selectedOverlay = overlay
                        }
                    }
                } label: {
                    Text(statusBarController.selectedOverlay?.name ?? "None")
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.controlColor))
                        )
                        .foregroundColor(.primary)
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }
            
            if statusBarController.selectedOverlay != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Layout")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 6) {
                        ForEach(aspectRatios, id: \.self) { ratio in
                            Button(ratio) {
                                aspectRatio = ratio
                            }
                            .buttonStyle(PlainButtonStyle())
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(ratio == aspectRatio ? 
                                        Color.accentColor : 
                                        Color(.controlColor)
                                    )
                            )
                            .foregroundColor(ratio == aspectRatio ? .white : .primary)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var quickActionsSection: some View {
        HStack(spacing: 8) {
            Button(action: {
                showPreview.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 9))
                    Text("Preview")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.controlColor))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            Button(action: {
                // TODO: Implement showSettings in StatusBarController
                print("Settings button tapped")
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.controlColor))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.controlBackgroundColor))
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separatorColor).opacity(0.5), lineWidth: 1)
            )
    }
}

#Preview("Floating Control Menu") {
    // This would typically be shown via FloatingControlWindowController
    Text("Floating Control Menu Preview")
        .frame(width: 200, height: 100)
        .background(Color(.controlBackgroundColor))
}