import SwiftUI
import AVFoundation

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var virtualCameraManager: VirtualCameraManager
    @ObservedObject private var statusBarController: StatusBarController
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempUserName: String = ""
    @State private var tempUserJobTitle: String = ""
    @State private var tempSelectedCameraID: String? = nil
    @State private var autoStartOverlays = true
    @State private var showPreview = false
    @State private var availableCameras: [AVCaptureDevice] = []
    
    init(virtualCameraManager: VirtualCameraManager, statusBarController: StatusBarController) {
        self.virtualCameraManager = virtualCameraManager
        self.statusBarController = statusBarController
    }
    
    private var selectedCameraName: String {
        guard let selectedID = tempSelectedCameraID else {
            return "No Camera Selected"
        }
        return availableCameras.first { $0.uniqueID == selectedID }?.localizedName ?? "Unknown Camera"
    }
    
    private func loadSettings() {
        tempUserName = settings.userName
        tempUserJobTitle = settings.userJobTitle
        tempSelectedCameraID = settings.selectedCameraID
        refreshCameras()
    }
    
    private func saveSettings() {
        settings.userName = tempUserName
        settings.userJobTitle = tempUserJobTitle
        settings.selectedCameraID = tempSelectedCameraID
    }
    
    private func refreshCameras() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        availableCameras = discoverySession.devices
    }
    
    var body: some View {
        ZStack {
            backgroundColor
            
            ScrollView {
                mainContent
            }
        }
        .onAppear {
            loadSettings()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveSettings()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var backgroundColor: some View {
        Color(.controlBackgroundColor)
            .ignoresSafeArea()
    }
    
    private var mainContent: some View {
        VStack(spacing: 32) {
            headerSection
            profileSection
            cameraSection
            behaviorSection
            virtualCameraSection
            
            Spacer(minLength: 40)
        }
        .padding(.horizontal, 40)
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Settings")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Customize your Ritually experience")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }
    
    private var profileSection: some View {
        SettingsSection(title: "Profile") {
            VStack(spacing: 20) {
                nameField
                jobTitleField
            }
        }
    }
    
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            TextField("Enter your name", text: $tempUserName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 14))
        }
    }
    
    private var jobTitleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Job Title")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            TextField("Enter your job title", text: $tempUserJobTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 14))
        }
    }
    
    private var cameraSection: some View {
        SettingsSection(title: "Camera") {
            VStack(spacing: 20) {
                cameraSelectionView
                cameraTestButton
            }
        }
    }
    
    private var cameraSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Input Camera")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            Menu {
                ForEach(availableCameras, id: \.uniqueID) { camera in
                    Button(camera.localizedName) {
                        tempSelectedCameraID = camera.uniqueID
                    }
                }
            } label: {
                cameraMenuLabel
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var cameraMenuLabel: some View {
        HStack {
            Image(systemName: "camera.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            
            Text(selectedCameraName)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.up.chevron.down")
                .foregroundColor(.secondary)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.separatorColor), lineWidth: 1)
                )
        )
    }
    
    private var cameraTestButton: some View {
        Button(action: {
            showPreview.toggle()
        }) {
            HStack {
                Image(systemName: "eye.fill")
                    .font(.system(size: 12))
                Text("Test Camera")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var behaviorSection: some View {
        SettingsSection(title: "Behavior") {
            VStack(spacing: 16) {
                autoStartToggle
            }
        }
    }
    
    private var autoStartToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Start overlays automatically")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Enable overlays when virtual camera starts")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $autoStartOverlays)
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        }
    }
    
    private var virtualCameraSection: some View {
        SettingsSection(title: "Virtual Camera") {
            VStack(spacing: 16) {
                virtualCameraStatus
            }
        }
    }
    
    private var virtualCameraStatus: some View {
        HStack {
            statusInfo
            Spacer()
            cameraToggleButton
        }
    }
    
    private var statusInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Status")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            HStack(spacing: 6) {
                Circle()
                    .fill(statusBarController.isVirtualCameraActive ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(statusBarController.isVirtualCameraActive ? "Active" : "Inactive")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var cameraToggleButton: some View {
        Button(statusBarController.isVirtualCameraActive ? "Stop Camera" : "Start Camera") {
            statusBarController.toggleVirtualCamera()
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(cameraButtonBackground)
        .foregroundColor(statusBarController.isVirtualCameraActive ? .red : .white)
        .shadow(color: statusBarController.isVirtualCameraActive ? Color.red.opacity(0.3) : Color.accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    private var cameraButtonBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                statusBarController.isVirtualCameraActive ? 
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.red.opacity(0.1),
                            Color.red.opacity(0.05)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.accentColor,
                            Color.accentColor.opacity(0.8)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
            )
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                content
                    .padding(20)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlColor))
                    .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 2)
            )
        }
    }
}

#Preview {
    // Note: This preview won't work without actual VirtualCameraManager and StatusBarController instances
    Text("Settings Preview")
        .frame(width: 500, height: 600)
}