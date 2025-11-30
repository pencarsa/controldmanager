import Foundation
import Security

/// Secure memory utilities for handling sensitive data
final class SecureMemory {
    
    // MARK: - Secure String Wrapper
    
    /// A string that zeros out its memory when deallocated
    final class SecureString {
        private var data: Data
        
        init(_ string: String) {
            self.data = string.data(using: .utf8) ?? Data()
        }
        
        var value: String {
            String(data: data, encoding: .utf8) ?? ""
        }
        
        func clear() {
            data.withUnsafeMutableBytes { ptr in
                memset(ptr.baseAddress, 0, ptr.count)
            }
            data = Data()
        }
        
        deinit {
            clear()
        }
    }
    
    // MARK: - Secure Operations
    
    /// Execute a closure with a secure string that is automatically cleared
    static func withSecureString<T>(_ string: String, operation: (SecureString) throws -> T) rethrows -> T {
        let secureString = SecureString(string)
        defer {
            secureString.clear()
        }
        return try operation(secureString)
    }
    
    /// Zero out memory for a string
    static func zeroOut(_ string: inout String) {
        if let data = string.data(using: .utf8) {
            var mutableData = data
            mutableData.withUnsafeMutableBytes { ptr in
                memset(ptr.baseAddress, 0, ptr.count)
            }
        }
        string = ""
    }
    
    /// Zero out memory for data
    static func zeroOut(_ data: inout Data) {
        data.withUnsafeMutableBytes { ptr in
            memset(ptr.baseAddress, 0, ptr.count)
        }
        data = Data()
    }
    
    /// Create a secure copy of data
    static func secureCopy(of data: Data) -> Data {
        var copy = Data(count: data.count)
        data.withUnsafeBytes { srcPtr in
            copy.withUnsafeMutableBytes { dstPtr in
                memcpy(dstPtr.baseAddress, srcPtr.baseAddress, data.count)
            }
        }
        return copy
    }
    
    /// Compare two pieces of data in constant time (prevents timing attacks)
    static func constantTimeCompare(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }
        
        var result: UInt8 = 0
        for i in 0..<lhs.count {
            result |= lhs[i] ^ rhs[i]
        }
        
        return result == 0
    }
    
    /// Compare two strings in constant time
    static func constantTimeCompare(_ lhs: String, _ rhs: String) -> Bool {
        guard let lhsData = lhs.data(using: .utf8),
              let rhsData = rhs.data(using: .utf8) else {
            return false
        }
        return constantTimeCompare(lhsData, rhsData)
    }
}

// MARK: - Secure Codable

/// Protocol for types that need secure encoding/decoding
protocol SecureCodable: Codable {
    /// Clear sensitive data from memory
    mutating func clearSensitiveData()
}

// MARK: - String Extension for Secure Handling

extension String {
    /// Create a redacted version for logging (shows only first/last few characters)
    var redacted: String {
        guard count > 8 else {
            return String(repeating: "*", count: count)
        }
        let prefix = String(prefix(4))
        let suffix = String(suffix(4))
        let middleLength = count - 8
        return "\(prefix)\(String(repeating: "*", count: middleLength))\(suffix)"
    }
    
    /// Validate that string doesn't contain obvious sensitive patterns
    var containsSensitiveData: Bool {
        let sensitivePatterns = [
            "password",
            "secret",
            "token",
            "key",
            "api",
            "auth"
        ]
        
        let lowercased = self.lowercased()
        return sensitivePatterns.contains { lowercased.contains($0) }
    }
}

// MARK: - Data Extension for Secure Handling

extension Data {
    /// Create a hexadecimal representation
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
    
    /// Create a redacted hex representation
    var redactedHex: String {
        guard count > 4 else {
            return String(repeating: "*", count: count * 2)
        }
        let prefix = self[0..<2].hexString
        let suffix = self[(count-2)..<count].hexString
        let middleLength = (count - 4) * 2
        return "\(prefix)\(String(repeating: "*", count: middleLength))\(suffix)"
    }
}

