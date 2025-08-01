import SwiftUI
import Cocoa
import AVFoundation

enum AppFlowState {
    case splash
    case welcome
    case onboarding
    case mainApp
    
    var debugDescription: String {
        switch self {
        case .splash: return "splash"
        case .welcome: return "welcome"
        case .onboarding: return "onboarding"
        case .mainApp: return "mainApp"
        }
    }
}

class AppFlowManager: ObservableObject {
    @Published var currentState: AppFlowState = .splash
    @Published var isFirstLaunch: Bool = true
    
    // Core app components
    var statusBarController: StatusBarController?
    var virtualCameraManager: VirtualCameraManager?
    var overlayManager = OverlayManager()
    
    // Window controllers
    private var welcomeWindowController: NSWindowController?
    private var onboardingWindowController: NSWindowController?
    private var settingsWindowController: NSWindowController?
    private var floatingControlWindowController: FloatingControlWindowController?
    
    init() {
        checkFirstLaunch()
        setupAppFlow()
    }
    
    private func checkFirstLaunch() {
        isFirstLaunch = !UserDefaults.standard.bool(forKey: "RituallyHasLaunchedBefore")
    }
    
    private func setupAppFlow() {
        print("🔄 AppFlowManager: setupAppFlow() called")
        print("🔄 AppFlowManager: isFirstLaunch = \(isFirstLaunch)")
        
        if isFirstLaunch {
            currentState = .splash
            print("🔄 AppFlowManager: First launch - starting with splash screen")
        } else {
            currentState = .mainApp
            setupMainApp()
            print("🔄 AppFlowManager: Returning user - going directly to main app")
        }
    }
    
    func completeAppLaunch() {
        if isFirstLaunch {
            currentState = .welcome
            showWelcomeWindow()
        } else {
            currentState = .mainApp
            setupMainApp()
        }
    }
    
    func startOnboarding() {
        currentState = .onboarding
        welcomeWindowController?.close()
        showOnboardingWindow()
    }
    
    func completeOnboarding() {
        currentState = .mainApp
        onboardingWindowController?.close()
        
        // Mark first launch as complete
        UserDefaults.standard.set(true, forKey: "RituallyHasLaunchedBefore")
        
        setupMainApp()
        
        print("✅ AppFlowManager: Onboarding completed - switching to menu bar mode")
    }
    
    private func setupMainApp() {
        print("🔄 AppFlowManager: Setting up main app components...")
        
        // Initialize main app components if not already done
        if virtualCameraManager == nil {
            print("🔄 Creating VirtualCameraManager...")
            virtualCameraManager = VirtualCameraManager()
        }
        
        if statusBarController == nil && virtualCameraManager != nil {
            print("🔄 Creating StatusBarController...")
            statusBarController = StatusBarController(virtualCameraManager: virtualCameraManager!)
        }
        
        // Setup floating control window
        if let statusBarController = statusBarController {
            print("🔄 Creating FloatingControlWindowController...")
            floatingControlWindowController = FloatingControlWindowController(
                statusBarController: statusBarController,
                overlayManager: overlayManager
            )
        }
        
        // Request camera permission
        requestCameraPermission()
        
        // Switch to accessory mode (menu bar only) after everything is set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.setActivationPolicy(.accessory)
            print("🔄 Switched to menu bar mode")
        }
        
        print("✅ AppFlowManager: Main app setup complete!")
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Camera permission granted")
                } else {
                    print("❌ Camera permission denied")
                }
            }
        }
    }
    
    // MARK: - Window Management
    
    private func showWelcomeWindow() {
        print("🔄 AppFlowManager: Showing welcome window...")
        
        // Set app to regular mode so it appears in Dock and can be activated
        NSApp.setActivationPolicy(.regular)
        
        let welcomeView = WelcomeScreen(onGetStarted: startOnboarding)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Welcome to Ritually"
        window.contentView = NSHostingView(rootView: welcomeView)
        window.level = .floating  // Make sure it stays on top
        window.makeKeyAndOrderFront(nil)
        
        // Activate the app and bring window to front
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        
        welcomeWindowController = NSWindowController(window: window)
        
        print("✅ AppFlowManager: Welcome window shown and activated")
    }
    
    private func showOnboardingWindow() {
        print("🔄 AppFlowManager: Showing onboarding window...")
        
        // Keep app in regular mode during onboarding
        NSApp.setActivationPolicy(.regular)
        
        let onboardingView = OnboardingFlow(onComplete: completeOnboarding)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Set up Ritually"
        window.contentView = NSHostingView(rootView: onboardingView)
        window.level = .floating  // Make sure it stays on top
        window.makeKeyAndOrderFront(nil)
        
        // Activate the app and bring window to front
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        
        onboardingWindowController = NSWindowController(window: window)
        
        print("✅ AppFlowManager: Onboarding window shown and activated")
    }
    
    func showSettingsWindow() {
        guard let virtualCameraManager = virtualCameraManager,
              let statusBarController = statusBarController else {
            print("Cannot show settings - required components not initialized")
            return
        }
        
        // Close existing settings window if open
        settingsWindowController?.close()
        
        let settingsView = SettingsView(
            virtualCameraManager: virtualCameraManager,
            statusBarController: statusBarController
        )
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Ritually Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.makeKeyAndOrderFront(nil)
        
        settingsWindowController = NSWindowController(window: window)
    }
    
    func showFloatingControls() {
        floatingControlWindowController?.show()
    }
    
    func hideFloatingControls() {
        floatingControlWindowController?.hide()
    }
    
    func toggleFloatingControls() {
        floatingControlWindowController?.toggle()
    }
    
    // MARK: - App State Management
    
    func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Global App Flow Manager

extension AppFlowManager {
    static let shared = AppFlowManager()
}

// MARK: - Integration with existing StatusBarController
// Note: Methods are now implemented directly in StatusBarController.swift