import Foundation

class ControlDService {
    private let baseURL = "https://api.controld.com"
    weak var settingsManager: SettingsManager?
    
    // MARK: - Security Configuration
    
    /// Secure URLSession with enhanced security configuration
    private lazy var secureSession: URLSession = {
        let config = URLSessionConfiguration.default
        
        // Security timeouts
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        
        // Security headers
        config.httpAdditionalHeaders = [
            "User-Agent": "ControlD-MenuBar/1.0",
            "Accept": "application/json"
        ]
        
        // Enhanced security
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        config.waitsForConnectivity = false
        
        return URLSession(configuration: config)
    }()
    
    private var apiToken: String? {
        return settingsManager?.apiKey
    }
    
    /// Validates that the API token is present and properly formatted
    private func validateApiToken() throws -> String {
        guard let token = apiToken, !token.isEmpty else {
            throw ControlDError.invalidToken
        }
        
        // Additional security: Validate token format
        guard token.hasPrefix("api.") && token.count >= 20 else {
            throw ControlDError.invalidToken
        }
        
        return token
    }
    
    enum ControlDError: Error, LocalizedError {
        case invalidToken
        case networkError(String)
        case profileNotFound
        case endpointNotFound
        case apiError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidToken:
                return "Invalid API token"
            case .networkError(let message):
                return "Network error: \(message)"
            case .profileNotFound:
                return "Profile 'YourProfile' not found"
            case .endpointNotFound:
                return "Endpoint 'YourEndpoint' not found"
            case .apiError(let message):
                return "API error: \(message)"
            }
        }
    }
    
    struct Profile: Codable {
        let PK: String  // Changed to String as shown in API response
        let name: String
        let updated: Int
        let disable_ttl: Int? // Unix timestamp when disable expires
        let profile: ProfileData?
    }
    
    struct ProfileData: Codable {
        // The actual profile data structure from API
        let flt: FilterCount?
        let cflt: FilterCount?
        let ipflt: FilterCount?
        let rule: FilterCount?
        let svc: FilterCount?
        let grp: FilterCount?
        let opt: OptionData?
        let da: DataAccessInfo?
    }
    
    struct FilterCount: Codable {
        let count: Int
    }
    
    struct OptionData: Codable {
        let count: Int
        let data: [OptionItem]?
    }
    
    struct OptionItem: Codable {
        let PK: String
        let value: Double
    }
    
    struct DataAccessInfo: Codable {
        let `do`: Int
        let status: Int
    }
    
    struct ProfilesResponse: Codable {
        let body: ProfilesBody
        let success: Bool
    }
    
    struct ProfilesBody: Codable {
        let profiles: [Profile]
    }
    
    struct Rule: Codable {
        let PK: String
        let order: Int
        let group: Int
        let action: RuleAction
        let comment: String?
    }
    
    struct RuleAction: Codable {
        let `do`: Int
        let status: Int
        let via: String?
    }
    
    struct RulesResponse: Codable {
        let body: RulesBody
        let success: Bool
    }
    
    struct RulesBody: Codable {
        let rules: [Rule]
    }
    
    struct DisableResponse: Codable {
        let body: DisableBody?
        let success: Bool
    }
    
    struct DisableBody: Codable {
        let message: String?
    }
    
    init() {
        // API token now comes from settings manager
        print("🛡️ ControlD service initialized with enhanced security")
    }
    
    deinit {
        // Clean up secure session
        secureSession.invalidateAndCancel()
    }
    
    func validateConnection() async throws -> Bool {
        let token = try validateApiToken()
        
        // Test connection by fetching profiles
        guard let url = URL(string: "\(baseURL)/profiles") else {
            throw ControlDError.networkError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (_, response) = try await secureSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ControlDError.networkError("Invalid response")
            }
            
            if httpResponse.statusCode == 200 {
                return true
            } else {
                throw ControlDError.apiError("HTTP \(httpResponse.statusCode)")
            }
        } catch {
            throw ControlDError.networkError(error.localizedDescription)
        }
    }
    
    func disableWorkMacEndpoint() async throws -> Bool {
        guard let token = apiToken, !token.isEmpty else {
            throw ControlDError.invalidToken
        }
        
        guard let settings = settingsManager else {
            throw ControlDError.apiError("Settings manager not available")
        }
        
        guard settings.hasSelectedProfile else {
            throw ControlDError.profileNotFound
        }
        
        print("🔍 Connecting to ControlD API...")
        
        // Step 1: Get profiles and find the selected profile
        let profiles = try await fetchProfiles()
        guard let selectedProfile = profiles.first(where: { $0.PK == settings.selectedProfileId }) else {
            throw ControlDError.profileNotFound
        }
        
        print("✅ Found selected profile '\(selectedProfile.name)': \(selectedProfile.PK)")
        
        // Step 2: Check if profile is already disabled
        if let _ = selectedProfile.disable_ttl {
            print("🔄 Profile is currently disabled, re-enabling it...")
            return try await enableProfile(profileId: selectedProfile.PK)
        } else {
            print("🎯 Disabling profile '\(selectedProfile.name)' for 1 hour...")
            return try await disableProfile(profileId: selectedProfile.PK)
        }
    }
    
    private func fetchProfiles() async throws -> [Profile] {
        let token = try validateApiToken()
        
        // Use the correct endpoint from ControlD API documentation
        guard let url = URL(string: "\(baseURL)/profiles") else {
            throw ControlDError.networkError("Invalid URL")
        }
        
        print("🔍 Fetching profiles from ControlD API: \(url)")
        print("🔑 Using token: \(String(token.prefix(10)))...")
        
        return try await fetchProfilesFromURL(url: url, token: token)
    }
    
    private func fetchProfilesFromURL(url: URL, token: String) async throws -> [Profile] {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🔍 Fetching profiles from: \(url)")
        print("🔑 Using token: \(String(token.prefix(10)))...")
        
        do {
            let (data, response) = try await secureSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ControlDError.networkError("Invalid response")
            }
            
            print("📡 Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                print("❌ API Error Response: \(responseString)")
                throw ControlDError.apiError("HTTP \(httpResponse.statusCode): \(responseString)")
            }
            
            // Debug: Print raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Raw API Response: \(responseString)")
            }
            
            // Try to decode the response
            do {
                let profilesResponse = try JSONDecoder().decode(ProfilesResponse.self, from: data)
                print("✅ Successfully decoded \(profilesResponse.body.profiles.count) profiles")
                
                if profilesResponse.body.profiles.isEmpty {
                    print("⚠️  No profiles found in response")
                }
                
                return profilesResponse.body.profiles
            } catch {
                print("❌ Failed to decode as ProfilesResponse: \(error)")
                
                // Try to decode as a simpler structure to understand the response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📄 Response structure: \(json)")
                    
                    // Check if it's a different structure
                    if let profiles = json["profiles"] as? [[String: Any]] {
                        print("🔍 Found profiles in different structure: \(profiles.count) profiles")
                        // Try to extract profiles manually
                        var extractedProfiles: [Profile] = []
                        for profileDict in profiles {
                            if let pk = profileDict["PK"] as? String,
                               let name = profileDict["name"] as? String {
                                let profile = Profile(
                                    PK: pk,
                                    name: name,
                                    updated: profileDict["updated"] as? Int ?? 0,
                                    disable_ttl: profileDict["disable_ttl"] as? Int,
                                    profile: nil
                                )
                                extractedProfiles.append(profile)
                            }
                        }
                        if !extractedProfiles.isEmpty {
                            print("✅ Successfully extracted \(extractedProfiles.count) profiles manually")
                            return extractedProfiles
                        }
                    }
                }
                
                throw error
            }
            
        } catch let decodingError as DecodingError {
            print("❌ Decoding error: \(decodingError)")
            throw ControlDError.apiError("Failed to decode response: \(decodingError)")
        } catch {
            print("❌ Network error: \(error)")
            throw ControlDError.networkError(error.localizedDescription)
        }
    }
    
    func disableProfile(profileId: String, durationInMinutes: Int = 60) async throws -> Bool {
        let token = try validateApiToken()
        
        print("🔄 Disabling profile with API call for \(durationInMinutes) minutes...")
        
        // Sanitize profile ID to prevent injection
        let sanitizedProfileId = profileId.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
        guard !sanitizedProfileId.isEmpty else {
            throw ControlDError.apiError("Invalid profile ID")
        }
        
        guard let url = URL(string: "\(baseURL)/profiles/\(sanitizedProfileId)") else {
            throw ControlDError.networkError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Set the disable_ttl to specified duration from now
        let durationInSeconds = durationInMinutes * 60
        let disableUntil = Int(Date().timeIntervalSince1970) + durationInSeconds
        let requestBody = [
            "disable_ttl": disableUntil
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw ControlDError.apiError("Failed to encode request body")
        }
        
        do {
            let (data, response) = try await secureSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ControlDError.networkError("Invalid response")
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                // Parse response to verify success
                if let responseString = String(data: data, encoding: .utf8) {
                    print("✅ API Response: \(responseString)")
                }
                
                if let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = jsonResponse["success"] as? Bool {
                    return success
                }
                return true
            } else {
                // Print response for debugging (without exposing sensitive data)
                print("❌ API Error Response: HTTP \(httpResponse.statusCode)")
                throw ControlDError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
        } catch {
            throw ControlDError.networkError(error.localizedDescription)
        }
    }
    
    func enableProfile(profileId: String) async throws -> Bool {
        guard let token = apiToken else {
            throw ControlDError.invalidToken
        }
        
        print("🔄 Re-enabling profile (canceling disable timer)...")
        
        // Cancel the disable by setting disable_ttl to 0
        let url = URL(string: "\(baseURL)/profiles/\(profileId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Set disable_ttl to 0 to cancel the disable timer
        let requestBody = [
            "disable_ttl": 0
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ControlDError.networkError("Invalid response")
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                // Parse response to verify success
                if let responseString = String(data: data, encoding: .utf8) {
                    print("✅ API Response: \(responseString)")
                }
                
                if let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = jsonResponse["success"] as? Bool {
                    return success
                }
                return true
            } else {
                // Print response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ API Error Response: \(responseString)")
                }
                throw ControlDError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
        } catch {
            throw ControlDError.networkError(error.localizedDescription)
        }
    }
    
    private func fetchRules(profileId: String) async throws -> [Rule] {
        guard let token = apiToken else {
            throw ControlDError.invalidToken
        }
        
        let url = URL(string: "\(baseURL)/profiles/\(profileId)/rules")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ControlDError.networkError("Invalid response")
            }
            
            if httpResponse.statusCode != 200 {
                throw ControlDError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            let rulesResponse = try JSONDecoder().decode(RulesResponse.self, from: data)
            return rulesResponse.body.rules
            
        } catch let decodingError as DecodingError {
            throw ControlDError.apiError("Failed to decode rules response: \(decodingError)")
        } catch {
            throw ControlDError.networkError(error.localizedDescription)
        }
    }
    
    private func disableRule(profileId: String, ruleName: String) async throws -> Bool {
        guard let token = apiToken else {
            throw ControlDError.invalidToken
        }
        
        print("🔄 Attempting to disable rule: \(ruleName)")
        
        // Try to modify the rule status to disable it temporarily
        let url = URL(string: "\(baseURL)/profiles/\(profileId)/rules/\(ruleName)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Set the rule to disabled status (status: 0)
        let requestBody = [
            "action": [
                "do": 0,
                "status": 0
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ControlDError.networkError("Invalid response")
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                print("✅ Successfully disabled rule: \(ruleName)")
                return true
            } else {
                // Print response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 API Response: \(responseString)")
                }
                throw ControlDError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
        } catch {
            throw ControlDError.networkError(error.localizedDescription)
        }
    }
    
    func getProfileStatus() async throws -> String {
        guard let settings = settingsManager, settings.hasSelectedProfile else {
            return "Unknown"
        }
        
        let profiles = try await fetchProfiles()
        guard let selectedProfile = profiles.first(where: { $0.PK == settings.selectedProfileId }) else {
            throw ControlDError.profileNotFound
        }
        
        if let disable_ttl = selectedProfile.disable_ttl {
            let currentTime = Int(Date().timeIntervalSince1970)
            if disable_ttl > currentTime {
                return "Disabled"
            } else {
                return "Enabled" // TTL expired
            }
        } else {
            return "Enabled"
        }
    }
    
    func validateApiKey(_ apiKey: String) async throws -> Bool {
        // Validate API key format first
        guard apiKey.hasPrefix("api.") && apiKey.count >= 20 && apiKey.count <= 100 else {
            return false
        }
        
        guard let url = URL(string: "\(baseURL)/profiles") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (_, response) = try await secureSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }
    
    func fetchAllProfiles() async throws -> [Profile] {
        return try await fetchProfiles()
    }
}
