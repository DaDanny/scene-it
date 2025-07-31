import Cocoa
import SwiftUI

class StatusBarController: ObservableObject {
    private var statusBarItem: NSStatusItem?
    private var virtualCameraManager: VirtualCameraManager
    @Published var isVirtualCameraActive = false
    @Published var selectedOverlay: Overlay?
    
    private var overlayManager = OverlayManager()
    private var previewWindowController: VideoPreviewWindowController?
    
    init(virtualCameraManager: VirtualCameraManager) {
        print("🔄 StatusBarController init starting...")
        self.virtualCameraManager = virtualCameraManager
        
        print("🔄 Setting up status bar item...")
        setupStatusBarItem()
        
        print("🔄 Creating initial menu...")
        updateMenu()
        
        // Listen for virtual camera state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(virtualCameraStateChanged),
            name: .virtualCameraStateChanged,
            object: nil
        )
        
        print("✅ StatusBarController init complete")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupStatusBarItem() {
        print("🔄 Creating NSStatusBar item...")
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let statusBarItem = statusBarItem {
            print("✅ StatusBar item created")
            
            if let statusBarButton = statusBarItem.button {
                print("✅ StatusBar button available")
                
                // Try to set the image
                if let image = NSImage(systemSymbolName: "video.circle", accessibilityDescription: "Scene It") {
                    statusBarButton.image = image
                    statusBarButton.image?.isTemplate = true
                    print("✅ Status bar image set: video.circle - Look for camera icon in menu bar!")
                } else {
                    // Fallback to a simple text
                    statusBarButton.title = "📹"
                    print("⚠️ Using fallback emoji icon - Look for 📹 in menu bar!")
                }
                
                // Modern approach: just set the menu, no need for action
                // statusBarButton.action = #selector(statusBarButtonClicked)
                // statusBarButton.target = self
                print("✅ Status bar button configured")
            } else {
                print("❌ Could not get statusBarButton")
            }
        } else {
            print("❌ Failed to create status bar item")
        }
    }
    
    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Virtual Camera Status
        let statusItem = NSMenuItem(
            title: isVirtualCameraActive ? "Virtual Camera: Active" : "Virtual Camera: Inactive",
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Start/Stop Virtual Camera
        let toggleItem = NSMenuItem(
            title: isVirtualCameraActive ? "Stop Virtual Camera" : "Start Virtual Camera",
            action: #selector(toggleVirtualCamera),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Preview Window
        let previewItem = NSMenuItem(
            title: previewWindowController?.window?.isVisible == true ? "Hide Preview" : "Show Preview",
            action: #selector(togglePreviewWindow),
            keyEquivalent: "p"
        )
        previewItem.target = self
        menu.addItem(previewItem)
        
        // Plugin Status
        let pluginStatusItem = NSMenuItem(
            title: virtualCameraManager.isPluginConnected ? "Plugin: Connected" : "Plugin: Disconnected",
            action: nil,
            keyEquivalent: ""
        )
        pluginStatusItem.isEnabled = false
        menu.addItem(pluginStatusItem)
        
        // Install Plugin (if not connected)
        if !virtualCameraManager.isPluginConnected {
            let installItem = NSMenuItem(
                title: "Install Virtual Camera Plugin",
                action: #selector(installPlugin),
                keyEquivalent: ""
            )
            installItem.target = self
            menu.addItem(installItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Overlay Selection
        let overlaySubmenu = NSMenu()
        
        // No overlay option
        let noOverlayItem = NSMenuItem(title: "No Overlay", action: #selector(selectNoOverlay), keyEquivalent: "")
        noOverlayItem.target = self
        noOverlayItem.state = selectedOverlay == nil ? .on : .off
        overlaySubmenu.addItem(noOverlayItem)
        
        overlaySubmenu.addItem(NSMenuItem.separator())
        
        // Available overlays
        for overlay in overlayManager.availableOverlays {
            let overlayItem = NSMenuItem(title: overlay.name, action: #selector(selectOverlay(_:)), keyEquivalent: "")
            overlayItem.target = self
            overlayItem.representedObject = overlay
            overlayItem.state = selectedOverlay?.id == overlay.id ? .on : .off
            overlaySubmenu.addItem(overlayItem)
        }
        
        let overlayMenuItem = NSMenuItem(title: "Select Overlay", action: nil, keyEquivalent: "")
        overlayMenuItem.submenu = overlaySubmenu
        menu.addItem(overlayMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit Scene It", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }
    
    private func updateMenu() {
        statusBarItem?.menu = createMenu()
    }
    
    @objc private func toggleVirtualCamera() {
        if isVirtualCameraActive {
            virtualCameraManager.stopVirtualCamera()
        } else {
            virtualCameraManager.startVirtualCamera(with: selectedOverlay)
        }
    }
    
    @objc private func selectNoOverlay() {
        selectedOverlay = nil
        if isVirtualCameraActive {
            virtualCameraManager.updateOverlay(selectedOverlay)
        }
        updateMenu() // Refresh menu to show new selection
    }
    
    @objc private func selectOverlay(_ sender: NSMenuItem) {
        guard let overlay = sender.representedObject as? Overlay else { return }
        selectedOverlay = overlay
        if isVirtualCameraActive {
            virtualCameraManager.updateOverlay(selectedOverlay)
        }
        updateMenu() // Refresh menu to show new selection
    }
    
    @objc private func togglePreviewWindow() {
        if let windowController = previewWindowController {
            if windowController.window?.isVisible == true {
                windowController.window?.close()
            } else {
                windowController.showWindow(nil)
            }
        } else {
            // Create new preview window
            previewWindowController = VideoPreviewWindowController(virtualCameraManager: virtualCameraManager)
            previewWindowController?.showWindow(nil)
        }
        updateMenu() // Refresh menu to update preview toggle text
    }
    
    @objc private func installPlugin() {
        let alert = NSAlert()
        alert.messageText = "Install Virtual Camera Plugin"
        alert.informativeText = "This will install the Scene It virtual camera plugin to your system. You may need to restart video applications after installation."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Show progress
            let progressAlert = NSAlert()
            progressAlert.messageText = "Installing Plugin..."
            progressAlert.informativeText = "Please wait while the virtual camera plugin is installed."
            progressAlert.alertStyle = .informational
            progressAlert.addButton(withTitle: "OK")
            
            DispatchQueue.global(qos: .userInitiated).async {
                let success = self.virtualCameraManager.installPlugin()
                
                DispatchQueue.main.async {
                    progressAlert.window.close()
                    
                    let resultAlert = NSAlert()
                    if success {
                        resultAlert.messageText = "Plugin Installed Successfully"
                        resultAlert.informativeText = "The virtual camera plugin has been installed. Restart video applications to see 'Scene It Virtual Camera' in their camera lists."
                        resultAlert.alertStyle = .informational
                    } else {
                        resultAlert.messageText = "Plugin Installation Failed"
                        resultAlert.informativeText = "There was an error installing the virtual camera plugin. Please check the console for details."
                        resultAlert.alertStyle = .warning
                    }
                    resultAlert.addButton(withTitle: "OK")
                    resultAlert.runModal()
                    
                    self.updateMenu()
                }
            }
            
            progressAlert.runModal()
        }
    }
    
    @objc private func quit() {
        previewWindowController?.window?.close()
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func virtualCameraStateChanged() {
        DispatchQueue.main.async {
            self.isVirtualCameraActive = self.virtualCameraManager.isActive
            self.updateMenu() // Refresh menu when state changes
        }
    }
}

extension Notification.Name {
    static let virtualCameraStateChanged = Notification.Name("virtualCameraStateChanged")
}