import Foundation
import SystemExtensions
import os.log

/// Manages installation and lifecycle of the CoreMediaIO system extension
class CMIOExtensionInstaller: NSObject, ObservableObject {
    private let logger = Logger(subsystem: "com.dannyfrancken.sceneit", category: "CMIOExtensionInstaller")
    
    @Published var status: SystemExtensionStatus = .notInstalled
    @Published var statusMessage: String = ""
    @Published var isInstalling: Bool = false
    
    private let extensionIdentifier = "com.dannyfrancken.sceneit.cameraextension"
    private var currentRequest: OSSystemExtensionRequest?
    
    override init() {
        super.init()
        logger.info("CMIOExtensionInstaller initialized")
        checkExtensionStatus()
    }
    
    // MARK: - Public Interface
    
    /// Install or activate the system extension
    func installExtension() {
        guard !isInstalling else {
            logger.warning("Extension installation already in progress")
            return
        }
        
        logger.info("Starting system extension installation...")
        isInstalling = true
        status = .installing
        statusMessage = "Installing virtual camera extension..."
        
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: extensionIdentifier,
            queue: .main
        )
        request.delegate = self
        currentRequest = request
        
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    /// Uninstall the system extension
    func uninstallExtension() {
        guard !isInstalling else {
            logger.warning("Cannot uninstall while installation is in progress")
            return
        }
        
        logger.info("Starting system extension uninstallation...")
        isInstalling = true
        status = .inactive
        statusMessage = "Removing virtual camera extension..."
        
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: extensionIdentifier,
            queue: .main
        )
        request.delegate = self
        currentRequest = request
        
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    /// Check current extension status
    func checkExtensionStatus() {
        logger.debug("Checking system extension status...")
        
        // Note: There's no direct API to query extension status
        // We'll determine status based on installation attempts and XPC connectivity
        // This is a simplified approach - production apps may need more sophisticated detection
        
        updateStatus(.notInstalled, message: "Checking extension status...")
    }
    
    /// Force refresh of extension status
    func refreshStatus() {
        checkExtensionStatus()
    }
    
    // MARK: - Private Methods
    
    private func updateStatus(_ newStatus: SystemExtensionStatus, message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.status = newStatus
            self?.statusMessage = message
            self?.isInstalling = (newStatus == .installing)
            
            self?.logger.info("Extension status updated: \(newStatus.rawValue) - \(message)")
            
            NotificationCenter.default.post(
                name: .systemExtensionStatusChanged,
                object: nil,
                userInfo: [
                    "status": newStatus.rawValue,
                    "message": message
                ]
            )
        }
    }
    
    private func handleInstallationSuccess() {
        logger.info("✅ System extension installation successful")
        updateStatus(.active, message: "Virtual camera extension is active")
    }
    
    private func handleInstallationFailure(_ error: Error) {
        logger.error("❌ System extension installation failed: \(error.localizedDescription)")
        
        let errorMessage: String
        if let systemExtensionError = error as? OSSystemExtensionError {
            errorMessage = getSystemExtensionErrorMessage(systemExtensionError)
        } else {
            errorMessage = error.localizedDescription
        }
        
        updateStatus(.error, message: "Installation failed: \(errorMessage)")
    }
    
    private func getSystemExtensionErrorMessage(_ error: OSSystemExtensionError) -> String {
        switch error.code {
        case .extensionNotFound:
            return "Extension not found in app bundle"
        case .missingEntitlement:
            return "Missing required entitlements"
        case .unsupportedParentBundleLocation:
            return "App must be in /Applications folder"
        case .extensionNotFound:
            return "Extension binary not found"
        case .authorizationRequired:
            return "User authorization required in System Preferences"
        case .requestCanceled:
            return "Installation was canceled"
        case .requestSuperseded:
            return "Installation request was superseded"
        case .validationFailed:
            return "Extension validation failed"
        @unknown default:
            return "Unknown system extension error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - User Guidance
    
    /// Get user-friendly instructions for common issues
    func getInstallationInstructions() -> String {
        switch status {
        case .needsApproval:
            return """
            To complete installation:
            1. Open System Preferences
            2. Go to Privacy & Security
            3. Look for "System software from developer 'Ritually' was blocked from loading"
            4. Click "Allow" next to the blocked software
            5. Restart Ritually
            """
            
        case .error:
            return """
            Installation failed. Try these steps:
            1. Make sure Ritually is in your Applications folder
            2. Restart your Mac
            3. Try installing again
            4. Check System Preferences > Privacy & Security for any blocked software
            """
            
        case .notInstalled:
            return """
            Click 'Install Virtual Camera' to set up the virtual camera extension.
            You may need to approve the extension in System Preferences.
            """
            
        case .installing:
            return """
            Installing virtual camera extension...
            You may see a system prompt asking for permission.
            """
            
        case .active:
            return """
            Virtual camera extension is active and ready to use.
            The camera should appear in video conferencing applications.
            """
            
        case .inactive:
            return """
            Virtual camera extension is installed but not active.
            Try restarting the application.
            """
        }
    }
    
    /// Check if extension requires user approval
    func requiresUserApproval() -> Bool {
        return status == .needsApproval
    }
    
    /// Check if extension is ready for use
    func isExtensionReady() -> Bool {
        return status.isOperational
    }
}

// MARK: - OSSystemExtensionRequestDelegate

extension CMIOExtensionInstaller: OSSystemExtensionRequestDelegate {
    
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        logger.info("System extension replacement requested")
        return .replace
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        logger.warning("System extension needs user approval")
        updateStatus(.needsApproval, message: "Approval required in System Preferences")
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        logger.info("System extension request completed with result: \(result.rawValue)")
        
        switch result {
        case .completed:
            handleInstallationSuccess()
        case .willCompleteAfterReboot:
            updateStatus(.needsApproval, message: "Extension will activate after restart")
        @unknown default:
            updateStatus(.error, message: "Unknown installation result")
        }
        
        currentRequest = nil
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        logger.error("System extension request failed: \(error.localizedDescription)")
        handleInstallationFailure(error)
        currentRequest = nil
    }
}