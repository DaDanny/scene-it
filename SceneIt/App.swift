import SwiftUI
import Cocoa

@main
struct RituallyApp: App {
    @StateObject private var appFlowManager = AppFlowManager.shared
    
    init() {
        // Force the app to show a window on launch
        print("🚀 RituallyApp: Initializing...")
    }
    
    var body: some Scene {
        // Main window - shows splash, then hides for menu bar mode
        WindowGroup {
            if appFlowManager.currentState == .splash {
                SplashScreen(onComplete: {
                    print("🚀 SplashScreen completed!")
                    appFlowManager.completeAppLaunch()
                })
                .frame(width: 500, height: 400)
                .onAppear {
                    print("🚀 SplashScreen appeared!")
                    // Ensure the app is active and window is visible
                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
            } else {
                // Hide main window after splash - app runs from menu bar or dedicated windows
                EmptyView()
                    .frame(width: 0, height: 0)
                    .hidden()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // Remove default menu items we don't need
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .pasteboard) { }
        }
    }
}