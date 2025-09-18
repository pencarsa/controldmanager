import Foundation
import Combine

/// Enhanced settings service with dependency injection and better separation of concerns
final class SettingsService: SettingsServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published var selectedProfileId: String = ""
    @Published var selectedProfileName: String = ""
    @Published var availableProfiles: [Profile] = []
    
    // MARK: - Dependencies
    
    private let keychainService: KeychainServiceProtocol
    private let configuration: ConfigurationServiceProtocol
    private let logger: LoggerProtocol
    
    // MARK: - Constants
    
    private struct Keys {
        static let apiKey = "controld-api-key"
        static let selectedProfileId = "selectedProfileId"
        static let selectedProfileName = "selectedProfileName"
    }
    
    // MARK: - Initialization
    
    init(keychainService: KeychainServiceProtocol,
         configuration: ConfigurationServiceProtocol = ConfigurationService.shared,
         logger: LoggerProtocol = LoggingService.shared) {
        self.keychainService = keychainService
        self.configuration = configuration
        self.logger = logger
        
        loadSettings()
    }
    
    // MARK: - API Key Management
    
    var apiKey: String? {
        get {
            return keychainService.getValue(for: Keys.apiKey)
        }
        set {
            do {
                if let key = newValue, !key.isEmpty {
                    try keychainService.setValue(key, for: Keys.apiKey)
                    logger.info("API key saved to keychain")
                } else {
                    try keychainService.deleteValue(for: Keys.apiKey)
                    logger.info("API key removed from keychain")
                }
            } catch {
                logger.error("Failed to update API key in keychain: \(error.localizedDescription)")
            }
        }
    }
    
    var hasValidApiKey: Bool {
        guard let key = apiKey, !key.isEmpty else {
            return false
        }
        
        return key.hasPrefix(configuration.apiKeyPrefix) && key.count > configuration.apiKeyMinLength
    }
    
    // MARK: - Profile Management
    
    var hasSelectedProfile: Bool {
        return !selectedProfileId.isEmpty && !selectedProfileName.isEmpty
    }
    
    func saveSelectedProfile(id: String, name: String) {
        logger.info("Saving selected profile: \(name) (\(id))")
        
        selectedProfileId = id
        selectedProfileName = name
        
        let userDefaults = UserDefaults.standard
        userDefaults.set(id, forKey: prefixedKey(Keys.selectedProfileId))
        userDefaults.set(name, forKey: prefixedKey(Keys.selectedProfileName))
        
        logger.debug("Profile selection saved to UserDefaults")
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        logger.debug("Loading settings from storage")
        
        let userDefaults = UserDefaults.standard
        selectedProfileId = userDefaults.string(forKey: prefixedKey(Keys.selectedProfileId)) ?? ""
        selectedProfileName = userDefaults.string(forKey: prefixedKey(Keys.selectedProfileName)) ?? ""
        
        logger.debug("Settings loaded - Profile: \(selectedProfileName) (\(selectedProfileId))")
    }
    
    func resetSettings() {
        logger.info("Resetting all settings")
        
        // Clear API key from keychain
        apiKey = nil
        
        // Clear profile selection
        selectedProfileId = ""
        selectedProfileName = ""
        availableProfiles = []
        
        // Clear UserDefaults
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: prefixedKey(Keys.selectedProfileId))
        userDefaults.removeObject(forKey: prefixedKey(Keys.selectedProfileName))
        
        logger.info("All settings have been reset")
    }
    
    // MARK: - Validation
    
    func validateConfiguration() -> ValidationResult {
        var issues: [String] = []
        
        if !hasValidApiKey {
            issues.append("API key is missing or invalid")
        }
        
        if !hasSelectedProfile {
            issues.append("Profile selection is required")
        }
        
        if availableProfiles.isEmpty && hasValidApiKey {
            issues.append("No profiles available - check API key")
        }
        
        if !selectedProfileId.isEmpty && !availableProfiles.contains(where: { $0.id == selectedProfileId }) {
            issues.append("Selected profile is no longer available")
        }
        
        return ValidationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Private Helpers
    
    private func prefixedKey(_ key: String) -> String {
        return "\(configuration.userDefaultsPrefix).\(key)"
    }
}

// MARK: - Supporting Types

struct ValidationResult {
    let isValid: Bool
    let issues: [String]
    
    var errorMessage: String? {
        guard !isValid else { return nil }
        return issues.joined(separator: "\n")
    }
}
