#!/bin/bash

# Scene It Virtual Camera Plugin Build Script
# This script builds and installs the CoreMediaIO DAL plugin

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PLUGIN_DIR="$PROJECT_ROOT/SceneItVirtualCamera.plugin"
PLUGIN_NAME="SceneItVirtualCamera"

echo "🔨 Building Scene It Virtual Camera Plugin..."

# Change to plugin directory
cd "$PLUGIN_DIR/Contents/Resources"

# Clean previous build
echo "🧹 Cleaning previous build..."
make clean

# Build the plugin
echo "🔨 Building plugin..."
make

# Check if build was successful
if [ -f "../MacOS/$PLUGIN_NAME" ]; then
    echo "✅ Plugin built successfully!"
    
    # Ask user if they want to install
    read -p "📦 Install plugin to system? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "📦 Installing plugin..."
        make install
        echo "✅ Plugin installed!"
        echo ""
        echo "🎉 Scene It Virtual Camera plugin is now available!"
        echo "📱 Restart your video applications to see 'Scene It Virtual Camera' in camera lists."
        echo ""
        echo "🔧 To uninstall later, run: make uninstall"
    else
        echo "⏭️ Plugin built but not installed."
        echo "📦 To install later, run: make install"
    fi
else
    echo "❌ Plugin build failed!"
    exit 1
fi

echo ""
echo "🎯 Build process complete!"