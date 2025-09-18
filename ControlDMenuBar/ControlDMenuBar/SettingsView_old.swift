import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var menuBarController: MenuBarController
    @FocusState private var isApiKeyFocused: Bool
    
    @State private var apiKeyInput: String = ""
    @State private var isValidatingKey: Bool = false
    @State private var validationMessage: String = ""
    @State private var showValidationMessage: Bool = false
    @State private var isApiKeyMasked: Bool = true
    @State private var isLoadingProfiles: Bool = false
    @State private var profilesError: String = ""
    @State private var isProcessingProfile: Bool = false
    @State private var profileActionMessage: String = ""
    @State private var selectedDurationMinutes: Int = 60
    @State private var customDurationHours: Int = 1
    @State private var customDurationMinutes: Int = 0
    @State private var showDurationPicker: Bool = false
    
    // Duration options that match the interface in your screenshot
    private let durationOptions = [
        (name: "Quick", minutes: 15, icon: "cup.and.saucer"),
        (name: "Short", minutes: 30, icon: "clock"),
        (name: "Work", minutes: 60, icon: "briefcase"),
        (name: "Long", minutes: 120, icon: "clock.arrow.circlepath"),
        (name: "Extended", minutes: 480, icon: "moon")
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "shield.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("ControlD Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Configure API key and profile selection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 10)
            
            Divider()
            
            // API Key Section
            VStack(alignment: .leading, spacing: 12) {
                Label("API Key", systemImage: "key.fill")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Enter your ControlD API token")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if isApiKeyMasked && !apiKeyInput.isEmpty {
                            SecureField("Paste your API token here", text: $apiKeyInput)
                                .textFieldStyle(.roundedBorder)
                                .focused($isApiKeyFocused)
                                .font(.system(.caption, design: .monospaced))
                                .frame(minHeight: 32)
                                .background(Color(.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isApiKeyFocused ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .onSubmit {
                                    if !apiKeyInput.isEmpty {
                                        validateApiKey()
                                    }
                                }
                        } else {
                            TextField("Paste your API token here", text: $apiKeyInput)
                                .textFieldStyle(.roundedBorder)
                                .focused($isApiKeyFocused)
                                .font(.system(.caption, design: .monospaced))
                                .frame(minHeight: 32)
                                .background(Color(.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isApiKeyFocused ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .onSubmit {
                                    if !apiKeyInput.isEmpty {
                                        validateApiKey()
                                    }
                                }
                        }
                        
                        Button(action: {
                            isApiKeyMasked.toggle()
                        }) {
                            Image(systemName: isApiKeyMasked ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .help(isApiKeyMasked ? "Show API key" : "Hide API key")
                    }
                    
                    HStack {
                        Button(action: validateApiKey) {
                            HStack {
                                if isValidatingKey {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.shield")
                                }
                                Text("Validate Key")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(apiKeyInput.isEmpty || isValidatingKey)
                        
                        Button("Clear") {
                            apiKeyInput = ""
                            settingsManager.apiKey = nil
                            validationMessage = ""
                            showValidationMessage = false
                            profilesError = ""
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    
                    if showValidationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundColor(validationMessage.contains("✅") ? .green : .red)
                            .padding(.top, 4)
                    }
                }
            }
            
            Divider()
            
            // Profile Selection Section
            VStack(alignment: .leading, spacing: 12) {
                Label("Profile Selection", systemImage: "person.crop.circle")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Choose which ControlD profile to manage")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    // Only show load button if profiles are not loaded
                    if settingsManager.availableProfiles.isEmpty {
                        HStack {
                            Button("Load Profiles") {
                                loadProfiles()
                            }
                            .disabled(!settingsManager.hasValidApiKey || isLoadingProfiles)
                            .buttonStyle(.borderedProminent)
                            
                            if isLoadingProfiles {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            }
                        }
                        
                        if !profilesError.isEmpty {
                            Text(profilesError)
                                .font(.caption)
                                .foregroundColor(.red)
                        } else if settingsManager.hasValidApiKey {
                            Text("Click 'Load Profiles' to fetch your ControlD profiles")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // Profiles are loaded, show them
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Found \(settingsManager.availableProfiles.count) profiles")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                
                                Spacer()
                                
                                Button("Refresh") {
                                    loadProfiles()
                                }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .disabled(isLoadingProfiles)
                                
                                if isLoadingProfiles {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.6)
                                }
                            }
                            
                            // Simple Profile Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Select a profile to manage:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ForEach(settingsManager.availableProfiles, id: \.PK) { profile in
                                    Button(action: {
                                        print("🎯 Profile selected: \(profile.name) (\(profile.PK))")
                                        settingsManager.saveSelectedProfile(id: profile.PK, name: profile.name)
                                    }) {
                                        HStack(spacing: 12) {
                                            // Selection indicator
                                            Image(systemName: settingsManager.selectedProfileId == profile.PK ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 16))
                                                .foregroundColor(settingsManager.selectedProfileId == profile.PK ? .blue : .gray)
                                            
                                            // Profile info
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack {
                                                    Text(profile.name)
                                                        .font(.system(size: 14, weight: .medium))
                                                        .foregroundColor(.primary)
                                                    
                                                    if let disableTTL = profile.disable_ttl, disableTTL > 0 {
                                                        Text("Disabled")
                                                            .font(.system(size: 10, weight: .medium))
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Capsule().fill(Color.red.opacity(0.15)))
                                                            .foregroundColor(.red)
                                                    }
                                                }
                                                
                                                Text("ID: \(profile.PK)")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(settingsManager.selectedProfileId == profile.PK ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(settingsManager.selectedProfileId == profile.PK ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                            
                            // Profile Management Actions (show when a profile is selected)
                            if !settingsManager.selectedProfileId.isEmpty,
                               let selectedProfile = settingsManager.availableProfiles.first(where: { $0.PK == settingsManager.selectedProfileId }) {
                                
                                Divider()
                                    .padding(.vertical, 8)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Profile Management")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Selected: \(selectedProfile.name)")
                                                .font(.system(size: 14, weight: .medium))
                                            
                                            if let disableTTL = selectedProfile.disable_ttl, disableTTL > 0 {
                                                Text("Currently disabled")
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                            } else {
                                                Text("Currently active")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // Enable/Disable button
                                        if let disableTTL = selectedProfile.disable_ttl, disableTTL > 0 {
                                            Button("Enable Profile") {
                                                enableProfile(selectedProfile)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .disabled(isProcessingProfile)
                                        } else {
                                            Button("Disable Profile") {
                                                showDurationPicker.toggle()
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.red)
                                            .disabled(isProcessingProfile)
                                        }
                                        
                                        if isProcessingProfile {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle())
                                                .scaleEffect(0.8)
                                        }
                                    }
                                    
                                    // Duration Selection (only show when disabling)
                                    if showDurationPicker && selectedProfile.disable_ttl == nil {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Divider()
                                            
                                            Text("Disable Duration")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            // Preset duration buttons
                                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                                                ForEach(Array(durationOptions.enumerated()), id: \.offset) { index, option in
                                                    Button(action: {
                                                        selectedDurationMinutes = option.minutes
                                                    }) {
                                                        VStack(spacing: 6) {
                                                            Image(systemName: option.icon)
                                                                .font(.system(size: 16))
                                                                .foregroundColor(selectedDurationMinutes == option.minutes ? .white : .blue)
                                                            
                                                            Text(option.name)
                                                                .font(.system(size: 12, weight: .medium))
                                                                .foregroundColor(selectedDurationMinutes == option.minutes ? .white : .primary)
                                                            
                                                            Text(formatDuration(option.minutes))
                                                                .font(.system(size: 10))
                                                                .foregroundColor(selectedDurationMinutes == option.minutes ? .white.opacity(0.8) : .secondary)
                                                        }
                                                        .frame(maxWidth: .infinity)
                                                        .padding(.vertical, 12)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .fill(selectedDurationMinutes == option.minutes ? Color.blue : Color.gray.opacity(0.1))
                                                        )
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            
                                            // Custom duration
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text("Custom:")
                                                    .font(.system(size: 14, weight: .medium))
                                                
                                                HStack(spacing: 12) {
                                                    Button(action: {
                                                        if customDurationMinutes > 0 {
                                                            customDurationMinutes -= 1
                                                        } else if customDurationHours > 0 {
                                                            customDurationHours -= 1
                                                            customDurationMinutes = 59
                                                        }
                                                        updateCustomDuration()
                                                    }) {
                                                        Image(systemName: "minus")
                                                    }
                                                    .buttonStyle(.plain)
                                                    .foregroundColor(.blue)
                                                    
                                                    Text("\(customDurationHours)h \(customDurationMinutes)m")
                                                        .font(.system(size: 14, design: .monospaced))
                                                        .frame(minWidth: 60)
                                                    
                                                    Button(action: {
                                                        customDurationMinutes += 1
                                                        if customDurationMinutes >= 60 {
                                                            customDurationHours += 1
                                                            customDurationMinutes = 0
                                                        }
                                                        if customDurationHours >= 24 {
                                                            customDurationHours = 23
                                                            customDurationMinutes = 59
                                                        }
                                                        updateCustomDuration()
                                                    }) {
                                                        Image(systemName: "plus")
                                                    }
                                                    .buttonStyle(.plain)
                                                    .foregroundColor(.blue)
                                                    
                                                    Spacer()
                                                }
                                            }
                                            
                                            // Action buttons
                                            HStack(spacing: 12) {
                                                Button("Cancel") {
                                                    showDurationPicker = false
                                                }
                                                .foregroundColor(.secondary)
                                                
                                                Spacer()
                                                
                                                Button("Disable for \(formatDuration(selectedDurationMinutes))") {
                                                    disableProfile(selectedProfile, durationMinutes: selectedDurationMinutes)
                                                    showDurationPicker = false
                                                }
                                                .buttonStyle(.borderedProminent)
                                                .tint(.red)
                                                .disabled(selectedDurationMinutes <= 0)
                                            }
                                        }
                                        .padding(.top, 8)
                                    }
                                    }
                                    
                                    if !profileActionMessage.isEmpty {
                                        Text(profileActionMessage)
                                            .font(.caption)
                                            .foregroundColor(profileActionMessage.contains("successfully") ? .green : .red)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            HStack {
                Button("Reset Settings") {
                    resetSettings()
                }
                .foregroundColor(.red)
                
                Spacer()
                
                Button("Save") {
                    saveSettings()
                    closeWindow()
                }
                .buttonStyle(.borderedProminent)
                .disabled(settingsManager.apiKey == nil || settingsManager.selectedProfileId.isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 600)
        .onAppear {
            // Load current API key if available
            if let apiKey = settingsManager.apiKey {
                apiKeyInput = apiKey
                isApiKeyMasked = true
                validationMessage = "✅ API key is valid"
                showValidationMessage = true
                // Auto-load profiles if we have a valid key
                loadProfiles()
            }
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
                        // Load profiles after successful validation
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
                print("🔄 Loading profiles...")
                let profiles = try await menuBarController.loadAvailableProfiles()
                print("✅ Loaded \(profiles.count) profiles")
                
                await MainActor.run {
                    isLoadingProfiles = false
                    print("🔄 About to update settingsManager.availableProfiles with \(profiles.count) profiles")
                    print("🔍 Profiles: \(profiles.map { "\($0.name) (\($0.PK))" }.joined(separator: ", "))")
                    
                    settingsManager.availableProfiles = profiles
                    
                    // Force UI update by triggering objectWillChange
                    settingsManager.objectWillChange.send()
                    
                    print("✅ Updated settingsManager.availableProfiles, current count: \(settingsManager.availableProfiles.count)")
                    
                    if profiles.isEmpty {
                        profilesError = "No profiles found. Make sure you have profiles configured in your ControlD account."
                    } else {
                        profilesError = ""
                        
                        // Auto-select if only one profile or restore previous selection
                        if profiles.count == 1 {
                            let profile = profiles[0]
                            settingsManager.saveSelectedProfile(id: profile.PK, name: profile.name)
                        } else if !settingsManager.selectedProfileId.isEmpty {
                            // Verify the previously selected profile still exists
                            if !profiles.contains(where: { $0.PK == settingsManager.selectedProfileId }) {
                                settingsManager.saveSelectedProfile(id: "", name: "")
                            }
                        }
                    }
                }
            } catch {
                print("❌ Error loading profiles: \(error)")
                await MainActor.run {
                    isLoadingProfiles = false
                    profilesError = "Failed to load profiles: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func saveSettings() {
        settingsManager.apiKey = apiKeyInput
        // The SettingsManager will notify observers via @Published properties
    }
    
    private func resetSettings() {
        settingsManager.resetSettings()
        apiKeyInput = ""
        validationMessage = ""
        showValidationMessage = false
        profilesError = ""
    }
    
    private func disableProfile(_ profile: ControlDService.Profile, durationMinutes: Int = 60) {
        isProcessingProfile = true
        profileActionMessage = ""
        
        Task {
            do {
                print("🔄 Disabling profile: \(profile.name) (\(profile.PK)) for \(durationMinutes) minutes")
                let success = try await menuBarController.disableProfile(profileId: profile.PK, durationInMinutes: durationMinutes)
                
                await MainActor.run {
                    isProcessingProfile = false
                    if success {
                        profileActionMessage = "✅ Profile '\(profile.name)' disabled for \(formatDuration(durationMinutes))"
                        // Refresh profiles to get updated status
                        loadProfiles()
                    } else {
                        profileActionMessage = "❌ Failed to disable profile"
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessingProfile = false
                    profileActionMessage = "❌ Error disabling profile: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func enableProfile(_ profile: ControlDService.Profile) {
        isProcessingProfile = true
        profileActionMessage = ""
        
        Task {
            do {
                print("🔄 Enabling profile: \(profile.name) (\(profile.PK))")
                let success = try await menuBarController.enableProfile(profileId: profile.PK)
                
                await MainActor.run {
                    isProcessingProfile = false
                    if success {
                        profileActionMessage = "✅ Profile '\(profile.name)' enabled successfully"
                        // Refresh profiles to get updated status
                        loadProfiles()
                    } else {
                        profileActionMessage = "❌ Failed to enable profile"
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessingProfile = false
                    profileActionMessage = "❌ Error enabling profile: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func closeWindow() {
        // Close the current window
        if let window = NSApplication.shared.keyWindow {
            window.close()
        }
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else if minutes % 60 == 0 {
            let hours = minutes / 60
            return "\(hours)h"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
    
    private func updateCustomDuration() {
        selectedDurationMinutes = customDurationHours * 60 + customDurationMinutes
    }
}

// MARK: - Profile Selection Component

struct ProfileSelectionView: View {
    let profiles: [ControlDService.Profile]
    let selectedProfileId: String
    let onProfileSelected: (ControlDService.Profile) -> Void
    
    @State private var searchText = ""
    @State private var isExpanded = false
    
    private var filteredProfiles: [ControlDService.Profile] {
        if searchText.isEmpty {
            return profiles
        } else {
            return profiles.filter { profile in
                profile.name.localizedCaseInsensitiveContains(searchText) ||
                profile.PK.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var selectedProfile: ControlDService.Profile? {
        profiles.first { $0.PK == selectedProfileId }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Current Selection Display
            if let selected = selectedProfile {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 12) {
                        // Profile Icon
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                        
                        // Profile Info
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(selected.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                if selected.disable_ttl != nil && selected.disable_ttl! > 0 {
                                    Text("Disabled")
                                        .font(.system(size: 9, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.red.opacity(0.15)))
                                        .foregroundColor(.red)
                                }
                            }
                            
                            Text("\(profiles.count) profile\(profiles.count == 1 ? "" : "s") available")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Expand/Collapse Icon
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            // Expanded Profile List
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Search Bar (only show if more than 3 profiles)
                    if profiles.count > 3 {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            TextField("Search profiles...", text: $searchText)
                                .font(.system(size: 13))
                                .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    
                    // Profile List
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(filteredProfiles, id: \.PK) { profile in
                                ProfileRowView(
                                    profile: profile,
                                    isSelected: profile.PK == selectedProfileId,
                                    onTap: {
                                        onProfileSelected(profile)
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isExpanded = false
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: min(CGFloat(filteredProfiles.count * 35), 140))
                    
                    if filteredProfiles.isEmpty && !searchText.isEmpty {
                        HStack {
                            Spacer()
                            Text("No profiles match '\(searchText)'")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        )
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
        }
    }
}

// MARK: - Profile Row Component

struct ProfileRowView: View {
    let profile: ControlDService.Profile
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                // Profile Name
                Text(profile.name)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // Status Badge
                if profile.disable_ttl != nil && profile.disable_ttl! > 0 {
                    Text("OFF")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red.opacity(0.2)))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

#Preview {
    SettingsView(settingsManager: SettingsManager(), menuBarController: MenuBarController())
}
