import Foundation
import Security

class SettingsManager: ObservableObject {
    @Published var selectedProfileId: String = ""
    @Published var selectedProfileName: String = ""
    @Published var availableProfiles: [ControlDService.Profile] = []
    
    private let keychainService = "com.controld.menubar"
    private let apiKeyAccount = "controld-api-key"
    
    // UserDefaults keys
    private let selectedProfileIdKey = "selectedProfileId"
    private let selectedProfileNameKey = "selectedProfileName"
    
    init() {
        loadSettings()
    }
    
    // MARK: - API Key Management (Keychain)
    
    var apiKey: String? {
        get {
            return getKeychainValue(account: apiKeyAccount)
        }
        set {
            if let key = newValue, !key.isEmpty {
                // Validate API key format before storing
                guard isValidApiKeyFormat(key) else {
                    print("⚠️ Invalid API key format - not storing")
                    return
                }
                setKeychainValue(key, account: apiKeyAccount)
            } else {
                deleteKeychainValue(account: apiKeyAccount)
            }
        }
    }
    
    /// Validates API key format without exposing the actual key
    private func isValidApiKeyFormat(_ key: String) -> Bool {
        // ControlD API keys should start with "api." and be of reasonable length
        return key.hasPrefix("api.") && key.count >= 20 && key.count <= 100
    }
    
    private func getKeychainValue(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    private func setKeychainValue(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { 
            print("⚠️ Failed to encode keychain value as UTF-8")
            return 
        }
        
        // Try to update first
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        
        if updateStatus == errSecItemNotFound {
            // Item doesn't exist, create it with enhanced security
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                // Enhanced security: Only accessible when device is unlocked and this device only
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                // Additional security: Mark as sensitive data
                kSecAttrLabel as String: "ControlD API Key",
                kSecAttrDescription as String: "Encrypted API key for ControlD service"
            ]
            
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                print("⚠️ Failed to add keychain item with status: \(addStatus)")
            }
        } else if updateStatus != errSecSuccess {
            print("⚠️ Failed to update keychain item with status: \(updateStatus)")
        }
    }
    
    private func deleteKeychainValue(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Profile Selection (UserDefaults)
    
    private func loadSettings() {
        selectedProfileId = UserDefaults.standard.string(forKey: selectedProfileIdKey) ?? ""
        selectedProfileName = UserDefaults.standard.string(forKey: selectedProfileNameKey) ?? ""
    }
    
    func saveSelectedProfile(id: String, name: String) {
        selectedProfileId = id
        selectedProfileName = name
        
        UserDefaults.standard.set(id, forKey: selectedProfileIdKey)
        UserDefaults.standard.set(name, forKey: selectedProfileNameKey)
    }
    
    // MARK: - Validation
    
    var hasValidApiKey: Bool {
        guard let key = apiKey, !key.isEmpty else { return false }
        return key.hasPrefix("api.") && key.count > 10
    }
    
    var hasSelectedProfile: Bool {
        return !selectedProfileId.isEmpty && !selectedProfileName.isEmpty
    }
    
    // MARK: - Reset
    
    func resetSettings() {
        apiKey = nil
        selectedProfileId = ""
        selectedProfileName = ""
        availableProfiles = []
        
        UserDefaults.standard.removeObject(forKey: selectedProfileIdKey)
        UserDefaults.standard.removeObject(forKey: selectedProfileNameKey)
    }
}
