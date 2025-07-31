#!/bin/bash

# Scene It Virtual Camera Build Script
# This script builds the CMIOExtension-based virtual camera

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo "🔨 Building Scene It Virtual Camera (CMIOExtension)..."
echo "📁 Script dir: $SCRIPT_DIR"
echo "📁 Project root: $PROJECT_ROOT"

# Build the main app and extension
echo "🔨 Building SceneIt app with CMIOExtension..."
cd "$PROJECT_ROOT"

# Build using xcodebuild
xcodebuild -project SceneIt.xcodeproj -scheme SceneIt -configuration Release build

echo "✅ Scene It Virtual Camera built successfully!"
echo ""
echo "🎉 Scene It Virtual Camera (CMIOExtension) is ready!"
echo "📱 The virtual camera will be available when Scene It app is running."
echo ""
echo "🎯 Build process complete!"