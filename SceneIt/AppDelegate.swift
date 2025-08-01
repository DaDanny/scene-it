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
        
        print("🚀 Scene It - App launching...")
        
        // Set activation policy to accessory (status bar only app)
        NSApp.setActivationPolicy(.accessory)
        print("✅ Set activation policy to accessory (status bar only)")
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
