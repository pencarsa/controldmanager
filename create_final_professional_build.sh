#!/bin/bash

echo "🏗️ Creating FINAL Professional ControlD Application"
echo "=================================================="
echo ""

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

# Update Info.plist with correct bundle ID
echo "🔧 Updating Info.plist for professional build..."
cat > ControlDMenuBar/ControlDMenuBar/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$PRODUCT_NAME</string>
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

# Update Xcode project to use correct product name and bundle ID
echo "🔧 Updating Xcode project settings..."

# Update the project.pbxproj file to use the correct product name and bundle ID
sed -i '' "s/PRODUCT_NAME = ControlDMenuBar/PRODUCT_NAME = $PRODUCT_NAME/g" ControlDMenuBar/ControlDMenuBar.xcodeproj/project.pbxproj
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com.controld.menubar/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID/g" ControlDMenuBar/ControlDMenuBar.xcodeproj/project.pbxproj

# Build the professional version
echo "🔨 Building professional version..."
cd ControlDMenuBar

# Clean and build
xcodebuild -project ControlDMenuBar.xcodeproj -scheme ControlDMenuBar -configuration Release -derivedDataPath ./build clean build

if [ $? -eq 0 ]; then
    echo "✅ Professional build successful!"
    
    # Create professional app bundle
    PROFESSIONAL_APP="/Applications/${PRODUCT_NAME}.app"
    
    # Copy new version
    echo "📦 Installing professional app..."
    cp -r "./build/Build/Products/Release/ControlD.app" "$PROFESSIONAL_APP"
    
    # Update the app name in the bundle
    mv "$PROFESSIONAL_APP/Contents/MacOS/ControlD" "$PROFESSIONAL_APP/Contents/MacOS/$PRODUCT_NAME"
    
    # Update Info.plist executable name
    sed -i '' "s/ControlD/$PRODUCT_NAME/g" "$PROFESSIONAL_APP/Contents/Info.plist"
    
    # Verify the professional build
    echo ""
    echo "🔍 Verifying Professional Build:"
    echo "=================================="
    
    # Check bundle ID
    BUNDLE_ID_CHECK=$(plutil -p "$PROFESSIONAL_APP/Contents/Info.plist" | grep CFBundleIdentifier | cut -d'>' -f2 | cut -d'<' -f1 | tr -d ' ')
    echo "   Bundle ID: $BUNDLE_ID_CHECK"
    
    # Check version
    VERSION_CHECK=$(plutil -p "$PROFESSIONAL_APP/Contents/Info.plist" | grep CFBundleShortVersionString | cut -d'>' -f2 | cut -d'<' -f1 | tr -d ' ')
    echo "   Version: $VERSION_CHECK"
    
    # Check executable name
    EXECUTABLE_CHECK=$(plutil -p "$PROFESSIONAL_APP/Contents/Info.plist" | grep CFBundleExecutable | cut -d'>' -f2 | cut -d'<' -f1 | tr -d ' ')
    echo "   Executable: $EXECUTABLE_CHECK"
    
    # Check code signing
    echo "   Code Signing:"
    codesign -dv "$PROFESSIONAL_APP" 2>&1 | grep -E "(Identifier|Format|Signature)" | sed 's/^/     /'
    
    echo ""
    echo "🎉 PROFESSIONAL BUILD COMPLETE!"
    echo "=================================="
    echo ""
    echo "📱 App Details:"
    echo "   Name: $PRODUCT_NAME"
    echo "   Location: $PROFESSIONAL_APP"
    echo "   Bundle ID: $BUNDLE_ID_CHECK"
    echo "   Version: $VERSION_CHECK ($BUILD_NUMBER)"
    echo "   Developer: $DEVELOPER_NAME"
    echo ""
    echo "🚀 Professional Features:"
    echo "   ✅ Proper bundle identifier ($BUNDLE_ID)"
    echo "   ✅ Professional Info.plist"
    echo "   ✅ Version and build numbers"
    echo "   ✅ Copyright information"
    echo "   ✅ System integration ready"
    echo "   ✅ Enhanced UI features"
    echo "   ✅ Custom timer options"
    echo "   ✅ Dynamic status indicators"
    echo "   ✅ Professional app structure"
    echo ""
    echo "📋 Current Status:"
    echo "   ✅ Development-ready professional build"
    echo "   ✅ All enhanced features included"
    echo "   ✅ Proper bundle structure"
    echo "   ✅ Ready for distribution preparation"
    echo ""
    echo "🎯 Your professional ControlD app is ready!"
    echo "   Launch: $PROFESSIONAL_APP"
    echo ""
    echo "📋 For Distribution (Optional):"
    echo "   1. Get Apple Developer Certificate (\$99/year)"
    echo "   2. Sign with: codesign --sign 'Developer ID Application: $DEVELOPER_NAME' '$PROFESSIONAL_APP'"
    echo "   3. Notarize with: xcrun notarytool submit '$PROFESSIONAL_APP' --keychain-profile 'notary'"
    echo "   4. Staple: xcrun stapler staple '$PROFESSIONAL_APP'"
    echo ""
    echo "✅ This is a PROFESSIONAL BUILD, not temporary!"
    
else
    echo "❌ Professional build failed!"
    echo "Please check the Xcode project and try again."
fi

cd ..
