#!/bin/bash

echo "🔄 Stopping any running ControlD instances..."
pkill -f "ControlD" 2>/dev/null || true
sleep 2

echo "🚀 Starting the new ControlD app..."
# Note: Update this path to your local build directory
# Example: open "~/Library/Developer/Xcode/DerivedData/ControlDMenuBar-*/Build/Products/Debug/ControlD.app"
echo "Please build the app first using: xcodebuild -scheme ControlDMenuBar -destination 'platform=macOS' build"

echo "✅ Build the app and run from your local DerivedData directory"