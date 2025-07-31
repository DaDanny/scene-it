# 🔧 Device Registration Guide for Scene It

## 🚨 **Issue**: Device "TheBonus" Not Registered

Your Mac device needs to be registered in your Apple Developer account to run the Scene It app with CMIOExtension.

## 📱 **Device Information**
- **Device Name**: TheBonus
- **Hardware UUID**: `68998DA4-BDAB-5666-9748-CE1EEE41A087`
- **Development Team**: 378NGS49HA

## 🔧 **Solution Options**

### **Option 1: Register Device in Apple Developer Portal (Recommended)**

1. **Go to Apple Developer Portal**
   - Visit: https://developer.apple.com/account/resources/devices/list
   - Sign in with your Apple ID

2. **Add New Device**
   - Click the "+" button to add device
   - Select "macOS" as platform
   - Enter device information:
     - **Device Name**: TheBonus
     - **Device ID (UDID)**: `68998DA4-BDAB-5666-9748-CE1EEE41A087`

3. **Update Provisioning Profile**
   - Go to Profiles section
   - Select or create development profile
   - Include your new device
   - Download and install updated profile

### **Option 2: Use Xcode for Automatic Registration**

If you have Xcode installed:

1. **Open Xcode**
   ```bash
   open SceneIt.xcodeproj
   ```

2. **Connect Device**
   - Select your Mac as build destination
   - Xcode will prompt to register device automatically

3. **Trust Developer**
   - Go to System Preferences → Privacy & Security
   - Allow apps from your developer account

### **Option 3: Install Full Xcode (If Using Command Line Tools)**

Since you're using command line tools, installing full Xcode will help:

1. **Install Xcode from App Store**
   - This provides full device management capabilities
   - Enables automatic device registration

2. **Switch to Full Xcode**
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   ```

### **Option 4: Manual Provisioning Profile**

If automatic signing fails:

1. **Download Manual Profile**
   - Create manual provisioning profile in developer portal
   - Include your device UDID
   - Download .mobileprovision file

2. **Install Profile**
   ```bash
   open ~/Downloads/YourProfile.mobileprovision
   ```

3. **Update Xcode Settings**
   - Change from "Automatic" to "Manual" signing
   - Select your downloaded profile

## 🧪 **Testing Steps After Registration**

### **1. Build the App**
```bash
# Try building again
cd /Users/dannyfrancken/Personal/devbydanny/scene-it
xcodebuild -project SceneIt.xcodeproj -scheme SceneIt -configuration Debug
```

### **2. Run Scene It**
```bash
# Launch the built app
open ./build/Debug/SceneIt.app
```

### **3. Test Virtual Camera**
1. **Start Scene It** - Look for icon in status bar
2. **Grant Permissions** - Allow camera access when prompted
3. **Start Virtual Camera** - Select overlay and click start
4. **Test in Video App** - Open Zoom/Teams and look for "Scene It Virtual Camera"

## 🔍 **Troubleshooting**

### **Still Getting Registration Error?**
```bash
# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData/SceneIt-*

# Check signing status
codesign -dv --verbose=4 ./build/Debug/SceneIt.app
```

### **Permission Issues?**
- Check System Preferences → Privacy & Security → Camera
- Ensure Scene It has camera permission
- Restart app after granting permissions

### **CMIOExtension Not Loading?**
```bash
# Check CMIOExtension logs
log show --predicate 'subsystem == "com.sceneit.SceneIt"' --info --last 1h
```

## 🎯 **Quick Start After Registration**

Once your device is registered:

1. **✅ Build succeeds without errors**
2. **✅ App launches and shows status bar icon** 
3. **✅ Camera permission requested and granted**
4. **✅ Virtual camera appears in video apps**
5. **✅ Overlays work correctly**

## 📞 **Need Help?**

If you continue having issues:
- Verify your Apple Developer account has active membership
- Check that Team ID `378NGS49HA` is correct
- Ensure you have development certificates installed
- Try creating a new App ID if needed

Your Scene It CMIOExtension implementation is ready - just need to get the signing sorted! 🚀