# System Extension Setup Guide

This guide explains how to manually configure the Xcode project to add the CoreMediaIO System Extension target.

## Required Steps

### 1. Add System Extension Target

1. **Open SceneIt.xcodeproj in Xcode**
2. **Select Project Navigator** (leftmost pane)
3. **Click the project name** at the top (SceneIt)
4. **Click the "+" button** at the bottom of the targets list
5. **Choose "macOS" → "System Extension"**
6. **Configure the target:**
   - Product Name: `SceneItCameraExtension`
   - Bundle Identifier: `com.ritually.SceneIt.CameraExtension`
   - Language: Swift
   - Minimum Deployment Target: macOS 14.0

### 2. Configure Extension Files

**Move these files from `SceneIt/CMIOExtension/` to the new system extension target:**

```
SceneIt/CMIOExtension/
├── SceneItCMIOProvider.swift          → Move to extension target
├── SceneItCMIOExtension.swift         → Move to extension target  
├── XPCFrameReceiver.swift             → Move to extension target
├── main.swift                         → Move to extension target
├── Info.plist                         → Replace extension's Info.plist
└── SceneItCameraExtension.entitlements → Set as extension entitlements
```

**Keep in main app target:**
```
SceneIt/
├── XPCProtocol.swift                  → Shared between targets
├── XPCFrameTransmitter.swift          → Main app only
└── CMIOExtensionInstaller.swift       → Main app only
```

### 3. Shared Files Configuration

**Add these files to BOTH targets (main app + extension):**
- `XPCProtocol.swift` (contains shared protocol definitions)

**In Xcode:**
1. Select `XPCProtocol.swift` in Project Navigator  
2. In File Inspector (right pane), check BOTH target checkboxes:
   - ✅ SceneIt
   - ✅ SceneItCameraExtension

### 4. Extension Target Settings

**Build Settings for SceneItCameraExtension target:**

```
PRODUCT_NAME = SceneItCameraExtension
BUNDLE_IDENTIFIER = com.ritually.SceneIt.CameraExtension
MACOSX_DEPLOYMENT_TARGET = 14.0
PRODUCT_BUNDLE_PACKAGE_TYPE = APPEX
CODE_SIGN_ENTITLEMENTS = SceneIt/CMIOExtension/SceneItCameraExtension.entitlements
INFOPLIST_FILE = SceneIt/CMIOExtension/Info.plist
```

**Frameworks to link (Build Phases → Link Binary With Libraries):**
- CoreMediaIO.framework
- CoreMedia.framework
- CoreVideo.framework
- Foundation.framework
- os.framework

### 5. Main App Entitlements

**Update `SceneIt/Resources/SceneIt.entitlements`:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.device.camera</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.ritually.SceneIt</string>
    </array>
    <key>com.apple.developer.system-extension.install</key>
    <true/>
</dict>
</plist>
```

### 6. Build Configuration

**Ensure both targets build correctly:**

1. **Select SceneIt scheme** → Build (⌘B)
2. **Select SceneItCameraExtension scheme** → Build (⌘B)
3. **Verify no build errors**

### 7. Runtime Configuration

**The extension will be embedded in the main app bundle at:**
```
SceneIt.app/Contents/PlugIns/SceneItCameraExtension.appex/
```

**System extension installation happens via:**
```swift
// In main app - CMIOExtensionInstaller
let request = OSSystemExtensionRequest.activationRequest(
    forExtensionWithIdentifier: "com.ritually.SceneIt.CameraExtension",
    queue: .main
)
```

## File Structure After Setup

```
SceneIt.xcodeproj
├── SceneIt/ (Main App Target)
│   ├── App.swift
│   ├── VirtualCameraManager.swift (updated for XPC)
│   ├── XPCProtocol.swift (shared)
│   ├── XPCFrameTransmitter.swift  
│   ├── CMIOExtensionInstaller.swift
│   └── Resources/
│       ├── SceneIt.entitlements (updated)
│       └── Info.plist
└── SceneItCameraExtension/ (System Extension Target)
    ├── main.swift
    ├── SceneItCMIOProvider.swift
    ├── SceneItCMIOExtension.swift  
    ├── XPCFrameReceiver.swift
    ├── XPCProtocol.swift (shared)
    ├── Info.plist
    └── SceneItCameraExtension.entitlements
```

## Testing the Extension

1. **Build and run the main app**
2. **Start virtual camera** → This triggers extension installation
3. **Approve extension** in System Preferences → Privacy & Security
4. **Check virtual camera** appears in video apps like QuickTime Player
5. **Verify frame transmission** by checking logs for XPC communication

## Troubleshooting

**Extension not appearing in System Preferences:**
- Check bundle identifier matches exactly
- Verify entitlements are correct
- Ensure app is in /Applications folder

**XPC connection failures:**
- Check both targets build successfully  
- Verify shared protocol files are in both targets
- Check system extension is approved and active

**Virtual camera not appearing in video apps:**
- Verify CMIO extension is properly registered
- Check system extension status in Activity Monitor
- Restart video applications after extension installation

This setup creates a fully functional CoreMediaIO system extension that provides a native virtual camera device to macOS applications.