# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Scene It (internally called "Ritually") is a native macOS application that provides virtual camera functionality with customizable overlays for video conferencing. The app runs as a menu bar application with SwiftUI interface components and uses AVFoundation for video processing. The virtual camera backend using CoreMediaIO Extension Framework is currently in development.

## Build and Development Commands

### Building the Application
```bash
# Open in Xcode (primary development environment)
open SceneIt.xcodeproj

# Build from command line (if needed)
xcodebuild -project SceneIt.xcodeproj -scheme SceneIt -configuration Debug build
```

### Testing and Verification
- No automated test suite is currently implemented
- Manual testing requires camera permissions and testing with video conferencing apps
- Verify virtual camera appears in Zoom/Meet/Teams camera selection

## Architecture Overview

### Core Application Flow
1. **App Launch**: `RituallyApp` (App.swift) shows splash screen, then transitions to menu bar mode
2. **Menu Bar Management**: `StatusBarController` handles status bar interactions and menu popover
3. **Virtual Camera**: `VirtualCameraManager` manages AVFoundation capture sessions and video processing
4. **CMIO Extension**: Custom CoreMediaIO extension (`SceneItCMIOProvider`) provides virtual camera device

### Key Components

**App Entry Point**:
- `App.swift`: SwiftUI app entry point, manages splash screen and app lifecycle
- `AppDelegate.swift`: Traditional AppKit delegate (if present)
- `AppFlowManager`: Coordinates app state transitions and window management

**Core Managers**:
- `VirtualCameraManager`: Handles camera capture, overlay processing, and virtual camera output
- `StatusBarController`: Manages menu bar presence, user interactions, and UI popover
- `OverlayManager`: Manages available overlays and overlay application logic

**UI Components**:
- `StatusBarMenuView.swift`: SwiftUI-based menu interface
- `VideoPreviewWindow.swift`: Live camera preview window
- `SettingsView.swift`: User preferences and camera selection
- `OnboardingFlow.swift`/`WelcomeScreen.swift`: First-run experience

**Virtual Camera Implementation** (In Development):
- `CMIOExtension/`: Contains existing CMIO extension components
- `SceneItCMIOProvider.swift`: CMIO provider class (partial implementation)
- Virtual camera backend implementation is in progress using native CoreMediaIO Extension Framework

### Data Models
- `AppSettings.swift`: User preferences, camera selection, profile information
- `Overlay.swift`: Overlay definitions and management

## Project Configuration

### Xcode Project Structure
- **Target**: SceneIt.app (main application)
- **Deployment Target**: macOS 13.0+
- **Frameworks**: AVFoundation, CoreMediaIO, SwiftUI, AppKit
- **Architecture**: Swift 5.0+, native macOS application

### Required Entitlements
The app requires specific entitlements in `SceneIt.entitlements`:
- `com.apple.security.device.camera` - Camera access
- `com.apple.security.device.microphone` - Microphone access
- `com.apple.security.cmio-extension` - CoreMediaIO extension
- `com.apple.security.app-sandbox` - App sandbox with appropriate permissions

### Info.plist Configuration
- `LSUIElement`: true (runs as status bar app, no dock icon)
- Camera/microphone usage descriptions for permission prompts
- CMIO extension configuration with provider class and service name

## Development Patterns

### State Management
- Uses `@Published` properties in ObservableObject classes for reactive UI updates
- `AppFlowManager.shared` singleton manages global app state transitions
- Status bar controller coordinates between UI and camera manager

### Error Handling
- Custom `VirtualCameraError` enum with localized descriptions
- Error states published through ObservableObject for UI display
- Graceful fallbacks when camera permissions denied or hardware unavailable

### Camera Pipeline
```
Physical Camera → AVCaptureSession → Core Image Processing → Overlay Application → CMIO Extension → Virtual Camera Output
```

### SwiftUI Integration
- Menu bar popover uses SwiftUI views embedded in NSPopover
- Settings and configuration windows use pure SwiftUI
- AppKit integration for menu bar and window management

## Important Implementation Details

### Virtual Camera Backend
- **Current Status**: Video processing pipeline complete, virtual camera device creation in development
- **Implementation Guide**: See `docs/COREMEDIAIO_EXTENSION_GUIDE.md` for comprehensive implementation roadmap  
- **Approach**: Native CoreMediaIO Extension Framework with System Extensions
- **Frame Processing**: Complete Core Image pipeline with GPU-accelerated overlay rendering

### App Lifecycle
- Launches with splash screen, then hides main window
- Runs primarily from menu bar with global keyboard shortcut (CMD+SHIFT+S)
- Camera sessions managed independently of UI lifecycle

### Settings and Persistence
- User settings stored via `@AppStorage` (UserDefaults)
- Camera selection persists across app restarts
- Profile information (name, job title) stored for overlay personalization

## File Organization Notes

- **Views/**: All SwiftUI view components
- **Controllers/**: App flow and state management controllers  
- **Models/**: Data models and app settings
- **CMIOExtension/**: Virtual camera implementation (partial)
- **IPC/**: Inter-process communication components
- **Resources/**: Assets, entitlements, Info.plist
- **docs/**: Technical documentation and implementation guides

### Key Documentation
- **`docs/COREMEDIAIO_EXTENSION_GUIDE.md`**: Comprehensive guide for implementing the native virtual camera using CoreMediaIO Extension Framework
- **`README.md`**: User-facing project overview and setup instructions

The codebase follows modern Swift conventions with SwiftUI for UI, ObservableObject for state management, and native macOS patterns for menu bar applications.