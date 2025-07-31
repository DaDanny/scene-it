import Foundation
import AVFoundation
import Combine

/// Application settings model
class AppSettings: ObservableObject {
    
    @Published var userName: String {
        didSet {
            UserDefaults.standard.set(userName, forKey: "SceneIt_UserName")
        }
    }
    
    @Published var userJobTitle: String {
        didSet {
            UserDefaults.standard.set(userJobTitle, forKey: "SceneIt_UserJobTitle")
        }
    }
    
    @Published var selectedCameraID: String? {
        didSet {
            UserDefaults.standard.set(selectedCameraID, forKey: "SceneIt_SelectedCameraID")
        }
    }
    
    static let shared = AppSettings()
    
    private init() {
        // Load saved settings
        self.userName = UserDefaults.standard.string(forKey: "SceneIt_UserName") ?? ""
        self.userJobTitle = UserDefaults.standard.string(forKey: "SceneIt_UserJobTitle") ?? ""
        self.selectedCameraID = UserDefaults.standard.string(forKey: "SceneIt_SelectedCameraID")
    }
    
    /// Get the selected camera device
    func getSelectedCamera(from availableCameras: [AVCaptureDevice]) -> AVCaptureDevice? {
        guard let selectedID = selectedCameraID else {
            return availableCameras.first // Default to first available
        }
        
        return availableCameras.first { $0.uniqueID == selectedID } ?? availableCameras.first
    }
    
    /// Update selected camera from device
    func selectCamera(_ camera: AVCaptureDevice) {
        selectedCameraID = camera.uniqueID
    }
}