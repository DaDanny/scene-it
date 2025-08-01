import SwiftUI
import AVFoundation

struct OnboardingFlow: View {
    @State private var currentStep = 0
    @State private var showAnimation = false
    @State private var cameraPermissionGranted = false
    @State private var microphonePermissionGranted = false
    @State private var screenRecordingGranted = false
    
    let onComplete: () -> Void
    
    private var steps: [OnboardingStep] {
        [
            OnboardingStep(
                icon: "camera.fill",
                title: "Camera Access",
                description: "Ritually needs access to your camera to create your virtual presence overlay.",
                actionTitle: cameraPermissionGranted ? "✓ Camera Access Granted" : "Grant Camera Access",
                isPermission: true,
                isGranted: cameraPermissionGranted
            ),
            OnboardingStep(
                icon: "mic.fill",
                title: "Microphone Access",
                description: "Optional: Enable microphone access for audio-reactive mood indicators.",
                actionTitle: microphonePermissionGranted ? "✓ Microphone Access Granted" : "Grant Microphone Access",
                isPermission: true,
                isGranted: microphonePermissionGranted
            ),
            OnboardingStep(
                icon: "desktopcomputer",
                title: "Screen Recording",
                description: "This allows Ritually to capture and overlay your virtual camera feed.",
                actionTitle: screenRecordingGranted ? "✓ Screen Recording Granted" : "Grant Screen Access",
                isPermission: true,
                isGranted: screenRecordingGranted
            ),
            OnboardingStep(
                icon: "video.fill",
                title: "Using Your Virtual Camera",
                description: "In Google Meet, Zoom, or any video app, select 'Ritually Virtual Camera' from your camera dropdown.",
                actionTitle: "Complete Setup",
                isPermission: false,
                isGranted: true
            )
        ]
    }
    
    var body: some View {
        ZStack {
            Color(.controlBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                let step = steps[currentStep]
                
                // Progress indicator
                HStack {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStep ? Color.accentColor : Color(.quaternaryLabelColor))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                        
                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(index < currentStep ? Color.accentColor : Color(.quaternaryLabelColor))
                                .frame(height: 2)
                                .animation(.easeInOut(duration: 0.3), value: currentStep)
                        }
                    }
                }
                .padding(.horizontal, 60)
                .padding(.top, 30)
                
                // Scrollable content area
                ScrollView {
                    VStack(spacing: 30) {
                        // Add top spacing
                        Spacer(minLength: 40)
                        
                        // Icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.accentColor.opacity(0.1),
                                            Color.accentColor.opacity(0.05)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: step.icon)
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                        .scaleEffect(showAnimation ? 1.0 : 0.8)
                        .animation(.easeInOut(duration: 0.6), value: showAnimation)
                        
                        // Content
                        VStack(spacing: 16) {
                            Text(step.title)
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text(step.description)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .opacity(showAnimation ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.8).delay(0.2), value: showAnimation)
                        
                        // Special content for virtual camera step
                        if currentStep == 3 {
                            VStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.controlColor))
                                    .frame(height: 120)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            HStack {
                                                Image(systemName: "video.fill")
                                                    .foregroundColor(.secondary)
                                                Text("Camera")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                Image(systemName: "chevron.down")
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.horizontal, 12)
                                            
                                            Divider()
                                            
                                            VStack(spacing: 4) {
                                                HStack {
                                                    Circle()
                                                        .fill(Color.green)
                                                        .frame(width: 6, height: 6)
                                                    Text("Ritually Virtual Camera")
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(.primary)
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 12)
                                                
                                                HStack {
                                                    Text("FaceTime HD Camera")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 12)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    )
                                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                            }
                            .opacity(showAnimation ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 1.0).delay(0.4), value: showAnimation)
                        }
                        
                        // Add bottom spacing to ensure content doesn't overlap with buttons
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 60)
                }
                
                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                                showAnimation = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showAnimation = true
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.controlColor))
                        )
                    }
                    
                    Spacer()
                    
                    Button(step.actionTitle) {
                        if step.isPermission && !step.isGranted {
                            handlePermissionRequest(for: currentStep)
                        } else {
                            // Move to next step or complete
                            if currentStep < steps.count - 1 {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep += 1
                                    showAnimation = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showAnimation = true
                                }
                            } else {
                                onComplete()
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.accentColor,
                                        Color.accentColor.opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .foregroundColor(.white)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            showAnimation = true
        }
        .onChange(of: currentStep) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showAnimation = true
            }
        }
    }
}

struct OnboardingStep {
    let icon: String
    let title: String
    let description: String
    let actionTitle: String
    let isPermission: Bool
    let isGranted: Bool
}

extension OnboardingFlow {
    private func handlePermissionRequest(for step: Int) {
        switch step {
        case 0: // Camera
            requestCameraPermission()
        case 1: // Microphone
            requestMicrophonePermission()
        case 2: // Screen Recording
            requestScreenRecordingPermission()
        default:
            break
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraPermissionGranted = granted
                if granted {
                    // Auto-advance to next step
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                            showAnimation = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showAnimation = true
                        }
                    }
                }
            }
        }
    }
    
    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                microphonePermissionGranted = granted
                // Auto-advance regardless (microphone is optional)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep += 1
                        showAnimation = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showAnimation = true
                    }
                }
            }
        }
    }
    
    private func requestScreenRecordingPermission() {
        // For screen recording, we can't directly request permission like camera/mic
        // We need to guide user to System Preferences
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Please grant Screen Recording permission in System Preferences > Security & Privacy > Screen Recording"
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Skip")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
        
        // For demo purposes, mark as granted after user interaction
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            screenRecordingGranted = true
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
                showAnimation = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showAnimation = true
            }
        }
    }
}

#Preview {
    OnboardingFlow(onComplete: {
        print("Onboarding completed")
    })
    .frame(width: 600, height: 500)
}