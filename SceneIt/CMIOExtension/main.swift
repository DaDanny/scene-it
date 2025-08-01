import Foundation
import CoreMediaIO
import os.log

/// Main entry point for the CoreMediaIO System Extension
/// This is the entry point that macOS will use to start the extension
@main
class SceneItCMIOExtensionMain {
    static func main() {
        let logger = Logger(subsystem: "com.ritually.SceneIt.CameraExtension", category: "Main")
        logger.info("🚀 Starting Ritually Virtual Camera Extension...")
        
        // Create and start the CMIO extension provider
        let providerSource = SceneItCMIOProvider.providerSource
        
        // Create XPC frame receiver to handle communication with main app
        let xpcReceiver = XPCFrameReceiver()
        
        logger.info("✅ Extension components initialized, starting CMIO service...")
        
        // Start the CoreMediaIO extension service
        // This call blocks and runs the extension's main loop
        CMIOExtensionProvider.startService(provider: providerSource)
        
        logger.info("📹 CoreMediaIO extension service started")
        
        // The extension will continue running until terminated by the system
        RunLoop.main.run()
    }
}