#!/bin/bash

echo "🔧 Integrating Enhanced Features into ControlD MenuBar App..."
echo ""

# Check if we're in the right directory
if [ ! -f "ControlDMenuBar/ControlDMenuBar.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Please run this script from the controld1 directory"
    exit 1
fi

# Backup the current project file
echo "📋 Backing up current project file..."
cp "ControlDMenuBar/ControlDMenuBar.xcodeproj/project.pbxproj" "ControlDMenuBar/ControlDMenuBar.xcodeproj/project.pbxproj.backup"

# Create a Python script to properly modify the Xcode project
cat > update_xcode_project.py << 'EOF'
#!/usr/bin/env python3
import re
import uuid

def generate_uuid():
    """Generate a UUID-like string for Xcode project files"""
    return ''.join([f"{uuid.uuid4().hex[i:i+2].upper()}" for i in range(0, 32, 2)])

def add_files_to_project():
    """Add the enhanced service files to the Xcode project"""
    
    # Read the current project file
    with open('ControlDMenuBar/ControlDMenuBar.xcodeproj/project.pbxproj', 'r') as f:
        content = f.read()
    
    # Service files to add
    service_files = [
        'Services/NotificationService.swift',
        'Services/AnalyticsService.swift', 
        'Services/TimerService.swift',
        'Services/BackgroundSyncService.swift',
        'Services/ProfileManagementService.swift',
        'Services/NetworkDiagnosticsService.swift',
        'Services/EnhancedSecurityService.swift',
        'Services/BackupSyncService.swift',
        'Services/DashboardIntegrationService.swift'
    ]
    
    # View files to add
    view_files = [
        'Views/EnhancedContentView.swift',
        'Views/EnhancedSettingsView.swift'
    ]
    
    # Generate UUIDs for new files
    file_refs = {}
    build_files = {}
    
    for file_path in service_files + view_files:
        file_ref_id = generate_uuid()
        build_file_id = generate_uuid()
        file_refs[file_path] = file_ref_id
        build_files[file_path] = build_file_id
    
    # Add PBXFileReference entries
    file_ref_section = "/* Begin PBXFileReference section */"
    file_ref_end = "/* End PBXFileReference section */"
    
    # Find the file reference section
    start_idx = content.find(file_ref_section)
    end_idx = content.find(file_ref_end)
    
    if start_idx == -1 or end_idx == -1:
        print("❌ Could not find PBXFileReference section")
        return False
    
    # Extract existing file references
    existing_refs = content[start_idx:end_idx]
    
    # Add new file references
    new_refs = []
    for file_path, ref_id in file_refs.items():
        filename = file_path.split('/')[-1]
        new_refs.append(f"\t\t{ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};")
    
    # Insert new references before the end marker
    new_content = content[:end_idx] + '\n' + '\n'.join(new_refs) + '\n' + content[end_idx:]
    
    # Add PBXBuildFile entries
    build_file_section = "/* Begin PBXBuildFile section */"
    build_file_end = "/* End PBXBuildFile section */"
    
    start_idx = new_content.find(build_file_section)
    end_idx = new_content.find(build_file_end)
    
    if start_idx == -1 or end_idx == -1:
        print("❌ Could not find PBXBuildFile section")
        return False
    
    # Add new build file entries
    new_build_files = []
    for file_path, build_id in build_files.items():
        ref_id = file_refs[file_path]
        filename = file_path.split('/')[-1]
        new_build_files.append(f"\t\t{build_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref_id} /* {filename} */; }};")
    
    # Insert new build files before the end marker
    new_content = new_content[:end_idx] + '\n' + '\n'.join(new_build_files) + '\n' + new_content[end_idx:]
    
    # Write the updated project file
    with open('ControlDMenuBar/ControlDMenuBar.xcodeproj/project.pbxproj', 'w') as f:
        f.write(new_content)
    
    print("✅ Successfully updated Xcode project file")
    return True

if __name__ == "__main__":
    add_files_to_project()
EOF

# Make the Python script executable
chmod +x update_xcode_project.py

# Run the Python script
echo "🔧 Updating Xcode project file..."
python3 update_xcode_project.py

if [ $? -eq 0 ]; then
    echo "✅ Xcode project updated successfully!"
else
    echo "❌ Failed to update Xcode project"
    echo "🔄 Restoring backup..."
    cp "ControlDMenuBar/ControlDMenuBar.xcodeproj/project.pbxproj.backup" "ControlDMenuBar/ControlDMenuBar.xcodeproj/project.pbxproj"
    exit 1
fi

# Clean up
rm -f update_xcode_project.py

echo ""
echo "🚀 Now building the enhanced application..."

# Build the enhanced app
cd ControlDMenuBar
xcodebuild -project ControlDMenuBar.xcodeproj -scheme ControlDMenuBar -configuration Release -derivedDataPath build clean build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Copy to Applications
    echo "📦 Installing enhanced app to /Applications..."
    cp -r "./build/Build/Products/Release/ControlD.app" /Applications/
    
    echo ""
    echo "🎉 SUCCESS! Enhanced ControlD app installed!"
    echo ""
    echo "📱 New Features Available:"
    echo "   • Custom timer options (15min, 30min, 1hr, 2hr, 4hr, custom)"
    echo "   • Status monitoring & notifications"
    echo "   • Usage analytics & insights"
    echo "   • Advanced profile management"
    echo "   • Enhanced security with biometric auth"
    echo "   • Network diagnostics"
    echo "   • Dashboard integration"
    echo "   • Backup & sync functionality"
    echo "   • Dynamic menu bar icon states"
    echo "   • And much more!"
    echo ""
    echo "🚀 Launch the app from /Applications/ControlD.app to see all features!"
    
else
    echo "❌ Build failed. Please check the Xcode project manually."
    echo "💡 You may need to add the Services/ and Views/ folders to Xcode:"
    echo "   1. Open ControlDMenuBar.xcodeproj in Xcode"
    echo "   2. Right-click 'ControlDMenuBar' group"
    echo "   3. Select 'Add Files to ControlDMenuBar'"
    echo "   4. Choose Services/ and Views/ folders"
    echo "   5. Ensure 'Create groups' is selected"
    echo "   6. Click 'Add'"
fi

cd ..
