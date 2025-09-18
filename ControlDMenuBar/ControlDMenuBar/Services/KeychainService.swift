import Foundation
import Security

/// Secure keychain service for storing sensitive data
final class KeychainService: KeychainServiceProtocol {
    
    // MARK: - Properties
    
    private let serviceName: String
    private let logger: LoggerProtocol
    
    // MARK: - Initialization
    
    init(serviceName: String, logger: LoggerProtocol = LoggingService.shared) {
        self.serviceName = serviceName
        self.logger = logger
    }
    
    // MARK: - KeychainServiceProtocol
    
    func getValue(for key: String) -> String? {
        logger.debug("Retrieving keychain value for key: \(key)")
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                logger.warning("Failed to decode keychain data for key: \(key)")
                return nil
            }
            logger.debug("Successfully retrieved keychain value for key: \(key)")
            return string
            
        case errSecItemNotFound:
            logger.debug("Keychain item not found for key: \(key)")
            return nil
            
        default:
            logger.error("Keychain error when retrieving key \(key): \(status)")
            return nil
        }
    }
    
    func setValue(_ value: String, for key: String) throws {
        logger.debug("Setting keychain value for key: \(key)")
        
        guard let data = value.data(using: .utf8) else {
            throw AppError.keychainError("Failed to encode value to data")
        }
        
        // Try to update existing item first
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        
        switch updateStatus {
        case errSecSuccess:
            logger.debug("Successfully updated keychain value for key: \(key)")
            return
            
        case errSecItemNotFound:
            // Item doesn't exist, create it
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            
            if addStatus == errSecSuccess {
                logger.debug("Successfully added keychain value for key: \(key)")
            } else {
                logger.error("Failed to add keychain item for key \(key): \(addStatus)")
                throw AppError.keychainError("Failed to add keychain item (status: \(addStatus))")
            }
            
        default:
            logger.error("Failed to update keychain item for key \(key): \(updateStatus)")
            throw AppError.keychainError("Failed to update keychain item (status: \(updateStatus))")
        }
    }
    
    func deleteValue(for key: String) throws {
        logger.debug("Deleting keychain value for key: \(key)")
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        switch status {
        case errSecSuccess:
            logger.debug("Successfully deleted keychain value for key: \(key)")
            
        case errSecItemNotFound:
            logger.debug("Keychain item not found for deletion (key: \(key))")
            // Not an error - item was already not there
            
        default:
            logger.error("Failed to delete keychain item for key \(key): \(status)")
            throw AppError.keychainError("Failed to delete keychain item (status: \(status))")
        }
    }
}
