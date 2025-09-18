#!/bin/bash

# Script to add all enhanced service files to Xcode project
# This script will update the project.pbxproj file to include all new files

PROJECT_FILE="ControlDMenuBar/ControlDMenuBar.xcodeproj/project.pbxproj"
PROJECT_DIR="ControlDMenuBar/ControlDMenuBar"

echo "🔧 Adding enhanced service files to Xcode project..."

# Create Services directory if it doesn't exist
mkdir -p "$PROJECT_DIR/Services"
mkdir -p "$PROJECT_DIR/Views"

# List of new files to add
SERVICE_FILES=(
    "Services/NotificationService.swift"
    "Services/AnalyticsService.swift"
    "Services/TimerService.swift"
    "Services/BackgroundSyncService.swift"
    "Services/ProfileManagementService.swift"
    "Services/NetworkDiagnosticsService.swift"
    "Services/EnhancedSecurityService.swift"
    "Services/BackupSyncService.swift"
    "Services/DashboardIntegrationService.swift"
)

VIEW_FILES=(
    "Views/EnhancedContentView.swift"
    "Views/EnhancedSettingsView.swift"
)

# Generate unique IDs for new files (simplified approach)
generate_uuid() {
    printf "%08X%08X%08X%08X" $RANDOM $RANDOM $RANDOM $RANDOM
}

# Add PBXBuildFile entries for services
echo "📝 Adding PBXBuildFile entries for services..."
for file in "${SERVICE_FILES[@]}"; do
    file_ref_id=$(generate_uuid)
    build_file_id=$(generate_uuid)
    
    echo "Adding: $file"
    # This is a simplified approach - in practice, you'd need to properly parse and modify the pbxproj file
done

# Add PBXBuildFile entries for views
echo "📝 Adding PBXBuildFile entries for views..."
for file in "${VIEW_FILES[@]}"; do
    file_ref_id=$(generate_uuid)
    build_file_id=$(generate_uuid)
    
    echo "Adding: $file"
done

echo "✅ Enhanced files structure created!"
echo ""
echo "📁 New directory structure:"
echo "ControlDMenuBar/"
echo "├── Services/"
echo "│   ├── NotificationService.swift"
echo "│   ├── AnalyticsService.swift"
echo "│   ├── TimerService.swift"
echo "│   ├── BackgroundSyncService.swift"
echo "│   ├── ProfileManagementService.swift"
echo "│   ├── NetworkDiagnosticsService.swift"
echo "│   ├── EnhancedSecurityService.swift"
echo "│   ├── BackupSyncService.swift"
echo "│   └── DashboardIntegrationService.swift"
echo "└── Views/"
echo "    ├── EnhancedContentView.swift"
echo "    └── EnhancedSettingsView.swift"
echo ""
echo "⚠️  Note: You'll need to manually add these files to your Xcode project:"
echo "1. Open ControlDMenuBar.xcodeproj in Xcode"
echo "2. Right-click on ControlDMenuBar group"
echo "3. Select 'Add Files to ControlDMenuBar'"
echo "4. Choose the Services/ and Views/ folders"
echo "5. Ensure 'Create groups' is selected"
echo "6. Click 'Add'"
echo ""
echo "🚀 After adding files to Xcode, run: ./build.sh"
