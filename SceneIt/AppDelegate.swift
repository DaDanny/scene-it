import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var virtualCameraManager: VirtualCameraManager?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Basic test - this should ALWAYS show up
        print("========================================")
        print("🚀 SCENE IT APP IS STARTING")
        print("========================================")
        
        // Debug window replaces the need for popup alerts
        
        print("🚀 Scene It - App launching...")
        
        // For production: use .accessory to hide from dock
        // For debugging: use .regular to show debug window
        #if DEBUG
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        print("✅ Set activation policy to regular for debugging")
        showDebugWindow()
        #else
        NSApp.setActivationPolicy(.accessory)
        print("✅ Set activation policy to accessory (status bar only)")
        #endif
        // Initialize virtual camera manager
        virtualCameraManager = VirtualCameraManager()
        print("✅ VirtualCameraManager created")
        
        // Initialize status bar controller
        print("🔄 Creating StatusBarController...")
        statusBarController = StatusBarController(virtualCameraManager: virtualCameraManager!)
        
        if statusBarController != nil {
            print("✅ StatusBarController created successfully")
        } else {
            print("❌ Failed to create StatusBarController")
        }
        
        // Request camera permissions
        requestCameraPermission()
        
        print("🎯 Scene It launch complete - Look for camera icon in menu bar!")
        print("========================================")
    }
    
    private func showDebugWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Scene It - Debug Mode"
        window.center()
        
        let contentView = VStack(spacing: 16) {
            HStack {
                Image(systemName: "video.circle.fill")
                    .foregroundColor(.blue)
                    .font(.largeTitle)
                
                VStack(alignment: .leading) {
                    Text("Scene It is running! 🚀")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Virtual Camera with Overlays")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("✅ App launched successfully")
                Text("📹 Check the menu bar for the camera icon")
                Text("🎛️ Click the icon to access virtual camera controls")
                Text("👀 Use 'Show Preview' to see live video feed")
                Text("🔌 Install the plugin to enable virtual camera output")
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            HStack {
                Button("Show Preview") {
                    self.statusBarController?.togglePreviewWindow()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Hide This Window") {
                    window.close()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Stop virtual camera before terminating
        virtualCameraManager?.stopVirtualCamera()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't terminate when last window is closed - we run in status bar
        return false
    }
    
    private func requestCameraPermission() {
        virtualCameraManager?.requestCameraAccess { granted in
            DispatchQueue.main.async {
                if !granted {
                    let alert = NSAlert()
                    alert.messageText = "Camera Access Required"
                    alert.informativeText = "Scene It requires camera access to provide virtual camera functionality. Please grant camera permission in System Preferences."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
}
