import Foundation

/// Configuration service providing app-wide settings and constants
final class ConfigurationService: ConfigurationServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = ConfigurationService()
    
    private init() {}
    
    // MARK: - API Configuration
    
    var apiBaseURL: String {
        return "https://api.controld.com"
    }
    
    var defaultTimeout: TimeInterval {
        return 30.0
    }
    
    // MARK: - Security Configuration
    
    var keychainServiceName: String {
        return "com.controld.menubar"
    }
    
    // MARK: - Storage Configuration
    
    var userDefaultsPrefix: String {
        return "ControlD"
    }
    
    // MARK: - UI Configuration
    
    var settingsWindowSize: CGSize {
        return CGSize(width: 500, height: 550)
    }
    
    var popoverWidth: CGFloat {
        return 280
    }
    
    // MARK: - Timing Configuration
    
    var profileDisableDuration: TimeInterval {
        return 3600 // 1 hour
    }
    
    var refreshInterval: TimeInterval {
        return 60 // 1 minute
    }
    
    // MARK: - Validation Configuration
    
    var apiKeyMinLength: Int {
        return 10
    }
    
    var apiKeyPrefix: String {
        return "api."
    }
    
    // MARK: - Development Configuration
    
    var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    var shouldLogNetworkRequests: Bool {
        return isDebugMode
    }
}
