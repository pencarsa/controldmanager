import Foundation

// MARK: - Unified Error Hierarchy

/// Unified error type for the entire application
enum AppError: LocalizedError, Equatable {
    // Network errors
    case networkUnavailable
    case networkTimeout
    case networkError(String)
    
    // API errors
    case invalidApiKey
    case apiUnauthorized
    case apiNotFound
    case apiServerError(statusCode: Int, message: String)
    case apiRateLimited(retryAfter: TimeInterval?)
    
    // Configuration errors
    case configurationMissing
    case invalidConfiguration(String)
    case profileNotFound
    
    // Validation errors
    case invalidInput(field: String, reason: String)
    case validationFailed(String)
    
    // Security errors
    case keychainError(String)
    case authenticationFailed
    case biometricUnavailable
    case biometricFailed
    
    // Data errors
    case cacheMiss
    case decodingError(String)
    case encodingError(String)
    
    // MARK: - LocalizedError
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network is unavailable"
        case .networkTimeout:
            return "Network request timed out"
        case .networkError(let message):
            return "Network error: \(message)"
            
        case .invalidApiKey:
            return "Invalid API key"
        case .apiUnauthorized:
            return "API authentication failed"
        case .apiNotFound:
            return "Resource not found"
        case .apiServerError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .apiRateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limited. Please retry after \(Int(retryAfter)) seconds"
            }
            return "Rate limited. Please try again later"
            
        case .configurationMissing:
            return "Configuration is incomplete"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        case .profileNotFound:
            return "Selected profile not found"
            
        case .invalidInput(let field, let reason):
            return "Invalid \(field): \(reason)"
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
            
        case .keychainError(let message):
            return "Keychain error: \(message)"
        case .authenticationFailed:
            return "Authentication failed"
        case .biometricUnavailable:
            return "Biometric authentication is not available"
        case .biometricFailed:
            return "Biometric authentication failed"
            
        case .cacheMiss:
            return "Cached data not available"
        case .decodingError(let message):
            return "Failed to decode data: \(message)"
        case .encodingError(let message):
            return "Failed to encode data: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Please check your internet connection and try again"
        case .networkTimeout:
            return "Please check your internet connection or try again later"
        case .networkError:
            return "Please verify your network connection"
            
        case .invalidApiKey:
            return "Please check your API key in settings"
        case .apiUnauthorized:
            return "Please verify your API key in settings"
        case .apiNotFound:
            return "The requested resource may have been deleted or moved"
        case .apiServerError:
            return "Please try again later or contact support"
        case .apiRateLimited:
            return "Please wait a moment before trying again"
            
        case .configurationMissing:
            return "Please complete the configuration in settings"
        case .invalidConfiguration:
            return "Please review your settings"
        case .profileNotFound:
            return "Please select a valid profile from settings"
            
        case .invalidInput:
            return "Please correct the input and try again"
        case .validationFailed:
            return "Please check your input and try again"
            
        case .keychainError:
            return "Please try resetting your settings"
        case .authenticationFailed:
            return "Please try authenticating again"
        case .biometricUnavailable:
            return "Please use manual authentication"
        case .biometricFailed:
            return "Please try again or use manual authentication"
            
        case .cacheMiss:
            return "Data will be fetched from the server"
        case .decodingError, .encodingError:
            return "Please try again or contact support if the issue persists"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .networkUnavailable:
            return "The device is not connected to the internet"
        case .networkTimeout:
            return "The request took too long to complete"
        case .networkError(let message):
            return message
            
        case .invalidApiKey:
            return "The API key format is invalid or expired"
        case .apiUnauthorized:
            return "The API key is not authorized for this operation"
        case .apiNotFound:
            return "The server could not find the requested resource"
        case .apiServerError(_, let message):
            return message
        case .apiRateLimited:
            return "Too many requests have been made"
            
        case .configurationMissing:
            return "Required configuration settings are not set"
        case .invalidConfiguration(let reason):
            return reason
        case .profileNotFound:
            return "The profile does not exist or has been deleted"
            
        case .invalidInput(_, let reason):
            return reason
        case .validationFailed(let reason):
            return reason
            
        case .keychainError(let message):
            return message
        case .authenticationFailed:
            return "Unable to verify identity"
        case .biometricUnavailable:
            return "Face ID or Touch ID is not configured on this device"
        case .biometricFailed:
            return "The biometric authentication did not succeed"
            
        case .cacheMiss:
            return "The requested data is not in the cache"
        case .decodingError(let message):
            return message
        case .encodingError(let message):
            return message
        }
    }
    
    // MARK: - Recovery Actions
    
    var recoveryAction: RecoveryAction? {
        switch self {
        case .networkUnavailable, .networkTimeout, .networkError:
            return .retry
        case .invalidApiKey, .apiUnauthorized:
            return .reconfigure
        case .apiServerError, .apiRateLimited:
            return .retryLater
        case .configurationMissing, .invalidConfiguration:
            return .configure
        case .profileNotFound:
            return .selectProfile
        case .keychainError:
            return .resetSettings
        case .cacheMiss:
            return .fetchFresh
        default:
            return nil
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .networkTimeout, .networkError,
             .apiServerError, .apiRateLimited:
            return true
        default:
            return false
        }
    }
}

// MARK: - Recovery Actions

enum RecoveryAction {
    case retry
    case retryLater
    case reconfigure
    case configure
    case selectProfile
    case resetSettings
    case fetchFresh
    case contactSupport
    
    var actionTitle: String {
        switch self {
        case .retry:
            return "Retry"
        case .retryLater:
            return "Try Again Later"
        case .reconfigure:
            return "Update API Key"
        case .configure:
            return "Open Settings"
        case .selectProfile:
            return "Select Profile"
        case .resetSettings:
            return "Reset Settings"
        case .fetchFresh:
            return "Refresh"
        case .contactSupport:
            return "Contact Support"
        }
    }
}

// MARK: - Error Extension for Conversion

extension Error {
    /// Convert any error to AppError
    func toAppError() -> AppError {
        if let appError = self as? AppError {
            return appError
        }
        
        let nsError = self as NSError
        
        // Network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return .networkUnavailable
            case NSURLErrorTimedOut:
                return .networkTimeout
            default:
                return .networkError(nsError.localizedDescription)
            }
        }
        
        // Keychain errors
        if nsError.domain == NSOSStatusErrorDomain {
            return .keychainError("Keychain operation failed with code: \(nsError.code)")
        }
        
        // Generic error
        return .networkError(localizedDescription)
    }
}

