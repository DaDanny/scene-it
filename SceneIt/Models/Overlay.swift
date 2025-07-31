import Foundation
import AppKit

struct Overlay: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let imageName: String
    let description: String
    let image: NSImage?
    
    init(name: String, imageName: String, description: String) {
        self.name = name
        self.imageName = imageName
        self.description = description
        self.image = NSImage(named: imageName)
    }
    
    static func == (lhs: Overlay, rhs: Overlay) -> Bool {
        return lhs.id == rhs.id
    }
}

class OverlayManager: ObservableObject {
    @Published var availableOverlays: [Overlay] = []
    
    init() {
        loadDefaultOverlays()
    }
    
    private func loadDefaultOverlays() {
        // Default overlays - in a real implementation, these would be loaded from
        // assets or a configuration file
        availableOverlays = [
            Overlay(
                name: "Professional Frame",
                imageName: "professional_frame",
                description: "Clean, modern frame for professional meetings"
            ),
            Overlay(
                name: "Casual Border",
                imageName: "casual_border",
                description: "Friendly border for informal calls"
            ),
            Overlay(
                name: "Minimalist",
                imageName: "minimalist_overlay",
                description: "Subtle enhancement for any occasion"
            ),
            Overlay(
                name: "Branded",
                imageName: "branded_overlay",
                description: "Customizable overlay with logo placement"
            )
        ]
    }
    
    func addCustomOverlay(_ overlay: Overlay) {
        availableOverlays.append(overlay)
    }
    
    func removeOverlay(_ overlay: Overlay) {
        availableOverlays.removeAll { $0.id == overlay.id }
    }
}