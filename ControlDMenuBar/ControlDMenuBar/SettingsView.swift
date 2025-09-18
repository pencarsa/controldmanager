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
    
    var body: some View {
        ScrollView {
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
                                            Button("Disable Profile (30 min)") {
                                                disableProfile(selectedProfile, durationMinutes: 30)
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
        }
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
    
    // MARK: - Helper Functions
    
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
                    
                    settingsManager.availableProfiles = profiles
                    settingsManager.objectWillChange.send()
                    
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
    }
    
    private func resetSettings() {
        settingsManager.resetSettings()
        apiKeyInput = ""
        validationMessage = ""
        showValidationMessage = false
        profilesError = ""
    }
    
    private func disableProfile(_ profile: ControlDService.Profile, durationMinutes: Int = 60) {
        NSLog("🔄 DEBUG: disableProfile called with durationMinutes = \(durationMinutes)")
        NSLog("🔄 DEBUG: Profile: \(profile.name) (\(profile.PK))")
        isProcessingProfile = true
        profileActionMessage = ""
        
        Task {
            do {
                print("🔄 Disabling profile: \(profile.name) (\(profile.PK)) for \(durationMinutes) minutes")
                NSLog("🔄 DEBUG: Calling menuBarController.disableProfile with durationInMinutes: \(durationMinutes)")
                let success = try await menuBarController.disableProfile(profileId: profile.PK, durationInMinutes: durationMinutes)
                
                await MainActor.run {
                    isProcessingProfile = false
                    if success {
                        profileActionMessage = "✅ Profile '\(profile.name)' disabled for \(durationMinutes) minutes"
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
}

#Preview {
    SettingsView(settingsManager: SettingsManager(), menuBarController: MenuBarController())
}