import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var virtualCameraManager: VirtualCameraManager?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Basic test - this should ALWAYS show up
        print("========================================")
        print("🚀 RITUALLY APP IS STARTING")
        print("========================================")
        
        print("🚀 Ritually - App launching...")
        
        // Set activation policy to regular app (shows in dock + status bar)
        NSApp.setActivationPolicy(.regular)
        print("✅ Set activation policy to regular (dock + status bar app)")
        
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
        
        // Set up dock menu
        setupDockMenu()
        
        print("🎯 Ritually launch complete!")
        print("📱 Available in DOCK and MENU BAR for easy access")
        print("⌨️ Keyboard shortcut: CMD+SHIFT+S")
        print("🖱️ Right-click dock icon for quick actions")
        print("========================================")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Stop virtual camera before terminating
        virtualCameraManager?.stopVirtualCamera()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't terminate when last window is closed - we run in dock and status bar
        return false
    }
    
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let dockMenu = NSMenu()
        
        // Toggle Virtual Camera
        let toggleItem = NSMenuItem(title: virtualCameraManager?.isActive == true ? "Stop Virtual Camera" : "Start Virtual Camera", action: #selector(toggleVirtualCameraFromDock), keyEquivalent: "")
        toggleItem.target = self
        dockMenu.addItem(toggleItem)
        
        dockMenu.addItem(NSMenuItem.separator())
        
        // Show Preview
        let previewItem = NSMenuItem(title: "Show Preview Window", action: #selector(showPreviewFromDock), keyEquivalent: "")
        previewItem.target = self
        dockMenu.addItem(previewItem)
        
        // Open Menu
        let menuItem = NSMenuItem(title: "Open Ritually Menu", action: #selector(openMenuFromDock), keyEquivalent: "")
        menuItem.target = self
        dockMenu.addItem(menuItem)
        
        return dockMenu
    }
    
    private func setupDockMenu() {
        // The dock menu is set up via applicationDockMenu delegate method
        print("✅ Dock menu configured - right-click dock icon for quick actions")
    }
    
    @objc private func toggleVirtualCameraFromDock() {
        statusBarController?.toggleVirtualCamera()
    }
    
    @objc private func showPreviewFromDock() {
        statusBarController?.togglePreviewWindow()
    }
    
    @objc private func openMenuFromDock() {
        // Activate the app first
        NSApp.activate(ignoringOtherApps: true)
        
        // Trigger the status bar controller to show menu
        if let statusBarController = statusBarController {
            // Use the keyboard shortcut method for consistent behavior
            DispatchQueue.main.async {
                statusBarController.showMenuFromKeyboard()
            }
        }
    }
    
    private func requestCameraPermission() {
        virtualCameraManager?.requestCameraAccess { granted in
            DispatchQueue.main.async {
                if !granted {
                    let alert = NSAlert()
                    alert.messageText = "Camera Access Required"
                    alert.informativeText = "Ritually requires camera access to provide virtual camera functionality. Please grant camera permission in System Preferences."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
}
