import Cocoa
import SwiftUI

class StatusBarController: ObservableObject {
    private var statusBarItem: NSStatusItem?
    var virtualCameraManager: VirtualCameraManager
    @Published var isVirtualCameraActive = false
    @Published var selectedOverlay: Overlay?
    
    private var overlayManager = OverlayManager()
    private var previewWindowController: VideoPreviewWindowController?
    private var menuPopover: NSPopover?
    
    init(virtualCameraManager: VirtualCameraManager) {
        print("🔄 StatusBarController init starting...")
        self.virtualCameraManager = virtualCameraManager
        
        print("🔄 Setting up status bar item...")
        setupStatusBarItem()
        
        print("🔄 Setting up SwiftUI popover...")
        setupMenuPopover()
        
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
                
                // Set up click action for SwiftUI popover
                statusBarButton.action = #selector(statusBarButtonClicked)
                statusBarButton.target = self
                print("✅ Status bar button configured")
            } else {
                print("❌ Could not get statusBarButton")
            }
        } else {
            print("❌ Failed to create status bar item")
        }
    }
    
    private func setupMenuPopover() {
        menuPopover = NSPopover()
        menuPopover?.contentSize = NSSize(width: 260, height: 400)
        menuPopover?.behavior = .transient
        menuPopover?.animates = true
        
        let menuView = StatusBarMenuView(statusBarController: self, overlayManager: overlayManager)
        menuPopover?.contentViewController = NSHostingController(rootView: menuView)
        
        print("✅ SwiftUI popover configured")
    }
    
    @objc private func statusBarButtonClicked() {
        guard let button = statusBarItem?.button else { return }
        guard let popover = menuPopover else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }
    
    // Public methods for SwiftUI view to call
    func toggleVirtualCamera() {
        if isVirtualCameraActive {
            virtualCameraManager.stopVirtualCamera()
        } else {
            virtualCameraManager.startVirtualCamera(with: selectedOverlay)
        }
    }
    
    func selectOverlay(_ overlay: Overlay?) {
        selectedOverlay = overlay
        if isVirtualCameraActive {
            virtualCameraManager.updateOverlay(selectedOverlay)
        }
    }
    
    @objc func togglePreviewWindow() {
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
        // SwiftUI will automatically update the UI through @Published properties
    }
    
    func installPlugin() {
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
                    
                    // SwiftUI will automatically update the UI through @Published properties
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
            // SwiftUI will automatically update the UI through @Published properties
        }
    }
}

extension Notification.Name {
    static let virtualCameraStateChanged = Notification.Name("virtualCameraStateChanged")
}