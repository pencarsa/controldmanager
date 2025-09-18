import SwiftUI
import AppKit

/// Enhanced main content view with all new features
struct EnhancedContentView: View {
    @EnvironmentObject var menuBarController: MenuBarController
    @StateObject private var timerService = TimerService.shared
    @StateObject private var analyticsService = AnalyticsService.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var profileService = ProfileManagementService.shared
    @StateObject private var securityService = EnhancedSecurityService.shared
    @StateObject private var networkService = NetworkDiagnosticsService.shared
    @StateObject private var dashboardService = DashboardIntegrationService.shared
    
    @State private var isLoading = false
    @State private var lastActionStatus: String = "Ready"
    @State private var showStatus = false
    @State private var profileStatus: String = "Unknown"
    @State private var showingSettings = false
    @State private var showingAnalytics = false
    @State private var showingDiagnostics = false
    @State private var showingDashboard = false
    @State private var selectedDuration: TimeInterval = 3600
    @State private var showingTimerOptions = false
    @State private var settingsWindow: NSWindow?
    @State private var windowDelegate: WindowDelegate?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with dynamic icon
            headerSection
            
            Divider()
            
            // Status section
            statusSection
            
            Divider()
            
            // Main action section
            mainActionSection
            
            Divider()
            
            // Quick actions
            quickActionsSection
            
            Divider()
            
            // Footer with additional info
            footerSection
        }
        .padding()
        .frame(width: 320)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            checkProfileStatus()
            setupServices()
        }
        .onChange(of: showingSettings) { newValue in
            if newValue {
                showSettingsWindow()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            // Dynamic status icon
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundColor(statusColor)
                .animation(.easeInOut(duration: 0.3), value: profileStatus)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("ControlD Manager")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Network status indicator
            networkStatusIndicator
        }
    }
    
    private var networkStatusIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: networkService.connectionStatus.icon)
                .font(.caption)
                .foregroundColor(networkService.networkQuality.color == "green" ? .green : 
                                networkService.networkQuality.color == "orange" ? .orange : .red)
            
            Text(networkService.networkQuality.description)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(4)
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if menuBarController.needsConfiguration {
                configurationRequiredView
            } else {
                profileStatusView
            }
            
            if showStatus {
                statusMessageView
            }
        }
    }
    
    private var configurationRequiredView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Configuration Required")
                .font(.subheadline)
                .foregroundColor(.orange)
            
            Button(action: {
                showingSettings = true
            }) {
                HStack {
                    Image(systemName: "gear.fill")
                    Text("Configure Settings")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var profileStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Profile Status")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if let timerInfo = timerService.getTimerInfo(for: menuBarController.settingsManager.selectedProfileName) {
                    timerCountdownView(timerInfo)
                }
            }
            
            Text(statusDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Timer options
            if showingTimerOptions {
                timerOptionsView
            }
            
            // Main action button
            mainActionButton
        }
    }
    
    private func timerCountdownView(_ timerInfo: TimerService.TimerInfo) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.caption)
            Text(timerInfo.formattedTimeRemaining)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.orange.opacity(0.2))
        .foregroundColor(.orange)
        .cornerRadius(4)
    }
    
    private var timerOptionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Disable Duration")
                .font(.caption)
                .fontWeight(.medium)
            
            // Quick presets
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 4) {
                ForEach(timerService.quickPresets) { preset in
                    Button(action: {
                        selectedDuration = preset.duration
                        showingTimerOptions = false
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: preset.icon)
                                .font(.caption)
                            Text(preset.name)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(selectedDuration == preset.duration ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Custom duration
            HStack {
                Text("Custom:")
                    .font(.caption)
                Spacer()
                Button(action: {
                    selectedDuration = max(60, selectedDuration - 300)
                }) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                
                Text(timerService.getFormattedCustomDuration())
                    .font(.caption)
                    .fontWeight(.medium)
                
                Button(action: {
                    selectedDuration = min(86400, selectedDuration + 300)
                }) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var mainActionButton: some View {
        Button(action: {
            performMainAction()
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: mainActionIcon)
                }
                Text(mainActionText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading)
    }
    
    private var statusMessageView: some View {
        HStack {
            Image(systemName: lastActionStatus.contains("Success") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(lastActionStatus.contains("Success") ? .green : .orange)
            Text(lastActionStatus)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Actions")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                quickActionButton("Settings", icon: "gear.fill", color: .blue) {
                    showingSettings = true
                }
                
                quickActionButton("Analytics", icon: "chart.bar.fill", color: .green) {
                    showingAnalytics = true
                }
                
                quickActionButton("Diagnostics", icon: "stethoscope", color: .orange) {
                    showingDiagnostics = true
                }
                
                quickActionButton("Dashboard", icon: "safari.fill", color: .purple) {
                    dashboardService.openDashboard()
                }
            }
        }
    }
    
    private func quickActionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Timer Options") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingTimerOptions.toggle()
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .help("Customize disable duration")
                
                Spacer()
                
                Button("Quit ControlD") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .font(.caption)
            }
            
            // Additional info
            HStack {
                Text("Security: \(securityService.securityLevel.description)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Sync: \(dashboardService.getSyncStatusInfo())")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusIcon: String {
        switch profileStatus {
        case "Disabled":
            return "shield.fill"
        case "Enabled":
            return "shield"
        case "Error":
            return "exclamationmark.triangle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch profileStatus {
        case "Disabled":
            return .red
        case "Enabled":
            return .green
        case "Error":
            return .orange
        default:
            return .gray
        }
    }
    
    private var statusSubtitle: String {
        if menuBarController.needsConfiguration {
            return "Setup required"
        } else {
            return "\(menuBarController.settingsManager.selectedProfileName) • \(networkService.connectionStatus.description)"
        }
    }
    
    private var statusDescription: String {
        if menuBarController.needsConfiguration {
            return "Please configure your API key and select a profile"
        } else {
            return profileStatus == "Disabled" ?
                "Profile is currently disabled" :
                "Ready to disable profile"
        }
    }
    
    private var mainActionText: String {
        if isLoading {
            return profileStatus == "Disabled" ? "Re-enabling..." : "Disabling..."
        } else {
            if showingTimerOptions {
                return "Disable for \(timerService.getFormattedCustomDuration())"
            } else {
                return profileStatus == "Disabled" ? "Re-enable Profile" : "Disable Profile"
            }
        }
    }
    
    private var mainActionIcon: String {
        return profileStatus == "Disabled" ? "play.fill" : "clock.fill"
    }
    
    // MARK: - Actions
    
    private func performMainAction() {
        if profileStatus == "Disabled" {
            reEnableProfile()
        } else {
            disableProfile()
        }
    }
    
    private func disableProfile() {
        isLoading = true
        showStatus = false
        
        Task {
            do {
                let success = try await menuBarController.disableEndpoint()
                
                if success {
                    // Start timer
                    timerService.startTimer(
                        for: menuBarController.settingsManager.selectedProfileName,
                        duration: selectedDuration
                    )
                    
                    // Send notification
                    notificationService.notifyProfileDisabled(
                        profileName: menuBarController.settingsManager.selectedProfileName,
                        duration: selectedDuration
                    )
                    
                    // Update profile usage
                    profileService.addToRecent(menuBarController.settingsManager.selectedProfileId)
                    
                    await MainActor.run {
                        isLoading = false
                        lastActionStatus = "Success: Profile disabled for \(timerService.getFormattedCustomDuration())"
                        profileStatus = "Disabled"
                        showStatus = true
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        lastActionStatus = "Failed: Could not disable profile"
                        showStatus = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    lastActionStatus = "Error: \(error.localizedDescription)"
                    showStatus = true
                }
            }
        }
    }
    
    private func reEnableProfile() {
        isLoading = true
        showStatus = false
        
        Task {
            do {
                let success = try await menuBarController.disableEndpoint() // This toggles
                
                if success {
                    // Stop timer
                    timerService.stopTimer(for: menuBarController.settingsManager.selectedProfileName)
                    
                    // Send notification
                    notificationService.notifyProfileEnabled(
                        profileName: menuBarController.settingsManager.selectedProfileName
                    )
                    
                    await MainActor.run {
                        isLoading = false
                        lastActionStatus = "Success: Profile re-enabled"
                        profileStatus = "Enabled"
                        showStatus = true
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                        lastActionStatus = "Failed: Could not re-enable profile"
                        showStatus = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    lastActionStatus = "Error: \(error.localizedDescription)"
                    showStatus = true
                }
            }
        }
    }
    
    private func checkProfileStatus() {
        Task {
            do {
                let status = try await menuBarController.getProfileStatus()
                await MainActor.run {
                    profileStatus = status
                }
            } catch {
                print("Failed to check profile status: \(error)")
                await MainActor.run {
                    profileStatus = "Error"
                    lastActionStatus = "Error: \(error.localizedDescription)"
                    showStatus = true
                }
            }
        }
    }
    
    private func setupServices() {
        // Initialize all services
        _ = NotificationService.shared
        _ = AnalyticsService.shared
        _ = TimerService.shared
        _ = BackgroundSyncService.shared
        _ = ProfileManagementService.shared
        _ = EnhancedSecurityService.shared
        _ = NetworkDiagnosticsService.shared
        _ = DashboardIntegrationService.shared
        _ = BackupSyncService.shared
    }
    
    private func showSettingsWindow() {
        // Don't open multiple settings windows
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // Close the MenuBarExtra popover
        closeMenuBarPopover()
        
        let settingsView = EnhancedSettingsView(
            settingsManager: menuBarController.settingsManager,
            menuBarController: menuBarController
        )
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "ControlD Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        
        // Store strong references to prevent deallocation
        settingsWindow = window
        windowDelegate = WindowDelegate {
            showingSettings = false
            settingsWindow = nil
            windowDelegate = nil
            // Refresh data when settings window closes
            Task { await menuBarController.checkConnection() }
            checkProfileStatus()
        }
        window.delegate = windowDelegate
    }
    
    private func closeMenuBarPopover() {
        // Try multiple approaches to close the MenuBarExtra popover
        DispatchQueue.main.async {
            // Method 1: Look for MenuBarExtra specific windows
            for window in NSApplication.shared.windows {
                let className = window.className
                if className.contains("MenuBarExtra") ||
                   className.contains("Popover") ||
                   className.contains("MenuBarWindow") ||
                   (window.level == .popUpMenu && window.styleMask.contains(.borderless)) ||
                   (window.level == .statusBar) {
                    window.orderOut(nil)
                    print("Closed window: \(className)")
                }
            }
            
            // Method 2: Try to deactivate the app momentarily
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let frontmostApp = NSWorkspace.shared.frontmostApplication,
                   frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier {
                    // Another app is already frontmost, good
                    return
                }
                
                // Try to hide the app briefly to dismiss MenuBar popover
                NSApplication.shared.hide(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NSApplication.shared.unhide(nil)
                }
            }
        }
    }
}

// Helper class for window delegate
class WindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

#Preview {
    EnhancedContentView()
        .environmentObject(MenuBarController())
}
