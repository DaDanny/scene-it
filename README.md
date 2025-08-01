# Scene It - Virtual Camera with Overlays

A native macOS application that provides virtual camera functionality with customizable overlays for video conferencing apps like Zoom, Google Meet, and others.

## Features

- **Status Bar Integration**: Runs as a menu bar app with a clean, unobtrusive interface
- **Virtual Camera**: Creates a virtual camera device that appears in video conferencing applications
- **Multi-Camera Support**: Select from built-in, external, or Continuity cameras
- **Professional Settings**: Configure name, job title, and camera preferences
- **Overlay System**: Apply modern-looking overlays to your video feed
- **Easy Controls**: Start/stop virtual camera and select overlays from the status bar menu
- **Hot Camera Switching**: Change cameras instantly without interrupting your virtual camera
- **Fallback Screen**: Shows a "camera not active" screen when virtual camera is selected but app is not running
- **Modern Architecture**: Built with Swift, SwiftUI, and AVFoundation using native macOS patterns

## Project Structure

```
SceneIt.xcodeproj/          # Xcode project file
SceneIt/
├── AppDelegate.swift        # Main app delegate with status bar setup
├── ContentView.swift        # Main app window (primarily for setup instructions)
├── StatusBarController.swift # Status bar menu management
├── VirtualCameraManager.swift # Virtual camera and video processing
├── Models/
│   ├── Overlay.swift        # Overlay data model and manager
│   └── AppSettings.swift    # User settings and preferences
├── Views/
│   ├── StatusBarMenuView.swift # SwiftUI menu interface
│   ├── VideoPreviewWindow.swift # Live video preview window
│   └── SettingsView.swift   # Settings configuration interface
└── Resources/
    ├── Assets.xcassets/     # App icons and assets
    ├── Info.plist          # App configuration
    └── SceneIt.entitlements # Security permissions
```

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Camera access permissions

## Setup Instructions

1. **Open in Xcode**: Double-click `SceneIt.xcodeproj` to open the project
2. **Configure Signing**: Set your development team in the project settings
3. **Build and Run**: Press Cmd+R to build and run the application

## Usage

1. **Launch the App**: The app will appear as a video camera icon in your menu bar
2. **Configure Settings** (recommended first-time setup):
   - Click the Scene It icon → "Settings..."
   - Enter your name and job title for profile information
   - Select your preferred camera from the dropdown
   - Click "Done" to save settings
3. **Start Virtual Camera**: Click the menu bar icon and select "Start Virtual Camera"
4. **Select Video Source**: In your video conferencing app, select "Scene It Virtual Camera"
5. **Choose Overlays**: Use the menu bar to select from available overlays
6. **Stop When Done**: Click "Stop Virtual Camera" when you're finished

### Settings Features
- **Profile Information**: Store name and job title for overlay personalization
- **Camera Management**: Select from all connected cameras (built-in, external, Continuity)
- **Hot-Swapping**: Change cameras without interrupting your virtual camera stream
- **Persistent Storage**: Settings automatically saved and restored on app launch

## Architecture Overview

### Core Components

- **AppDelegate**: Manages app lifecycle and initial setup
- **StatusBarController**: Handles menu bar interactions and state management  
- **VirtualCameraManager**: Manages camera capture, virtual camera output, and video processing
- **OverlayManager**: Manages available overlays and overlay application
- **StatusBarMenuView**: SwiftUI-based menu interface

### Key Technologies

- **AVFoundation**: Camera capture and video processing
- **CoreMediaIO Extension Framework**: Native virtual camera device creation
- **SystemExtensions Framework**: Secure system-level integration
- **SwiftUI**: Modern UI components
- **AppKit**: Native macOS integration

## Configuration

### Entitlements

The app requires several entitlements for proper functionality:
- Camera access (`com.apple.security.device.camera`)
- Microphone access (`com.apple.security.device.microphone`)
- CoreMediaIO extension support (`com.apple.developer.cmio.extension`)
- App sandbox with appropriate permissions

### Info.plist Settings

- `LSUIElement`: Set to true to run as status bar app
- `NSCameraUsageDescription`: Explains camera access requirement
- Camera and microphone usage descriptions for user permission prompts

## Virtual Camera Implementation

The app includes a complete video processing pipeline with overlay support. The virtual camera functionality is currently in development using Apple's native CoreMediaIO Extension Framework.

### Current Status
- ✅ **Core Video Processing**: Full camera capture and overlay system
- ✅ **User Interface**: Menu bar controls and settings
- 🔄 **Virtual Camera Backend**: Native CoreMediaIO Extension implementation in progress

### Implementation Details

For comprehensive technical documentation on the virtual camera implementation, see **[`docs/COREMEDIAIO_EXTENSION_GUIDE.md`](docs/COREMEDIAIO_EXTENSION_GUIDE.md)**.

This guide covers:
- Architecture overview and system design
- Phase-by-phase implementation roadmap
- Code examples and technical specifications
- Distribution and deployment strategies

## Future Enhancements

- [ ] Custom overlay creation and import
- [ ] Advanced overlay positioning and sizing
- [ ] Multiple overlay layers support
- [ ] Preset overlay configurations
- [ ] Background blur and replacement
- [ ] Keyboard shortcuts
- [ ] Settings panel for advanced configuration

## Troubleshooting

**Camera Access Issues**
- Ensure camera permissions are granted in System Preferences > Security & Privacy
- Restart the app after granting permissions

**Virtual Camera Not Appearing**
- The native virtual camera backend is currently in development
- See `docs/COREMEDIAIO_EXTENSION_GUIDE.md` for implementation progress
- Current version includes video processing but virtual camera device creation is pending

**Build Issues**
- Ensure you have a valid development team selected
- Check that all entitlements are properly configured
- Verify macOS deployment target compatibility

## License

Copyright © 2024. All rights reserved.