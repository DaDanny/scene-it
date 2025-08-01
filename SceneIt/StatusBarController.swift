import Cocoa
import SwiftUI

class StatusBarController: ObservableObject {
    private var statusBarItem: NSStatusItem?
    var virtualCameraManager: VirtualCameraManager
    private var extensionInstaller = CMIOExtensionInstaller()
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
        
        print("🔄 Setting up global keyboard shortcut...")
        setupGlobalKeyboardShortcut()
        
        // Listen for virtual camera state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(virtualCameraStateChanged),
            name: .virtualCameraStateChanged,
            object: nil
        )
        
        print("✅ StatusBarController init complete")
        print("⌨️ Global shortcut: CMD+SHIFT+S")
        print("🔗 Access via: Menu Bar + Dock + Keyboard")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Ritually UI Integration
    
    func showSettings() {
        AppFlowManager.shared.showSettingsWindow()
    }
    
    func showFloatingControls() {
        AppFlowManager.shared.showFloatingControls()
    }
    
    func hideFloatingControls() {
        AppFlowManager.shared.hideFloatingControls()
    }
    
    func toggleFloatingControls() {
        AppFlowManager.shared.toggleFloatingControls()
    }
    
    private func setupStatusBarItem() {
        print("🔄 Creating NSStatusBar item...")
        
        // Use variableLength for better visibility and set priority
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusBarItem = statusBarItem {
            print("✅ StatusBar item created")
            
            // Set a higher priority to keep it visible
            statusBarItem.autosaveName = "SceneItStatusItem"
            
            if let statusBarButton = statusBarItem.button {
                print("✅ StatusBar button available")
                
                // Try to set the image with better fallback
                if let image = NSImage(systemSymbolName: "video.circle.fill", accessibilityDescription: "Ritually") {
                    statusBarButton.image = image
                    statusBarButton.image?.isTemplate = true
                    statusBarButton.image?.size = NSSize(width: 18, height: 18)
                    print("✅ Status bar image set: video.circle.fill - Look for camera icon in menu bar!")
                } else if let image = NSImage(systemSymbolName: "camera", accessibilityDescription: "Ritually") {
                    statusBarButton.image = image
                    statusBarButton.image?.isTemplate = true
                    statusBarButton.image?.size = NSSize(width: 18, height: 18)
                    print("✅ Status bar image set: camera - Look for camera icon in menu bar!")
                } else {
                    // Fallback to a simple text that's more visible
                    statusBarButton.title = "📹"
                    statusBarButton.font = NSFont.systemFont(ofSize: 16, weight: .bold)
                    print("⚠️ Using fallback emoji icon '📹' - Look for '📹' in menu bar!")
                }
                
                // Set tooltip for better accessibility
                statusBarButton.toolTip = "Ritually - Virtual Camera"
                
                // Set up click action for SwiftUI popover
                statusBarButton.action = #selector(statusBarButtonClicked)
                statusBarButton.target = self
                
                // Add right-click support for alternative access
                statusBarButton.sendAction(on: [.leftMouseUp, .rightMouseUp])
                
                print("✅ Status bar button configured with tooltip and right-click support")
                
                // Log visibility status
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.checkStatusBarVisibility()
                }
            } else {
                print("❌ Could not get statusBarButton")
            }
        } else {
            print("❌ Failed to create status bar item")
        }
    }
    
    private func checkStatusBarVisibility() {
        if let button = statusBarItem?.button {
            let isVisible = button.window != nil && !button.isHidden
            print("🔍 Status bar item: \(isVisible ? "VISIBLE" : "HIDDEN")")
            
            if !isVisible {
                print("💡 Status bar item hidden - use dock icon or CMD+SHIFT+S")
            } else {
                print("✅ Status bar item available in menu bar")
            }
        }
    }
    
    private func setupMenuPopover() {
        menuPopover = NSPopover()
        menuPopover?.contentSize = NSSize(width: 280, height: 420)
        menuPopover?.behavior = .transient
        menuPopover?.animates = false // Disable animations for instant response
        
        let menuView = StatusBarMenuView(statusBarController: self, overlayManager: overlayManager)
        let hostingController = NSHostingController(rootView: menuView)
        
        // Optimize hosting controller for performance
        hostingController.view.wantsLayer = true
        hostingController.view.layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        // Pre-size the hosting controller to avoid layout delays
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 280, height: 420)
        
        menuPopover?.contentViewController = hostingController
        
        // Pre-warm the popover by preparing it off-screen
        DispatchQueue.main.async {
            self.prewarmPopover()
        }
        
        print("✅ SwiftUI popover configured with caching optimizations")
    }
    
    private func prewarmPopover() {
        // Pre-render the popover by forcing view load and initial layout
        guard let popover = menuPopover else { return }
        
        if let hostingController = popover.contentViewController as? NSHostingController<StatusBarMenuView> {
            // Force the hosting controller to load and layout its view
            let view = hostingController.view
            view.layoutSubtreeIfNeeded()
            
            // Cache the view hierarchy for faster subsequent displays
            view.needsDisplay = false
        }
        
        print("✅ Popover pre-warmed for fast display")
    }
    
    private func setupGlobalKeyboardShortcut() {
        let eventMask = NSEvent.EventTypeMask.keyDown
        NSEvent.addGlobalMonitorForEvents(matching: eventMask) { event in
            // Check for CMD+SHIFT+S
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 1 { // S key
                DispatchQueue.main.async {
                    self.showMenuFromKeyboard()
                }
            }
        }
        
        // Also add local monitor for when the app is active
        NSEvent.addLocalMonitorForEvents(matching: eventMask) { event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 1 { // S key
                DispatchQueue.main.async {
                    self.showMenuFromKeyboard()
                }
                return nil // Consume the event
            }
            return event
        }
    }
    
    func showMenuFromKeyboard() {
        print("⌨️ Global keyboard shortcut triggered - showing Ritually menu")
        
        // Find the center of the screen for menu placement
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let centerPoint = NSPoint(x: screenFrame.midX, y: screenFrame.midY + 100)
        
        // Create a temporary invisible button for positioning
        let tempButton = NSButton(frame: NSRect(x: centerPoint.x, y: centerPoint.y, width: 1, height: 1))
        
        if let popover = menuPopover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                // Show popover at center of screen
                if let window = NSApp.windows.first {
                    window.contentView?.addSubview(tempButton)
                    popover.show(relativeTo: tempButton.bounds, of: tempButton, preferredEdge: .minY)
                    
                    // Remove temp button after showing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        tempButton.removeFromSuperview()
                    }
                }
            }
        }
    }
    
    @objc private func statusBarButtonClicked() {
        // Immediate response - no delays on main thread
        guard let button = statusBarItem?.button else { return }
        guard let popover = menuPopover else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        if popover.isShown {
            popover.performClose(nil)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("⚡ Menu closed in \(String(format: "%.1f", duration * 1000))ms")
        } else {
            // Show immediately without additional checks
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("⚡ Menu opened in \(String(format: "%.1f", duration * 1000))ms")
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
            previewWindowController = VideoPreviewWindowController(virtualCameraManager: virtualCameraManager, statusBarController: self)
            previewWindowController?.showWindow(nil)
        }
        // SwiftUI will automatically update the UI through @Published properties
    }
    
    // Called by VideoPreviewWindowController when window is closing
    func previewWindowDidClose() {
        print("🪟 Preview window closed, cleaning up reference")
        previewWindowController = nil
    }
    
    func installPlugin() {
        let alert = NSAlert()
        alert.messageText = "Install Virtual Camera Plugin"
        alert.informativeText = "This will install the Ritually virtual camera plugin to your system. You may need to restart video applications after installation."
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
                self.extensionInstaller.installExtension()
                
                DispatchQueue.main.async {
                    progressAlert.window.close()
                    
                    let resultAlert = NSAlert()
                    resultAlert.messageText = "Extension Installation Started"
                    resultAlert.informativeText = "The system extension installation has been initiated. Please check System Preferences → Privacy & Security to approve the extension."
                    resultAlert.alertStyle = .informational
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

