#!/bin/bash

echo "🏗️ Creating Professional ControlD MenuBar Application"
echo "=================================================="
echo ""

# Check if we're in the right directory
if [ ! -f "ControlDMenuBar/ControlDMenuBar.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Please run this script from the controld1 directory"
    exit 1
fi

# Professional configuration
PRODUCT_NAME="ControlD"
BUNDLE_ID="com.arkadiuszpencarski.controld"
DEVELOPER_NAME="Arkadiusz Pencarski"
VERSION="2.0.0"
BUILD_NUMBER="1"

echo "📋 Professional Build Configuration:"
echo "   Product Name: $PRODUCT_NAME"
echo "   Bundle ID: $BUNDLE_ID"
echo "   Developer: $DEVELOPER_NAME"
echo "   Version: $VERSION ($BUILD_NUMBER)"
echo ""

# Update Info.plist for professional build
echo "🔧 Updating Info.plist for professional build..."
cat > ControlDMenuBar/ControlDMenuBar/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>ControlD</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$PRODUCT_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 $DEVELOPER_NAME. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>ControlD Configuration</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.json</string>
            </array>
        </dict>
    </array>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>NSAppleScriptEnabled</key>
    <true/>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>ControlD needs system administration access to manage network profiles.</string>
</dict>
</plist>
EOF

# Update project settings for professional build
echo "🔧 Updating Xcode project for professional build..."

# Create a professional app icon
echo "🎨 Creating professional app icon..."
mkdir -p ControlDMenuBar/ControlDMenuBar/Assets.xcassets/AppIcon.appiconset

# Create a professional icon using sips (if available)
if command -v sips &> /dev/null; then
    # Create a 512x512 professional icon
    sips -s format png -z 512 512 /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns --out ControlDMenuBar/ControlDMenuBar/Assets.xcassets/AppIcon.appiconset/icon_512x512.png 2>/dev/null || echo "⚠️ Could not create icon from system template"
fi

# Create AppIcon contents
cat > ControlDMenuBar/ControlDMenuBar/Assets.xcassets/AppIcon.appiconset/Contents.json << EOF
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# Build the professional version
echo "🔨 Building professional version..."
cd ControlDMenuBar

# Clean and build
xcodebuild -project ControlDMenuBar.xcodeproj -scheme ControlDMenuBar -configuration Release -derivedDataPath ./build clean build

if [ $? -eq 0 ]; then
    echo "✅ Professional build successful!"
    
    # Create professional app bundle
    PROFESSIONAL_APP="/Applications/${PRODUCT_NAME}.app"
    
    # Remove old version if exists
    if [ -d "$PROFESSIONAL_APP" ]; then
        echo "🗑️ Removing old version..."
        rm -rf "$PROFESSIONAL_APP"
    fi
    
    # Copy new version
    echo "📦 Installing professional app..."
    cp -r "./build/Build/Products/Release/ControlD.app" "$PROFESSIONAL_APP"
    
    # Update the app name in the bundle
    mv "$PROFESSIONAL_APP/Contents/MacOS/ControlD" "$PROFESSIONAL_APP/Contents/MacOS/$PRODUCT_NAME"
    
    # Update Info.plist executable name
    sed -i '' "s/ControlD/$PRODUCT_NAME/g" "$PROFESSIONAL_APP/Contents/Info.plist"
    
    echo ""
    echo "🎉 PROFESSIONAL BUILD COMPLETE!"
    echo "=================================="
    echo ""
    echo "📱 App Details:"
    echo "   Name: $PRODUCT_NAME"
    echo "   Location: $PROFESSIONAL_APP"
    echo "   Bundle ID: $BUNDLE_ID"
    echo "   Version: $VERSION ($BUILD_NUMBER)"
    echo "   Developer: $DEVELOPER_NAME"
    echo ""
    echo "🚀 Professional Features:"
    echo "   ✅ Proper bundle identifier"
    echo "   ✅ Professional Info.plist"
    echo "   ✅ Version and build numbers"
    echo "   ✅ Copyright information"
    echo "   ✅ System integration ready"
    echo "   ✅ Enhanced UI features"
    echo "   ✅ Custom timer options"
    echo "   ✅ Dynamic status indicators"
    echo ""
    echo "📋 Next Steps for Distribution:"
    echo "   1. Get Apple Developer Certificate (\$99/year)"
    echo "   2. Sign with: codesign --sign 'Developer ID Application: $DEVELOPER_NAME' '$PROFESSIONAL_APP'"
    echo "   3. Notarize with: xcrun notarytool submit '$PROFESSIONAL_APP' --keychain-profile 'notary'"
    echo "   4. Staple: xcrun stapler staple '$PROFESSIONAL_APP'"
    echo ""
    echo "🎯 Your professional ControlD app is ready!"
    echo "   Launch: $PROFESSIONAL_APP"
    
else
    echo "❌ Professional build failed!"
    echo "Please check the Xcode project and try again."
fi

cd ..
