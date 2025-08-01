# CoreMediaIO Extension Implementation Guide

This is the definitive guide for implementing a native macOS virtual camera for Scene It using Apple's CoreMediaIO Extension Framework.

## Project Goal

Create a professional macOS virtual camera that users can install with a single DMG file and immediately use in any video conferencing application, with zero external dependencies.

## Architecture Overview

### System Design

The implementation uses Apple's modern CoreMediaIO Extension Framework with a dual-component architecture:

```
SceneIt.xcodeproj
├── SceneIt (Main App)                    - User interface, video processing, overlays
└── SceneItCameraExtension (System Ext)   - Virtual camera device provider
```

### Core Technologies

- **CoreMediaIO Extension Framework** (macOS 14+) - Native virtual camera support
- **SystemExtensions Framework** - Automatic extension installation and management
- **XPC Services** - Secure inter-process communication between app and extension
- **AVFoundation** - Video capture and processing (existing implementation)
- **CoreImage** - GPU-accelerated overlay effects (existing implementation)

### Data Flow

```
Physical Camera → AVFoundation → Core Image → Overlays → XPC → System Extension → macOS Camera System → Video Apps
```

## Current Status

### ✅ Implemented
- **Core Image Processing Pipeline**: Full overlay system with 4 overlay types
- **AVFoundation Integration**: Camera capture, switching, and preview
- **Status Bar Interface**: Menu bar controls and settings
- **SwiftUI Architecture**: Modern menu bar app with VideoPreviewWindow
- **Error Handling**: Comprehensive error management and logging
- **Splash Screen System**: Fallback content when app inactive

### 🔄 Partial Implementation (CMIOExtension Directory)
- **SceneItCMIOProvider.swift**: Basic provider structure with device/stream creation, sendFrame() method present but needs XPC integration
- **SceneItCMIOExtension.swift**: More complete CMIOExtension subclass with property handling, stream management, frame delivery methods
- **CMIOExtensionIPC.swift**: Bridge class connecting to provider, basic frame sending capability but needs proper XPC implementation
- **CMIOExtensionTypes.swift**: Placeholder type definitions awaiting proper CoreMediaIO framework linking

### 🚨 Critical Missing Components
- **System Extension Target**: No Xcode system extension target configured
- **XPC Communication**: Current IPC uses provider directly, needs proper XPC for security
- **Proper CMIOExtension Framework**: Using placeholder types instead of real framework classes
- **Extension Installation**: No SystemExtensions framework integration for automatic installation

### ❌ Removed Placeholders
- **SimpleVirtualCamera**: UserDefaults-based registration (non-functional)
- **VirtualCameraIPC**: Shared memory placeholder (to be replaced with XPC)

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)

#### 1.1 Project Structure Setup
- [ ] **Add System Extension Target**
  - Create new macOS System Extension target: "SceneItCameraExtension" 
  - Set minimum deployment: macOS 14.0
  - Configure bundle identifiers:
    - Main App: `com.ritually.SceneIt`
    - Extension: `com.ritually.SceneIt.CameraExtension`

#### 1.2 Critical Architecture Note
⚠️ **The current implementation has existing classes that need to be properly integrated**:
- `SceneItCMIOProvider.swift` - Has working structure but needs XPC
- `SceneItCMIOExtension.swift` - More complete implementation 
- `CMIOExtensionIPC.swift` - Bridge that bypasses proper XPC security
- Current VirtualCameraManager has video processing pipeline but needs virtual camera output

#### 1.3 Extension Configuration
- [ ] **Create Extension Info.plist**
  ```xml
  <key>NSExtension</key>
  <dict>
      <key>NSExtensionPointIdentifier</key>
      <string>com.apple.cmio-dal-assistant.extension</string>
      <key>NSExtensionPrincipalClass</key>
      <string>SceneItCMIOExtensionProvider</string>
  </dict>
  ```

- [ ] **Configure Extension Entitlements**
  ```xml
  <key>com.apple.developer.cmio.extension</key>
  <true/>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  ```

#### 1.4 Fix Current Implementation Issues
- [x] **Remove SimpleVirtualCamera.swift** - Non-functional placeholder
- [ ] **Replace CMIOExtensionTypes.swift placeholders** - Link proper CoreMediaIO framework
- [ ] **Convert CMIOExtensionIPC.swift to proper XPC** - Current direct provider access needs XPC security
- [ ] **Update VirtualCameraManager.swift** - Integrate with new XPC communication layer

#### 1.5 Refactor Existing Extension Files
- [ ] **Move existing files to System Extension target**
  - Move `SceneItCMIOProvider.swift` to extension target
  - Move `SceneItCMIOExtension.swift` to extension target  
  - Update imports and framework references
  - Remove placeholder `CMIOExtensionTypes.swift`

- [ ] **Create proper CMIOExtension main class**
  ```swift
  import CoreMediaIO
  
  @main
  class SceneItCMIOExtensionMain {
      static func main() {
          let provider = SceneItCMIOProvider.providerSource
          CMIOExtensionProvider.startService(provider: provider)
      }
  }
  ```

### Phase 2: Core Functionality (Week 3-4)

#### 2.1 XPC Communication Setup
- [ ] **Create XPC Protocol**
  ```swift
  @objc protocol SceneItXPCProtocol {
      func sendVideoFrame(data: Data, width: Int, height: Int, completion: @escaping (Bool) -> Void)
      func updateStreamState(isActive: Bool)
      func sendSplashScreen(imageData: Data)
  }
  ```

- [ ] **Implement XPC Client (Main App)**
  ```swift
  class XPCFrameTransmitter {
      private var connection: NSXPCConnection?
      
      func sendFrame(_ pixelBuffer: CVPixelBuffer) {
          // Convert CVPixelBuffer to Data
          // Send via XPC to extension
          // Handle transmission errors
      }
  }
  ```

- [ ] **Implement XPC Service (Extension)**
  ```swift
  class XPCFrameReceiver: NSObject, SceneItXPCProtocol {
      func sendVideoFrame(data: Data, width: Int, height: Int, completion: @escaping (Bool) -> Void) {
          // Convert Data back to CVPixelBuffer
          // Feed to CMIO stream
          completion(true)
      }
  }
  ```

#### 2.2 Virtual Camera Device Registration
- [ ] **Configure Device Properties**
  - Device Name: "Ritually Virtual Camera"
  - Manufacturer: "Ritually"  
  - Model: "Virtual Camera v2.0"
  - Supported Formats: 1080p@30fps, 720p@30fps, 1080p@60fps
  - Pixel Format: kCVPixelFormatType_32BGRA

- [ ] **Implement Device Discovery**
  ```swift
  override func availableStreamConfigurations() -> [CMIOExtensionStreamConfiguration] {
      return [
          CMIOExtensionStreamConfiguration(
              width: 1920, height: 1080, 
              pixelFormat: kCVPixelFormatType_32BGRA,
              frameRate: 30
          ),
          CMIOExtensionStreamConfiguration(
              width: 1280, height: 720,
              pixelFormat: kCVPixelFormatType_32BGRA, 
              frameRate: 30
          )
      ]
  }
  ```

#### 2.3 Frame Processing Pipeline Integration
- [ ] **Update VirtualCameraManager**
  ```swift
  class VirtualCameraManager {
      private var xpcTransmitter: XPCFrameTransmitter?
      
      private func sendToVirtualCamera(pixelBuffer: CVPixelBuffer, originalSampleBuffer: CMSampleBuffer) {
          xpcTransmitter?.sendFrame(pixelBuffer)
      }
  }
  ```

#### 2.4 Overlay System Enhancement (Building on Existing System)
- [ ] **Enhance Current Overlay Collection** (Currently has 4 overlay types)
  - Review and polish existing overlay designs for professional appearance
  - Add 2-3 additional business-focused overlays if needed
  - Ensure high-resolution overlay assets for crisp display
  
- [ ] **Integrate Overlay Selection in Status Bar Menu** (StatusBarMenuView exists)
  ```swift
  extension StatusBarMenuView {
      private var overlaySelectionMenu: some View {
          Menu("Overlay") {
              ForEach(OverlayType.allCases) { overlayType in
                  Button(overlayType.displayName) {
                      settingsManager.currentOverlay = overlayType
                  }
              }
              Divider()
              Button("No Overlay") {
                  settingsManager.currentOverlay = .none
              }
          }
      }
  }
  ```
  
- [ ] **Overlay Live Preview Integration** (VideoPreviewWindow exists)
  - Ensure VideoPreviewWindow shows overlays in real-time
  - Add overlay change animations for smooth transitions
  - Implement overlay hot-swapping without camera interruption

### Phase 3: System Integration (Week 5-6)

#### 3.1 Extension Installation Management
- [ ] **Create CMIOExtensionInstaller.swift**
  ```swift
  import SystemExtensions
  
  class CMIOExtensionInstaller: NSObject, OSSystemExtensionRequestDelegate {
      func installExtension() {
          let request = OSSystemExtensionRequest.activationRequest(
              forExtensionWithIdentifier: "com.ritually.SceneIt.CameraExtension",
              queue: .main
          )
          request.delegate = self
          OSSystemExtensionManager.shared.submitRequest(request)
      }
      
      func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
          // Handle successful installation
      }
      
      func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
          // Handle installation failure with user guidance
      }
  }
  ```

#### 3.2 User Experience Flow
- [ ] **Implement Installation UI**
  - Guided system extension approval process
  - Clear instructions for Security & Privacy settings
  - Retry mechanisms for failed approvals
  - User-friendly error messages and troubleshooting

- [ ] **Permission Management**
  - Maintain existing camera permission flow
  - Handle system extension approval requirements
  - Graceful error recovery and user guidance

#### 3.3 Error Handling & Recovery
- [ ] **XPC Communication Error Handling**
  - Automatic reconnection logic for dropped connections
  - Fallback strategies for communication failures
  - Real-time status monitoring and user feedback

- [ ] **Extension Lifecycle Management**
  - Handle extension crashes and restarts
  - Monitor extension health and performance
  - Provide diagnostics and troubleshooting information

### Phase 4: Performance Optimization (Week 7-8)

#### 4.1 Frame Processing Optimization
- [ ] **Memory Management**
  ```swift
  class FrameBufferPool {
      private var availableBuffers: [CVPixelBuffer] = []
      
      func getBuffer(width: Int, height: Int) -> CVPixelBuffer? {
          // Implement object pooling for CVPixelBuffers
          // Minimize allocations in video pipeline
      }
      
      func returnBuffer(_ buffer: CVPixelBuffer) {
          // Return buffer to pool for reuse
      }
  }
  ```

- [ ] **XPC Optimization**
  - Efficient frame serialization strategies
  - Shared memory for high-frequency data transfer
  - Minimize IPC overhead and latency

#### 4.2 User Experience Polish
- [ ] **Performance Monitoring**
  - Real-time frame rate monitoring
  - Memory usage tracking and limits
  - Extension status and health indicators

- [ ] **Splash Screen Integration**
  - Seamless fallback when app inactive
  - Smooth state transitions
  - Professional branding and messaging

### Phase 5: Distribution (Week 9-10)

#### 5.1 Code Signing & Notarization
- [ ] **Development Signing Setup**
  - Configure provisioning profiles for both app and extension
  - Test with development certificates
  - Validate entitlements and permissions

- [ ] **Distribution Preparation**
  ```bash
  # Sign the main application
  codesign --sign "Developer ID Application: Your Name" SceneIt.app
  
  # Sign the system extension
  codesign --sign "Developer ID Application: Your Name" \
    SceneIt.app/Contents/PlugIns/SceneItCameraExtension.appex
  
  # Create installer package
  productbuild --component SceneIt.app /Applications SceneIt-Installer.pkg
  
  # Notarize for Gatekeeper
  xcrun notarytool submit SceneIt-Installer.pkg --wait
  ```

#### 5.2 Professional Installation Package
- [ ] **DMG Creation**
  - Professional installer background and branding
  - Clear drag-to-Applications instructions
  - Include app icon and visual guidelines

- [ ] **Installation Testing**
  - Test on clean macOS 14+ systems
  - Verify installation success rates
  - Test uninstallation and cleanup process

#### 5.3 Compatibility Validation
- [ ] **Video Application Testing**
  - Zoom (desktop and web versions)
  - Google Meet (Chrome, Safari, Edge)
  - Microsoft Teams
  - FaceTime
  - Discord
  - Slack
  - Any app using AVFoundation camera discovery

- [ ] **Performance Validation**
  - Maintain 30fps minimum across all apps
  - Memory usage under 100MB during operation
  - Stability during extended video calls
  - Proper cleanup on app termination
  - Test real-time preview window functionality
  - Verify overlay switching without interruption

## Success Criteria

### Technical Requirements
- ✅ Virtual camera appears in system-wide camera list
- ✅ Works seamlessly in all major video conferencing applications  
- ✅ Maintains stable 30fps performance with overlay processing
- ✅ Memory usage stays under 100MB during active operation
- ✅ Proper camera switching without application crashes
- ✅ Clean extension installation and uninstallation

### User Experience Requirements
- ✅ Single DMG installation with standard drag-to-Applications
- ✅ Automatic system extension installation and approval guidance
- ✅ Zero configuration required after successful installation
- ✅ Professional appearance and branding throughout
- ✅ Clear error messages and troubleshooting guidance
- ✅ Works immediately in existing video calls
- ✅ **Real-time Video Preview**: Users can see exactly what others will see before joining calls
- ✅ **Instant Overlay Changes**: Live preview updates when switching overlays

### Overlay System Requirements
- ✅ **Modern Overlay System**: Professional overlays visible to meeting participants
- ✅ **3-4 Preset Overlays**: Pre-designed overlay options for easy selection
- ✅ **Easy Selection Interface**: Quick overlay switching from status bar menu
- ✅ **Easy Updates**: Simple overlay replacement and management system
- ✅ **Real-time Application**: Overlays applied to live video feed without lag
- ✅ **Professional Quality**: High-resolution overlays that enhance professional appearance

### Distribution Requirements
- ✅ Properly signed and notarized for macOS Gatekeeper
- ✅ Compatible with macOS 14.0 and later versions
- ✅ Installation success rate exceeds 95%
- ✅ Professional installer package and user documentation

## Final File Structure

```
SceneIt.xcodeproj
├── SceneIt/                                    # Main Application
│   ├── App.swift                               # SwiftUI app entry point
│   ├── VirtualCameraManager.swift              # Video processing (updated)
│   ├── CMIOExtensionInstaller.swift            # System extension management
│   ├── XPCFrameTransmitter.swift               # Communication with extension
│   ├── StatusBarController.swift               # Menu bar interface
│   ├── Models/
│   │   ├── AppSettings.swift                   # User preferences
│   │   └── Overlay.swift                       # Overlay definitions
│   ├── Views/
│   │   ├── StatusBarMenuView.swift             # SwiftUI menu
│   │   ├── VideoPreviewWindow.swift            # Camera preview
│   │   └── SettingsView.swift                  # Configuration interface
│   └── Resources/
│       ├── Assets.xcassets/                    # App icons and assets
│       ├── Info.plist                          # App configuration
│       └── SceneIt.entitlements                # App permissions
└── SceneItCameraExtension/                     # System Extension
    ├── SceneItCMIOExtensionProvider.swift      # Main extension provider
    ├── SceneItCMIODevice.swift                 # Virtual camera device
    ├── SceneItCMIOStream.swift                 # Video stream management
    ├── XPCFrameReceiver.swift                  # Receive frames from main app
    ├── Info.plist                              # Extension configuration
    └── SceneItCameraExtension.entitlements     # Extension permissions
```

## Key User Experience Flow

### Installation Experience
1. **Download**: User downloads single DMG file
2. **Install**: Drag SceneIt.app to Applications folder
3. **Launch**: Double-click to launch - status bar icon appears
4. **Extension Setup**: First launch triggers system extension installation with guided approval
5. **Camera Permission**: Standard macOS camera permission request
6. **Ready**: Virtual camera appears in all video applications

### Daily Usage Flow  
1. **Launch App**: SceneIt starts and shows status bar icon
2. **Preview Video**: Click status bar → "Show Preview" to see live camera feed with overlays
3. **Select Overlay**: Click status bar → Choose from overlay options in real-time
4. **Join Meeting**: Open Zoom/Meet/Teams and select "Ritually Virtual Camera" from camera list
5. **Professional Video**: Participants see user with chosen overlay applied

### Critical Success Factors
- **Real-time Preview**: Users MUST see exactly what others will see before joining calls
- **Instant Overlay Switching**: Changes must be visible immediately in preview window
- **Zero Latency**: No delay between physical camera and virtual camera output
- **Universal Compatibility**: Must work in ALL major video conferencing applications
- **Professional Quality**: Overlay rendering must be crisp and properly aligned

## Key Advantages of This Implementation

### Technical Benefits
- **Native Performance**: Uses Apple's optimized CoreMediaIO framework
- **Security**: Sandboxed system extension with proper entitlements
- **Reliability**: Built-in system integration and automatic discovery
- **Future-Proof**: Uses modern Apple frameworks, not deprecated APIs

### User Benefits  
- **Zero Dependencies**: No external software installation required
- **Seamless Integration**: Appears as native camera in all applications
- **Professional Experience**: Single DMG → drag to Applications → works immediately
- **Real-time Preview**: See exactly what meeting participants will see
- **Instant Overlay Changes**: Live feedback when switching overlays

### Developer Benefits
- **Maintainable**: Pure Swift implementation with clear separation of concerns
- **Debuggable**: Standard Xcode debugging and profiling tools work
- **Distributable**: Standard code signing and notarization process
- **Extensible**: Clean architecture for future feature additions

This implementation provides a professional, native macOS virtual camera experience that users can install and use immediately without external dependencies or complex configuration.