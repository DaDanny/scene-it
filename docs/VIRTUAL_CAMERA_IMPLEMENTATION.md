# Native Virtual Camera Implementation Guide

This document provides comprehensive guidance on implementing a native macOS virtual camera for Scene It using modern CoreMediaIO frameworks.

## Current Status

✅ **Core Image Processing Pipeline**: Fully implemented with overlay support  
✅ **Splash Screen System**: Complete fallback screen for inactive states  
✅ **Error Handling**: Robust error management and logging  
✅ **AVFoundation Integration**: Real camera capture and frame processing  
🔄 **Virtual Camera Output**: Framework ready, native backend implementation needed  

## Implementation Strategy: Native CoreMediaIO Extension

**Goal**: Provide a seamless, native macOS experience where users can install a single DMG and immediately use the virtual camera in any video conferencing app.

**Approach**: Modern CoreMediaIO System Extension using Apple's latest APIs and frameworks.

### Why Native Implementation?

**Pros**: 
- ✅ Zero external dependencies - single app installation
- ✅ Native macOS integration and performance
- ✅ Automatic system registration and discovery
- ✅ Code signing and notarization support
- ✅ Mac App Store compatibility potential
- ✅ Professional user experience

**Cons**: 
- ⚠️ More complex initial implementation
- ⚠️ Requires System Extension approval process

### Modern Architecture: System Extension + Main App

The native implementation consists of two coordinated components:

```
SceneIt.xcodeproj
├── SceneIt (Main App)                    - User interface, video processing, overlays
└── SceneItCameraExtension (System Ext)   - Virtual camera device provider
```

#### **1. Main App (SceneIt)**
- **Purpose**: User interface, camera capture, overlay processing
- **Framework**: SwiftUI + AVFoundation + CoreImage  
- **Role**: Process real camera → Apply overlays → Send to System Extension

#### **2. System Extension (SceneItCameraExtension)**
- **Purpose**: Provide virtual camera device to macOS
- **Framework**: CoreMediaIO Extension Framework
- **Role**: Receive processed frames → Present as camera device → Appear in video apps

#### **3. Communication Bridge**
- **Method**: XPC (inter-process communication) + Shared Memory
- **Data Flow**: Main App → [XPC/Memory] → System Extension → macOS Camera System

### Implementation Using Modern Apple Frameworks

#### **Core Technologies**:
- **CoreMediaIO Extension Framework** (iOS 17+/macOS 14+)
- **SystemExtensions Framework** for installation
- **XPC Services** for secure communication
- **AVFoundation** for video processing
- **CoreImage** for GPU-accelerated effects

#### **Key Files Structure**:
```
SceneIt/
├── SceneIt/                          # Main App
│   ├── VirtualCameraManager.swift    # Video processing (existing)
│   ├── CMIOExtensionInstaller.swift  # System extension management
│   └── XPCCommunicator.swift        # Communication with extension
└── SceneItCameraExtension/           # System Extension Target
    ├── CMIOExtensionProvider.swift   # Main extension provider
    ├── CMIOExtensionDevice.swift     # Virtual camera device
    ├── CMIOExtensionStream.swift     # Video stream management
    └── Info.plist                    # Extension configuration
```

## Integration with Scene It

### Current VirtualCameraManager Integration Points

The `VirtualCameraManager.swift` is designed to work with any backend:

```swift
// Key integration methods:
func sendToVirtualCamera(pixelBuffer: CVPixelBuffer, originalSampleBuffer: CMSampleBuffer)
func outputSplashScreen()
func getSplashScreenImage() -> CIImage?
```

### Implementation Steps

1. **Choose Backend** (recommend OBS for initial version)
2. **Create Backend Class**:
   ```swift
   protocol VirtualCameraBackend {
       func initialize() -> Bool
       func sendFrame(_ pixelBuffer: CVPixelBuffer)
       func sendSplashScreen(_ image: CIImage)
       func cleanup()
   }
   ```

3. **Update VirtualCameraManager**:
   ```swift
   class VirtualCameraManager {
       private var backend: VirtualCameraBackend?
       
       private func sendToVirtualCamera(pixelBuffer: CVPixelBuffer, originalSampleBuffer: CMSampleBuffer) {
           backend?.sendFrame(pixelBuffer)
       }
   }
   ```

## Testing and Validation

### Test Applications
- **Zoom**: Most common video conferencing app
- **Google Meet**: Web-based testing
- **QuickTime Player**: Simple camera selection test
- **FaceTime**: Native macOS camera app

### Validation Checklist
- [ ] Virtual camera appears in camera selection menus
- [ ] Overlays render correctly in video calls
- [ ] Splash screen shows when app is inactive
- [ ] Performance maintains 30fps minimum
- [ ] No memory leaks during long sessions
- [ ] Graceful handling of camera switching

## Performance Optimization

### Core Image Optimization
```swift
// Use GPU-accelerated processing
private let ciContext = CIContext(options: [
    .useSoftwareRenderer: false,
    .cacheIntermediates: false
])

// Reuse pixel buffers
private var pixelBufferPool: CVPixelBufferPool?
```

### Memory Management
```swift
// Implement object pooling for frequent allocations
private let frameQueue = DispatchQueue(label: "frames", qos: .userInteractive)
private var reusablePixelBuffers: [CVPixelBuffer] = []
```

## Deployment Considerations

### Code Signing Requirements
```bash
# Sign the main app
codesign --sign "Developer ID Application: Your Name" SceneIt.app

# Sign DAL plugin (if using custom plugin)
codesign --sign "Developer ID Application: Your Name" SceneItVirtualCamera.plugin
```

### System Integration
```swift
// Request necessary permissions
private func requestSystemPermissions() {
    // Camera access (already implemented)
    AVCaptureDevice.requestAccess(for: .video) { _ in }
    
    // Screen recording (if using screen capture approach)
    CGRequestScreenCaptureAccess()
}
```

### Distribution Options
1. **Mac App Store**: Requires sandboxing, limited system access
2. **Direct Distribution**: Full system access, requires notarization
3. **Developer Distribution**: Testing and beta versions

## Next Steps

### Immediate (Phase 1)
1. **Implement OBS Backend**: Fastest path to working virtual camera
2. **Basic Testing**: Verify core functionality works
3. **User Documentation**: Setup instructions for OBS requirement

### Medium Term (Phase 2)
1. **Custom DAL Plugin**: Remove OBS dependency
2. **Performance Optimization**: GPU acceleration, memory management
3. **Advanced Overlays**: Animation support, dynamic content

### Long Term (Phase 3)
1. **Background Processing**: Virtual camera works without main app
2. **System Service**: Automatic startup, system integration
3. **Plugin Architecture**: Third-party overlay support

## Resources

### Apple Documentation
- [Core Media I/O Programming Guide](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/WorkingWAudioVideoDevices/WorkingWithAudioVideoDevices.html)
- [AVFoundation Programming Guide](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/00_Introduction.html)

### Sample Code
- [Apple's LoopbackCameraSample](https://developer.apple.com/documentation/coremediaio/creating_a_camera_extension_with_core_media_i_o) - Official DAL plugin example
- [OBS Studio Virtual Camera Source](https://github.com/obsproject/obs-studio) - Reference implementation

### Third-Party Solutions
- [CameraAssistant](https://github.com/gre4ixin/CameraAssistant) - Open source virtual camera
- [mmhmm Virtual Camera](https://www.mmhmm.app/) - Commercial reference

## Troubleshooting

### Common Issues

**Virtual camera not appearing in apps**:
- Verify DAL plugin is properly installed
- Check system permissions
- Restart video conferencing apps

**Performance issues**:
- Profile Core Image operations
- Check for memory leaks
- Optimize pixel buffer management

**Overlay rendering problems**:
- Verify Core Image filter compatibility
- Check coordinate system transformations
- Test with different video resolutions

### Debug Tools
```swift
// Enable Core Image debugging
UserDefaults.standard.set(true, forKey: "CI_PRINT_TREE")

// Profile frame processing time
let startTime = CFAbsoluteTimeGetCurrent()
processVideoFrame(sampleBuffer)
let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
print("Frame processing time: \(timeElapsed * 1000)ms")
```

## Contact and Support

For implementation questions or collaboration:
- Review the Scene It codebase for integration patterns
- Test with simple overlay configurations first
- Consider starting with OBS backend for rapid prototyping