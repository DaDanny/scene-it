# Scene It Virtual Camera - DAL Plugin Setup

This document provides complete setup instructions for the Scene It virtual camera with its custom CoreMediaIO DAL plugin.

## 🏗️ **Project Architecture**

### **Swift App Components**
```
SceneIt/
├── main.swift                      # App entry point
├── AppDelegate.swift               # App lifecycle and setup
├── StatusBarController.swift       # Menu bar interface
├── VirtualCameraManager.swift      # Camera capture and processing
├── Models/
│   └── Overlay.swift              # Overlay system
├── Views/
│   ├── StatusBarMenuView.swift    # SwiftUI menu components
│   └── VideoPreviewWindow.swift   # Live preview window
├── IPC/
│   └── VirtualCameraIPC.swift     # Plugin communication bridge
└── Resources/                     # Assets and configuration
```

### **DAL Plugin Components**
```
SceneItVirtualCamera.plugin/
├── Contents/
│   ├── Info.plist                # Plugin metadata
│   ├── MacOS/
│   │   └── SceneItVirtualCamera   # Compiled plugin binary
│   └── Resources/
│       ├── SceneItVirtualCamera.h # Plugin interface
│       ├── SceneItVirtualCamera.cpp # Plugin implementation
│       └── Makefile              # Build system
```

## 🚀 **Setup Process**

### **Step 1: Build the Swift App**

1. **Open Project**: Launch `SceneIt.xcodeproj` in Xcode
2. **Configure Signing**: Set your development team in project settings
3. **Build & Run**: Press `Cmd + R`

The app will show a debug window and create a status bar icon with virtual camera controls.

### **Step 2: Build the DAL Plugin**

#### **Option A: Using Build Script (Recommended)**
```bash
cd /path/to/scene-it
./SceneIt/Build/build_plugin.sh
```

#### **Option B: Manual Build**
```bash
cd SceneItVirtualCamera.plugin/Contents/Resources
make clean
make
make install
```

### **Step 3: Verify Installation**

1. **Check Plugin Location**: 
   ```bash
   ls ~/Library/CoreMediaIO/Plug-Ins/DAL/
   # Should show: SceneItVirtualCamera.plugin
   ```

2. **Test in Scene It App**:
   - Click the camera icon in menu bar
   - Status should show "Plugin: Connected"
   - Start virtual camera
   - Use "Show Preview" to see live feed

3. **Test in Video Apps**:
   - Open QuickTime Player → New Movie Recording
   - Click camera dropdown → Look for "Scene It Virtual Camera"
   - Test in Zoom, Google Meet, etc.

## 🎯 **Usage Instructions**

### **Status Bar Controls**
- **Start/Stop Virtual Camera**: Toggle camera functionality
- **Show/Hide Preview**: Live video preview window
- **Select Overlay**: Choose from 4 built-in overlays
- **Plugin Status**: Shows connection to DAL plugin
- **Install Plugin**: One-click plugin installation

### **Preview Window Features**
- **Live Video Feed**: Real-time camera with overlays
- **Resolution Display**: Shows current video dimensions
- **Frame Rate**: Live FPS counter
- **Quick Controls**: Start/stop camera, launch QuickTime

### **Available Overlays**
1. **Professional Frame**: Clean border for business meetings
2. **Casual Border**: Colorful gradient for informal calls
3. **Minimalist**: Subtle corner indicators
4. **Branded**: Logo area with Scene It branding

## 🔧 **Technical Details**

### **IPC Communication**
- **Shared Memory**: Ring buffer for high-performance frame transfer
- **Synchronization**: POSIX semaphores for thread safety
- **Format**: RGBA32 pixel buffers up to 1920×1080
- **Performance**: 30 FPS with GPU-accelerated processing

### **Plugin Architecture**
- **CoreMediaIO DAL Plugin**: Native virtual camera device
- **Property Management**: Handles device/stream properties
- **Frame Delivery**: Async frame processing pipeline
- **Fallback Support**: Static splash screen when app inactive

### **Video Processing Pipeline**
```
Camera Input → AVCaptureSession → Core Image → Overlay Compositing → IPC → DAL Plugin → Virtual Camera Output
```

## 🛠️ **Troubleshooting**

### **Common Issues**

#### **Plugin Not Appearing in Video Apps**
1. **Restart Applications**: Close and reopen video conferencing apps
2. **Check Installation**: Verify plugin in `~/Library/CoreMediaIO/Plug-Ins/DAL/`
3. **Check Permissions**: Ensure camera access granted in System Preferences
4. **Rebuild Plugin**: Try `make clean && make && make install`

#### **"Plugin: Disconnected" Status**
1. **Build Plugin**: Plugin must be built and installed first
2. **Check Console**: Look for IPC initialization errors
3. **Restart Scene It**: Close and reopen the app
4. **Check Dependencies**: Ensure all frameworks available

#### **Poor Performance**
1. **Check GPU Acceleration**: Core Image should use GPU
2. **Monitor Frame Rate**: Use preview window FPS counter
3. **Reduce Resolution**: Try 720p if 1080p is slow
4. **Close Other Apps**: Free up camera resources

#### **Video Not Updating**
1. **Check IPC Status**: Use debug info in console
2. **Verify Overlay Processing**: Test without overlays
3. **Check Camera Permissions**: Ensure full access granted
4. **Restart Camera**: Stop and start virtual camera

### **Debug Information**

#### **Console Logs to Watch**
```
✅ IPC bridge initialized
✅ Virtual camera plugin connected  
✅ Status bar image set: video.circle
Virtual camera started successfully
Processed frame with overlay: [overlay name]
```

#### **IPC Buffer Status**
The app monitors buffer usage:
- `writeIndex`: Current write position
- `readIndex`: Plugin read position  
- `frameCount`: Frames pending processing

#### **Performance Monitoring**
- **Frame Rate**: Real-time FPS display
- **Buffer Status**: IPC communication health
- **Plugin Connection**: DAL plugin availability

### **Reinstallation**

#### **Complete Reset**
```bash
# Remove plugin
make -C SceneItVirtualCamera.plugin/Contents/Resources uninstall

# Clean build
make -C SceneItVirtualCamera.plugin/Contents/Resources clean

# Rebuild and reinstall
./SceneIt/Build/build_plugin.sh
```

#### **Reset Shared Memory**
```bash
# If IPC gets stuck, restart Scene It app
# Shared memory is automatically cleaned up
```

## 🔒 **Code Signing & Distribution**

### **Development Setup**
- Plugin builds with automatic code signing
- Uses developer certificate for local testing
- No special entitlements required for development

### **Production Distribution**
- Requires Apple Developer ID for distribution
- Plugin must be notarized for public release
- App must be notarized if distributed outside App Store

### **Signing Commands**
```bash
# Sign plugin (replace with your certificate)
codesign --sign "Developer ID Application: Your Name" SceneItVirtualCamera.plugin

# Sign app bundle
codesign --sign "Developer ID Application: Your Name" SceneIt.app
```

## 📝 **Development Notes**

### **Adding New Overlays**
1. Add overlay definition to `OverlayManager`
2. Implement rendering in `createOverlayImage()` 
3. Test in preview window
4. No plugin changes needed

### **IPC Protocol Extensions**
- Shared memory structure is versioned
- Maintain backward compatibility
- Plugin and app must use matching protocols

### **Performance Optimization**
- Use GPU acceleration (Core Image/Metal)
- Implement frame pooling for memory efficiency
- Consider compression for large frames

## 🎉 **Success Criteria**

You'll know everything is working when:

✅ **Scene It shows "Plugin: Connected"**  
✅ **Preview window displays live video with overlays**  
✅ **"Scene It Virtual Camera" appears in video app camera lists**  
✅ **Other apps can select and use the virtual camera**  
✅ **Overlays render correctly in real-time**  
✅ **Frame rate stays at 30 FPS**  

## 🆘 **Getting Help**

### **Check These First**
1. Console logs in Xcode
2. Plugin installation location
3. Camera permissions in System Preferences
4. Video app restart after plugin installation

### **Advanced Debugging**
1. Activity Monitor for process status
2. `log show --predicate 'subsystem contains "com.sceneit"'`
3. IPC buffer status in app debug output

This implementation provides a complete, professional virtual camera solution that works with all major video conferencing applications! 🚀