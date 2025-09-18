import SwiftUI
import AppKit

/// Enhanced settings view with all new features and services
struct EnhancedSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var menuBarController: MenuBarController
    
    @StateObject private var timerService = TimerService.shared
    @StateObject private var analyticsService = AnalyticsService.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var profileService = ProfileManagementService.shared
    @StateObject private var securityService = EnhancedSecurityService.shared
    @StateObject private var networkService = NetworkDiagnosticsService.shared
    @StateObject private var dashboardService = DashboardIntegrationService.shared
    @StateObject private var backupService = BackupSyncService.shared
    
    @FocusState private var isApiKeyFocused: Bool
    @State private var selectedTab: SettingsTab = .general
    
    @State private var apiKeyInput: String = ""
    @State private var isValidatingKey: Bool = false
    @State private var validationMessage: String = ""
    @State private var showValidationMessage: Bool = false
    @State private var isApiKeyMasked: Bool = true
    @State private var isLoadingProfiles: Bool = false
    @State private var profilesError: String = ""
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case profiles = "Profiles"
        case security = "Security"
        case analytics = "Analytics"
        case notifications = "Notifications"
        case backup = "Backup"
        case diagnostics = "Diagnostics"
        case dashboard = "Dashboard"
        
        var icon: String {
            switch self {
            case .general:
                return "gear"
            case .profiles:
                return "person.crop.circle"
            case .security:
                return "lock.shield"
            case .analytics:
                return "chart.bar"
            case .notifications:
                return "bell"
            case .backup:
                return "icloud"
            case .diagnostics:
                return "stethoscope"
            case .dashboard:
                return "safari"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebarView
            
            Divider()
            
            // Main content
            mainContentView
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            setupInitialState()
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("ControlD Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Text("Configure your ControlD experience")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            // Tab list
            VStack(alignment: .leading, spacing: 4) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            
            Spacer()
            
            // Footer
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                
                HStack {
                    Button("Reset All Settings") {
                        resetAllSettings()
                    }
                    .buttonStyle(.destructive)
                    .font(.caption)
                    
                    Spacer()
                    
                    Button("Save & Close") {
                        saveAndClose()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 200)
        .background(Color(.controlBackgroundColor))
    }
    
    private func tabButton(_ tab: SettingsTab) -> some View {
        Button(action: {
            selectedTab = tab
        }) {
            HStack {
                Image(systemName: tab.icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                
                Text(tab.rawValue)
                    .font(.system(size: 13))
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .foregroundColor(selectedTab == tab ? .accentColor : .primary)
    }
    
    // MARK: - Main Content
    
    private var mainContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch selectedTab {
                case .general:
                    generalSettingsView
                case .profiles:
                    profilesSettingsView
                case .security:
                    securitySettingsView
                case .analytics:
                    analyticsSettingsView
                case .notifications:
                    notificationsSettingsView
                case .backup:
                    backupSettingsView
                case .diagnostics:
                    diagnosticsSettingsView
                case .dashboard:
                    dashboardSettingsView
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - General Settings
    
    private var generalSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General Settings")
                .font(.title3)
                .fontWeight(.semibold)
            
            // API Key Section
            apiKeySection
            
            // Profile Selection
            profileSelectionSection
            
            // Timer Settings
            timerSettingsSection
        }
    }
    
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("API Key", systemImage: "key.fill")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if isApiKeyMasked && !apiKeyInput.isEmpty {
                        SecureField("Paste your API token here", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .focused($isApiKeyFocused)
                            .font(.system(.caption, design: .monospaced))
                    } else {
                        TextField("Paste your API token here", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .focused($isApiKeyFocused)
                            .font(.system(.caption, design: .monospaced))
                    }
                    
                    Button(action: {
                        isApiKeyMasked.toggle()
                    }) {
                        Image(systemName: isApiKeyMasked ? "eye.slash.fill" : "eye.fill")
                    }
                    .buttonStyle(.plain)
                }
                
                if showValidationMessage {
                    Text(validationMessage)
                        .font(.caption2)
                        .foregroundColor(validationMessage.contains("✅") ? .green : .red)
                }
            }
            
            HStack {
                Button(action: validateApiKey) {
                    if isValidatingKey {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Validate API Key")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isValidatingKey || apiKeyInput.isEmpty)
                
                Spacer()
                
                Button("Load Profiles") {
                    loadProfiles()
                }
                .buttonStyle(.bordered)
                .disabled(!settingsManager.hasValidApiKey || isLoadingProfiles)
            }
        }
    }
    
    private var profileSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Profile Selection", systemImage: "person.crop.circle.fill")
                .font(.headline)
            
            if isLoadingProfiles {
                ProgressView("Loading profiles...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if !profilesError.isEmpty {
                Text("Error: \(profilesError)")
                    .font(.caption)
                    .foregroundColor(.red)
            } else if !profileService.profiles.isEmpty {
                ProfileSelectionView(
                    profiles: profileService.profiles,
                    selectedProfileId: settingsManager.selectedProfileId,
                    onProfileSelected: { profile in
                        settingsManager.saveSelectedProfile(id: profile.id, name: profile.displayName)
                    }
                )
            } else {
                Text("Click 'Load Profiles' to fetch your ControlD profiles")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var timerSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Timer Settings", systemImage: "timer")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Disable Duration")
                    .font(.subheadline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(timerService.quickPresets) { preset in
                        Button(action: {
                            timerService.setDefaultPreset(preset)
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: preset.icon)
                                    .font(.title3)
                                Text(preset.name)
                                    .font(.caption)
                                Text(preset.formattedDuration)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(preset.isDefault ? Color.accentColor.opacity(0.2) : Color(.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Security Settings
    
    private var securitySettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Security Settings")
                .font(.title3)
                .fontWeight(.semibold)
            
            // Security Level
            VStack(alignment: .leading, spacing: 8) {
                Text("Security Level")
                    .font(.headline)
                
                Picker("Security Level", selection: $securityService.securityLevel) {
                    Text("Basic").tag(EnhancedSecurityService.SecurityLevel.basic)
                    Text("Standard").tag(EnhancedSecurityService.SecurityLevel.standard)
                    Text("Enhanced").tag(EnhancedSecurityService.SecurityLevel.enhanced)
                    Text("Maximum").tag(EnhancedSecurityService.SecurityLevel.maximum)
                }
                .pickerStyle(.segmented)
            }
            
            // Biometric Settings
            if securityService.isBiometricAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Biometric Authentication")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: securityService.biometricType == .faceID ? "faceid" : "touchid")
                        Text("\(securityService.biometricType == .faceID ? "Face ID" : "Touch ID") Available")
                    }
                    .foregroundColor(.green)
                }
            }
            
            // Audit Log
            VStack(alignment: .leading, spacing: 8) {
                Text("Security Audit Log")
                    .font(.headline)
                
                HStack {
                    Text("\(securityService.auditLog.count) entries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("View Log") {
                        // Show audit log
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    
                    Button("Export") {
                        let export = securityService.exportAuditLog()
                        // Handle export
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Analytics Settings
    
    private var analyticsSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analytics & Insights")
                .font(.title3)
                .fontWeight(.semibold)
            
            // Daily Stats
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Usage")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Disables")
                            .font(.caption)
                        Text("\(analyticsService.dailyStats.totalDisables)")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Text("Total Duration")
                            .font(.caption)
                        Text(formatDuration(analyticsService.dailyStats.totalDuration))
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            // Insights
            VStack(alignment: .leading, spacing: 8) {
                Text("Insights")
                    .font(.headline)
                
                ForEach(analyticsService.generateInsights()) { insight in
                    HStack {
                        Image(systemName: insight.type == .recommendation ? "lightbulb.fill" : "info.circle.fill")
                            .foregroundColor(insight.type == .recommendation ? .yellow : .blue)
                        
                        VStack(alignment: .leading) {
                            Text(insight.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(insight.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Notifications Settings
    
    private var notificationsSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notifications")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Notification Status")
                    .font(.headline)
                
                HStack {
                    Image(systemName: notificationService.isAuthorized ? "bell.fill" : "bell.slash.fill")
                        .foregroundColor(notificationService.isAuthorized ? .green : .red)
                    
                    Text(notificationService.isAuthorized ? "Notifications Enabled" : "Notifications Disabled")
                        .font(.subheadline)
                }
                
                if !notificationService.isAuthorized {
                    Text("Enable notifications in System Preferences to receive status updates")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Backup Settings
    
    private var backupSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Backup & Sync")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("iCloud Backup")
                    .font(.headline)
                
                HStack {
                    Image(systemName: backupService.isCloudAvailable ? "icloud.fill" : "icloud.slash.fill")
                        .foregroundColor(backupService.isCloudAvailable ? .blue : .red)
                    
                    Text(backupService.isCloudAvailable ? "iCloud Available" : "iCloud Not Available")
                        .font(.subheadline)
                }
                
                if backupService.isCloudAvailable {
                    Button("Create Backup") {
                        Task {
                            await backupService.createBackup()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Data Export")
                    .font(.headline)
                
                HStack {
                    Button("Export Data") {
                        let exportData = backupService.exportData()
                        // Handle export
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Import Data") {
                        // Handle import
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Diagnostics Settings
    
    private var diagnosticsSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Network Diagnostics")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Connection Status")
                    .font(.headline)
                
                HStack {
                    Image(systemName: networkService.connectionStatus.icon)
                        .foregroundColor(networkService.networkQuality.color == "green" ? .green : .orange)
                    
                    Text("\(networkService.connectionStatus.description) • \(networkService.networkQuality.description)")
                        .font(.subheadline)
                }
                
                Button("Run Diagnostics") {
                    Task {
                        await networkService.runFullDiagnostics()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    // MARK: - Dashboard Settings
    
    private var dashboardSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dashboard Integration")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Access")
                    .font(.headline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(dashboardService.getQuickActions()) { action in
                        Button(action: {
                            performDashboardAction(action.action)
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: action.icon)
                                    .font(.title3)
                                Text(action.title)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialState() {
        apiKeyInput = settingsManager.apiKey ?? ""
        if settingsManager.hasValidApiKey {
            validationMessage = "✅ API key is valid"
            showValidationMessage = true
            loadProfiles()
        }
    }
    
    private func validateApiKey() {
        guard !apiKeyInput.isEmpty else { return }
        
        isValidatingKey = true
        showValidationMessage = false
        
        Task {
            do {
                let isValid = try await menuBarController.validateApiKey(apiKeyInput)
                await MainActor.run {
                    isValidatingKey = false
                    if isValid {
                        settingsManager.apiKey = apiKeyInput
                        validationMessage = "✅ API key is valid"
                        showValidationMessage = true
                        loadProfiles()
                    } else {
                        validationMessage = "❌ Invalid API key"
                        showValidationMessage = true
                    }
                }
            } catch {
                await MainActor.run {
                    isValidatingKey = false
                    validationMessage = "❌ Validation failed: \(error.localizedDescription)"
                    showValidationMessage = true
                }
            }
        }
    }
    
    private func loadProfiles() {
        guard settingsManager.hasValidApiKey else {
            profilesError = "Please validate your API key first"
            return
        }
        
        isLoadingProfiles = true
        profilesError = ""
        
        Task {
            do {
                let profiles = try await menuBarController.loadAvailableProfiles()
                await MainActor.run {
                    isLoadingProfiles = false
                    profileService.loadProfiles(from: profiles)
                    
                    // Auto-select if only one profile
                    if profiles.count == 1 {
                        let profile = profiles[0]
                        settingsManager.saveSelectedProfile(id: profile.PK, name: profile.name)
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingProfiles = false
                    profilesError = error.localizedDescription
                }
            }
        }
    }
    
    private func performDashboardAction(_ action: DashboardIntegrationService.DashboardQuickAction.QuickActionType) {
        switch action {
        case .openDashboard:
            dashboardService.openDashboard()
        case .openProfiles:
            dashboardService.openProfiles()
        case .openSettings:
            dashboardService.openSettings()
        case .openAnalytics:
            dashboardService.openAnalytics()
        case .openSupport:
            dashboardService.openSupport()
        case .refreshData:
            Task {
                await dashboardService.syncWithDashboard()
            }
        default:
            break
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func resetAllSettings() {
        settingsManager.resetSettings()
        apiKeyInput = ""
        validationMessage = ""
        showValidationMessage = false
        profilesError = ""
        
        // Reset all services
        analyticsService.clearAllAnalytics()
        timerService.clearAllTimers()
        securityService.clearAuditLog()
    }
    
    private func saveAndClose() {
        settingsManager.apiKey = apiKeyInput
        closeWindow()
    }
    
    private func closeWindow() {
        if let window = NSApplication.shared.keyWindow {
            window.close()
        }
    }
}

#Preview {
    EnhancedSettingsView(settingsManager: SettingsManager(), menuBarController: MenuBarController())
}
