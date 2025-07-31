# 🛠️ Xcode Setup Guide for Scene It CMIOExtension

## 🚨 **Current Issue**: Command Line Tools vs Full Xcode

You're currently using **Command Line Tools** which doesn't support:
- Device registration
- CMIOExtension development  
- Automatic provisioning profiles
- Full xcodebuild functionality

## 📱 **Solution: Install Full Xcode**

### **Step 1: Install Xcode**
```bash
# Option A: App Store (Recommended)
# Open App Store → Search "Xcode" → Install

# Option B: Direct Download (Developer Account Required)
# Visit: https://developer.apple.com/xcode/
```

### **Step 2: Switch to Full Xcode**
```bash
# After Xcode is installed, switch to it
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Verify the switch
xcode-select --print-path
# Should show: /Applications/Xcode.app/Contents/Developer
```

### **Step 3: Accept License and Install Components**
```bash
# Accept Xcode license
sudo xcodebuild -license accept

# Install additional components
sudo xcodebuild -runFirstLaunch
```

## 🚀 **After Xcode Installation**

### **Build Scene It with CMIOExtension**
```bash
cd /Users/dannyfrancken/Personal/devbydanny/scene-it

# Build the project
xcodebuild -project SceneIt.xcodeproj -scheme SceneIt -configuration Debug build

# Or open in Xcode GUI
open SceneIt.xcodeproj
```

### **Device Registration (Now Available)**
```bash
# Register your Mac device
# Device: TheBonus
# UUID: 68998DA4-BDAB-5666-9748-CE1EEE41A087

# Xcode will handle this automatically when you:
# 1. Open the project
# 2. Select your Mac as build destination  
# 3. Try to run the app
```

## 🎯 **Immediate Testing Steps**

### **1. Open in Xcode**
```bash
open SceneIt.xcodeproj
```

### **2. Configure Signing**
- Select **SceneIt** target
- Go to **Signing & Capabilities**
- Ensure **Team** is set to your account (378NGS49HA)
- **Automatically manage signing** should be checked

### **3. Build and Run**
- Select your Mac as destination
- Press **⌘+R** to build and run
- Xcode will prompt to register device if needed

### **4. Test Virtual Camera**
1. **Scene It launches** → Status bar icon appears
2. **Grant camera permission** when prompted
3. **Start virtual camera** with an overlay
4. **Test in video app** → Look for "Scene It Virtual Camera"

## 🔧 **Troubleshooting**

### **If Build Fails After Xcode Install**
```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/

# Clean project
xcodebuild -project SceneIt.xcodeproj -scheme SceneIt clean

# Rebuild
xcodebuild -project SceneIt.xcodeproj -scheme SceneIt build
```

### **If Device Still Not Registered**
1. **Open Xcode** → Window → Devices and Simulators
2. **Select your Mac** in left sidebar  
3. **Use for Development** button should appear
4. **Click it** to register device

### **If CMIOExtension Doesn't Load**
```bash
# Check system logs for CMIOExtension
log show --predicate 'subsystem == "com.sceneit.SceneIt"' --info --last 30m

# Verify entitlements
codesign -d --entitlements - /path/to/SceneIt.app
```

## 🎉 **Expected Result**

After Xcode installation and setup:

1. **✅ Build succeeds without device registration errors**
2. **✅ Scene It app launches with status bar controls**
3. **✅ Virtual camera shows up in video apps**
4. **✅ Overlays work correctly on video stream**
5. **✅ CMIOExtension loads properly in macOS 15.6**

## ⚡ **Alternative: Quick Test without Full Build**

If you want to test the CMIOExtension concept first:

1. **Download existing CMIOExtension sample**: Apple provides samples
2. **Test virtual camera functionality**: Verify your system supports it
3. **Then install Xcode**: For full Scene It development

## 📞 **Still Having Issues?**

Common solutions:
- **Restart Xcode** after switching from Command Line Tools
- **Log out/in** to refresh developer account
- **Check System Preferences** → Privacy & Security → Camera permissions
- **Verify Apple ID** is signed in to Xcode

Your Scene It CMIOExtension implementation is complete and ready to test! 🚀