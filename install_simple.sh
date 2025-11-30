#!/bin/bash

# Simple installation script for ControlD Menu Bar App

echo "📱 Installing ControlD to /Applications..."

# Find the built app
BUILT_APP="./ControlDMenuBar/build/Build/Products/Release/ControlD.app"

if [ ! -d "$BUILT_APP" ]; then
    echo "❌ Built app not found at: $BUILT_APP"
    echo "Please run ./build.sh first."
    exit 1
fi

# Check if app exists in Applications
if [ -d "/Applications/ControlD.app" ]; then
    echo "🔄 Removing existing ControlD app..."
    rm -rf "/Applications/ControlD.app"
fi

# Copy to Applications (this will prompt for password if needed)
echo "📦 Copying to /Applications..."
cp -R "$BUILT_APP" "/Applications/ControlD.app"

if [ $? -eq 0 ]; then
    echo "✅ Successfully installed ControlD to /Applications!"
    
    # Clear quarantine attributes
    xattr -cr "/Applications/ControlD.app" 2>/dev/null || true
    
    echo "🚀 Launching ControlD..."
    open "/Applications/ControlD.app"
    
    echo ""
    echo "🎉 Installation complete!"
    echo "Look for the colorful shield icon in your menu bar."
    echo ""
    echo "To uninstall: rm -rf '/Applications/ControlD.app'"
else
    echo "❌ Installation failed. You may need to install manually:"
    echo "   1. Open Finder"
    echo "   2. Navigate to: $(dirname "$BUILT_APP")"
    echo "   3. Drag ControlDMenuBar.app to Applications folder"
    echo "   4. Rename it to ControlD.app"
fi
