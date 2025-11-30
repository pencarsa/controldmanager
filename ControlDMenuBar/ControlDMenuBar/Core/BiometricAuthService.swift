import Foundation
import LocalAuthentication

/// Service for biometric authentication (Face ID / Touch ID)
final class BiometricAuthService {
    
    // MARK: - Biometric Type
    
    enum BiometricType {
        case faceID
        case touchID
        case none
        
        var displayName: String {
            switch self {
            case .faceID:
                return "Face ID"
            case .touchID:
                return "Touch ID"
            case .none:
                return "None"
            }
        }
    }
    
    // MARK: - Authentication Result
    
    enum AuthenticationResult {
        case success
        case failure(BiometricError)
        case cancelled
    }
    
    enum BiometricError: LocalizedError {
        case notAvailable
        case notEnrolled
        case lockout
        case systemCancel
        case failed
        case unknown(Error)
        
        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "Biometric authentication is not available on this device"
            case .notEnrolled:
                return "No biometric data is enrolled. Please set up Face ID or Touch ID in System Preferences"
            case .lockout:
                return "Biometric authentication is locked out due to too many failed attempts"
            case .systemCancel:
                return "Biometric authentication was cancelled by the system"
            case .failed:
                return "Biometric authentication failed"
            case .unknown(let error):
                return "Biometric authentication error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Properties
    
    private let context = LAContext()
    
    // Singleton
    static let shared = BiometricAuthService()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Availability
    
    /// Check if biometric authentication is available
    func isAvailable() -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Get the type of biometric authentication available
    func biometricType() -> BiometricType {
        guard isAvailable() else {
            return .none
        }
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }
    
    // MARK: - Authentication
    
    /// Authenticate using biometrics
    func authenticate(reason: String = "Authenticate to access ControlD") async -> AuthenticationResult {
        // Check availability first
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                return .failure(mapError(error))
            }
            return .failure(.notAvailable)
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            return success ? .success : .failure(.failed)
        } catch let error as LAError {
            return .failure(mapLAError(error))
        } catch {
            return .failure(.unknown(error))
        }
    }
    
    /// Authenticate with fallback to password
    func authenticateWithFallback(reason: String = "Authenticate to access ControlD") async -> AuthenticationResult {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let error = error {
                return .failure(mapError(error))
            }
            return .failure(.notAvailable)
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            
            return success ? .success : .failure(.failed)
        } catch let error as LAError {
            return .failure(mapLAError(error))
        } catch {
            return .failure(.unknown(error))
        }
    }
    
    // MARK: - Error Mapping
    
    private func mapLAError(_ error: LAError) -> BiometricError {
        switch error.code {
        case .authenticationFailed:
            return .failed
        case .userCancel:
            return .cancelled
        case .systemCancel:
            return .systemCancel
        case .biometryNotAvailable:
            return .notAvailable
        case .biometryNotEnrolled:
            return .notEnrolled
        case .biometryLockout:
            return .lockout
        default:
            return .unknown(error)
        }
    }
    
    private func mapError(_ error: NSError) -> BiometricError {
        if let laError = error as? LAError {
            return mapLAError(laError)
        }
        return .unknown(error)
    }
    
    // MARK: - Configuration
    
    /// Invalidate current authentication context
    func invalidate() {
        context.invalidate()
    }
}

// MARK: - Convenience Extensions

extension BiometricAuthService {
    /// Quick check with Result type
    func authenticateWithResult(reason: String = "Authenticate to access ControlD") async -> Result<Void, BiometricError> {
        let result = await authenticate(reason: reason)
        switch result {
        case .success:
            return .success(())
        case .failure(let error):
            return .failure(error)
        case .cancelled:
            return .failure(.systemCancel)
        }
    }
}

