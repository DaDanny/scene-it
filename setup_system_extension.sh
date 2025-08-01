#!/bin/bash

# Setup script for CoreMediaIO System Extension
# This script helps configure the Xcode project for the virtual camera extension

set -e

echo "🚀 Setting up CoreMediaIO System Extension..."

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XCODE_PROJECT="$PROJECT_DIR/SceneIt.xcodeproj"

# Check if Xcode project exists
if [ ! -d "$XCODE_PROJECT" ]; then
    echo "❌ Error: SceneIt.xcodeproj not found"
    exit 1
fi

# Create extension directory structure if it doesn't exist
EXTENSION_DIR="$PROJECT_DIR/SceneItCameraExtension"
mkdir -p "$EXTENSION_DIR"

echo "📁 Created extension directory structure"

# Copy extension files to proper location
echo "📄 Moving extension files..."

# Files that go in the extension target
EXTENSION_FILES=(
    "SceneIt/CMIOExtension/SceneItCMIOProvider.swift"
    "SceneIt/CMIOExtension/SceneItCMIOExtension.swift"
    "SceneIt/CMIOExtension/XPCFrameReceiver.swift"
    "SceneIt/CMIOExtension/main.swift"
    "SceneIt/CMIOExtension/Info.plist"
    "SceneIt/CMIOExtension/SceneItCameraExtension.entitlements"
)

for file in "${EXTENSION_FILES[@]}"; do
    if [ -f "$PROJECT_DIR/$file" ]; then
        filename=$(basename "$file")
        cp "$PROJECT_DIR/$file" "$EXTENSION_DIR/$filename"
        echo "✅ Copied $filename to extension directory"
    else
        echo "⚠️  Warning: $file not found"
    fi
done

# Create a shared directory for files used by both targets
SHARED_DIR="$PROJECT_DIR/Shared"
mkdir -p "$SHARED_DIR"

# Copy shared files
if [ -f "$PROJECT_DIR/SceneIt/XPCProtocol.swift" ]; then
    cp "$PROJECT_DIR/SceneIt/XPCProtocol.swift" "$SHARED_DIR/"
    echo "✅ Copied XPCProtocol.swift to shared directory"
fi

echo "🔧 Extension files are now organized for Xcode configuration"

# Display next steps
echo ""
echo "📋 NEXT STEPS:"
echo "1. Open SceneIt.xcodeproj in Xcode"
echo "2. Add a new macOS System Extension target:"
echo "   - Product Name: SceneItCameraExtension"
echo "   - Bundle ID: com.ritually.SceneIt.CameraExtension"
echo "   - Minimum Deployment: macOS 14.0"
echo ""
echo "3. Add these files to the extension target:"
echo "   - SceneItCameraExtension/main.swift"
echo "   - SceneItCameraExtension/SceneItCMIOProvider.swift"
echo "   - SceneItCameraExtension/SceneItCMIOExtension.swift"
echo "   - SceneItCameraExtension/XPCFrameReceiver.swift"
echo "   - Shared/XPCProtocol.swift (add to BOTH targets)"
echo ""
echo "4. Configure entitlements and Info.plist from SceneItCameraExtension/"
echo ""
echo "5. Build both targets to verify configuration"
echo ""
echo "📖 See SYSTEM_EXTENSION_SETUP.md for detailed instructions"

# Check if we can open Xcode
if command -v xed &> /dev/null; then
    echo ""
    echo "🚀 Opening Xcode project..."
    xed "$XCODE_PROJECT"
else
    echo ""
    echo "💡 Open SceneIt.xcodeproj in Xcode to continue setup"
fi

echo ""
echo "✅ System extension setup preparation complete!"