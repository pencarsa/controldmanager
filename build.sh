#!/bin/bash

# ControlD Menu Bar App - Quick Build Script

echo "🔨 Building ControlD Menu Bar Application..."

# Navigate to project directory
cd "$(dirname "$0")/ControlDMenuBar"

# Check if Xcode project exists
if [ ! -f "ControlDMenuBar.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Xcode project not found!"
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
xcodebuild clean -project ControlDMenuBar.xcodeproj -scheme ControlDMenuBar

# Build the project
echo "🔨 Building release version..."
xcodebuild -project ControlDMenuBar.xcodeproj \
           -scheme ControlDMenuBar \
           -configuration Release \
           -derivedDataPath ./build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Find the built app
    BUILT_APP=$(find ./build -name "ControlDMenuBar.app" -type d | head -1)
    
    if [ -n "$BUILT_APP" ]; then
        echo "📦 Application built to: $BUILT_APP"
        echo ""
        echo "🚀 Quick Actions:"
        echo "  1. Run now: open '$BUILT_APP'"
        echo "  2. Install to /Applications: ../install_to_applications.sh"
        echo ""
        echo "💡 The app will appear in your menu bar with a colorful shield icon."
        
        # Offer to run immediately
        read -p "🚀 Launch the app now? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo "🎯 Launching ControlD..."
            open "$BUILT_APP"
        fi
    else
        echo "⚠️  Built app not found in expected location"
    fi
else
    echo "❌ Build failed!"
    exit 1
fi
