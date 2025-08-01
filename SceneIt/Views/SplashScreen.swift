import SwiftUI

class SplashScreenController: ObservableObject {
    @Published var isLoading = false
    @Published var loadingProgress = 0.0
    @Published var loadingMessage = "Starting Ritually..."
    
    private let loadingSteps = [
        "Starting Ritually...",
        "Checking permissions...",
        "Setting up virtual camera...",
        "Loading overlays...",
        "Ready to go!"
    ]
    
    func startLoadingSequence(completion: @escaping () -> Void) {
        isLoading = true
        loadingProgress = 0.0
        
        let stepDuration = 0.8
        let totalSteps = loadingSteps.count
        
        for (index, message) in loadingSteps.enumerated() {
            let delay = Double(index) * stepDuration
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.loadingMessage = message
                    self.loadingProgress = Double(index + 1) / Double(totalSteps)
                }
                
                // Complete on last step
                if index == totalSteps - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration) {
                        completion()
                    }
                }
            }
        }
    }
}

struct SplashScreen: View {
    @StateObject private var controller = SplashScreenController()
    @State private var opacity = 0.0
    @State private var scale = 0.8
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.controlBackgroundColor),
                    Color(.controlBackgroundColor).opacity(0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // App icon with logo
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.accentColor,
                                    Color.accentColor.opacity(0.7)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .scaleEffect(scale)
                    
                    // Simple icon representation
                    Image(systemName: "video.circle.fill")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.white)
                        .scaleEffect(scale)
                }
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: scale)
                
                VStack(spacing: 16) {
                    // App name
                    Text("Ritually")
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .foregroundColor(.primary)
                        .opacity(opacity)
                    
                    // Tagline
                    Text("Your meetings, with presence.")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                        .opacity(opacity)
                }
                
                Spacer()
                
                // Loading section
                if controller.isLoading {
                    VStack(spacing: 16) {
                        // Progress bar
                        ProgressView(value: controller.loadingProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                            .frame(width: 200)
                            .opacity(opacity)
                        
                        // Loading message
                        Text(controller.loadingMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .opacity(opacity)
                            .animation(.easeInOut(duration: 0.3), value: controller.loadingMessage)
                    }
                }
                
                Spacer().frame(height: 60)
            }
            .padding(40)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                opacity = 1.0
                scale = 1.05
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                controller.startLoadingSequence {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        opacity = 0.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onComplete()
                    }
                }
            }
        }
    }
}

#Preview {
    SplashScreen(onComplete: {
        print("Splash screen completed")
    })
    .frame(width: 500, height: 400)
}