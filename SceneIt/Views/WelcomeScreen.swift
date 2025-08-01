import SwiftUI

struct WelcomeScreen: View {
    @State private var showAnimation = false
    @ObservedObject private var settings = AppSettings.shared
    let onGetStarted: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Color(.controlBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header section
                VStack(spacing: 24) {
                    // App icon
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.accentColor,
                                    Color.accentColor.opacity(0.8)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .scaleEffect(showAnimation ? 1.0 : 0.8)
                        .animation(.easeInOut(duration: 0.6), value: showAnimation)
                    
                    VStack(spacing: 12) {
                        Text("Welcome to Ritually")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Transform your daily meetings with mindful presence")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Preview section
                VStack(spacing: 20) {
                    Text("See your overlays in action")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    // Mock overlay preview with user's actual name if available
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.controlColor))
                        .frame(width: 300, height: 180)
                        .overlay(
                            VStack {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(settings.userName.isEmpty ? "Your Name" : settings.userName)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                        Text(settings.userJobTitle.isEmpty ? "Your Job Title" : settings.userJobTitle)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 10)
                                
                                Spacer()
                                
                                HStack {
                                    Spacer()
                                    VStack(spacing: 2) {
                                        Text("😊")
                                            .font(.system(size: 16))
                                        Text("Focused")
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.controlBackgroundColor).opacity(0.8))
                                    )
                                }
                                .padding(.horizontal, 12)
                                .padding(.bottom, 10)
                            }
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .scaleEffect(showAnimation ? 1.0 : 0.9)
                        .animation(.easeInOut(duration: 0.8).delay(0.2), value: showAnimation)
                }
                
                Spacer()
                
                // CTA section
                VStack(spacing: 16) {
                    Button(action: onGetStarted) {
                        HStack {
                            Text("Get Started")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
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
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .scaleEffect(showAnimation ? 1.0 : 0.95)
                    .animation(.easeInOut(duration: 1.0).delay(0.4), value: showAnimation)
                    
                    Text("Takes less than 2 minutes to set up")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 60)
        }
        .onAppear {
            showAnimation = true
        }
    }
}

#Preview {
    WelcomeScreen(onGetStarted: {
        print("Get Started tapped")
    })
    .frame(width: 600, height: 500)
}