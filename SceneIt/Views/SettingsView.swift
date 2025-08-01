import SwiftUI
import AVFoundation

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var virtualCameraManager: VirtualCameraManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempUserName: String = ""
    @State private var tempUserJobTitle: String = ""
    @State private var tempSelectedCameraID: String? = nil
    
    init(virtualCameraManager: VirtualCameraManager) {
        self.virtualCameraManager = virtualCameraManager
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Ritually Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Configure your profile and camera preferences")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Done") {
                    saveSettings()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 10)
            
            Divider()
            
            // Profile Settings
            VStack(alignment: .leading, spacing: 15) {
                Text("Profile Information")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Enter your name", text: $tempUserName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Job Title")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Enter your job title", text: $tempUserJobTitle)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            Divider()
            
            // Camera Settings
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("Camera Settings")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Refresh Cameras") {
                        virtualCameraManager.discoverAvailableCameras()
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Camera")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if virtualCameraManager.availableCameras.isEmpty {
                        HStack {
                            Image(systemName: "camera.slash")
                                .foregroundColor(.secondary)
                            Text("No cameras detected")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Picker("Select Camera", selection: $tempSelectedCameraID) {
                            Text("No Camera Selected")
                                .tag(nil as String?)
                            
                            ForEach(virtualCameraManager.availableCameras, id: \.uniqueID) { camera in
                                HStack {
                                    Image(systemName: cameraIcon(for: camera))
                                    Text(camera.localizedName)
                                }
                                .tag(camera.uniqueID as String?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                // Camera Info
                if let selectedCameraID = tempSelectedCameraID,
                   let selectedCamera = virtualCameraManager.availableCameras.first(where: { $0.uniqueID == selectedCameraID }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected Camera Info:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("• Name: \(selectedCamera.localizedName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Type: \(deviceTypeDescription(selectedCamera.deviceType))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if selectedCamera.position != .unspecified {
                            Text("• Position: \(positionDescription(selectedCamera.position))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 5)
                }
            }
            
            Spacer()
            
            // Footer info
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                
                Text("Settings are automatically saved")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 450, height: 400)
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentSettings() {
        tempUserName = settings.userName
        tempUserJobTitle = settings.userJobTitle
        
        // Set tempSelectedCameraID to saved camera if it exists and is still available
        if let savedCameraID = settings.selectedCameraID,
           virtualCameraManager.availableCameras.contains(where: { $0.uniqueID == savedCameraID }) {
            tempSelectedCameraID = savedCameraID
        } else {
            // Fall back to first available camera, or nil if none
            tempSelectedCameraID = virtualCameraManager.availableCameras.first?.uniqueID
        }
    }
    
    private func saveSettings() {
        settings.userName = tempUserName
        settings.userJobTitle = tempUserJobTitle
        settings.selectedCameraID = tempSelectedCameraID
        
        // Update the virtual camera manager's selected camera
        if let selectedCameraID = tempSelectedCameraID,
           let selectedCamera = virtualCameraManager.availableCameras.first(where: { $0.uniqueID == selectedCameraID }) {
            virtualCameraManager.selectCamera(selectedCamera)
        }
        
        print("✅ Settings saved - Name: '\(tempUserName)', Job: '\(tempUserJobTitle)', Camera: \(tempSelectedCameraID ?? "none")")
    }
    
    private func cameraIcon(for camera: AVCaptureDevice) -> String {
        switch camera.deviceType {
        case .builtInWideAngleCamera:
            return "camera"
        case .externalUnknown:
            return "camera.aperture"
        case .continuityCamera:
            return "iphone"
        default:
            return "camera.fill"
        }
    }
    
    private func deviceTypeDescription(_ deviceType: AVCaptureDevice.DeviceType) -> String {
        switch deviceType {
        case .builtInWideAngleCamera:
            return "Built-in Camera"
        case .externalUnknown:
            return "External Camera"
        case .continuityCamera:
            return "Continuity Camera"
        default:
            return "Camera"
        }
    }
    
    private func positionDescription(_ position: AVCaptureDevice.Position) -> String {
        switch position {
        case .front:
            return "Front"
        case .back:
            return "Back"
        case .unspecified:
            return "Unspecified"
        @unknown default:
            return "Unknown"
        }
    }
}

#Preview {
    SettingsView(virtualCameraManager: VirtualCameraManager())
}