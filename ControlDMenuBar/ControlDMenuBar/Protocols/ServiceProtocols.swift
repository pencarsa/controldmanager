import Foundation

// MARK: - Core Service Protocols

/// Protocol for API service operations
protocol APIServiceProtocol: AnyObject {
    func validateConnection() async throws -> Bool
    func validateApiKey(_ apiKey: String) async throws -> Bool
    func fetchAllProfiles() async throws -> [Profile]
    func getProfileStatus(profileId: String) async throws -> ProfileStatus
    func toggleProfileDisable(profileId: String) async throws -> Bool
}

/// Protocol for settings management
protocol SettingsServiceProtocol: ObservableObject {
    var selectedProfileId: String { get set }
    var selectedProfileName: String { get set }
    var availableProfiles: [Profile] { get set }
    var apiKey: String? { get set }
    var hasValidApiKey: Bool { get }
    var hasSelectedProfile: Bool { get }
    
    func saveSelectedProfile(id: String, name: String)
    func resetSettings()
}

/// Protocol for keychain operations
protocol KeychainServiceProtocol: AnyObject {
    func getValue(for key: String) -> String?
    func setValue(_ value: String, for key: String) throws
    func deleteValue(for key: String) throws
}

/// Protocol for configuration management
protocol ConfigurationServiceProtocol: AnyObject {
    var apiBaseURL: String { get }
    var keychainServiceName: String { get }
    var userDefaultsPrefix: String { get }
    var defaultTimeout: TimeInterval { get }
}

/// Protocol for logging
protocol LoggerProtocol: AnyObject {
    func debug(_ message: String, file: String, function: String, line: Int)
    func info(_ message: String, file: String, function: String, line: Int)
    func warning(_ message: String, file: String, function: String, line: Int)
    func error(_ message: String, file: String, function: String, line: Int)
}

// MARK: - Data Models

struct Profile: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let updated: Int
    let disableTTL: Int?
    
    enum CodingKeys: String, CodingKey {
        case id = "PK"
        case name
        case updated
        case disableTTL = "disable_ttl"
    }
}

struct ProfileStatus: Equatable {
    let isEnabled: Bool
    let disableExpiresAt: Date?
    
    var statusDescription: String {
        if isEnabled {
            return "Enabled"
        } else if let expiresAt = disableExpiresAt, expiresAt > Date() {
            return "Disabled"
        } else {
            return "Enabled" // TTL expired
        }
    }
}

// MARK: - Error Types

enum AppError: LocalizedError, Equatable {
    case invalidApiKey
    case networkError(String)
    case profileNotFound
    case configurationMissing
    case keychainError(String)
    case apiError(String, statusCode: Int)
    case validationError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidApiKey:
            return "Invalid API key provided"
        case .networkError(let message):
            return "Network error: \(message)"
        case .profileNotFound:
            return "Selected profile not found"
        case .configurationMissing:
            return "Configuration is incomplete"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        case .apiError(let message, let statusCode):
            return "API error (\(statusCode)): \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidApiKey:
            return "Please check your API key and try again"
        case .networkError:
            return "Please check your internet connection"
        case .profileNotFound:
            return "Please select a valid profile from settings"
        case .configurationMissing:
            return "Please complete the configuration in settings"
        case .keychainError:
            return "Please try resetting your settings"
        case .apiError:
            return "Please try again later or contact support"
        case .validationError:
            return "Please check your input and try again"
        }
    }
}
