import XCTest
@testable import ControlD

final class SecureMemoryTests: XCTestCase {
    
    func testSecureStringClearing() {
        let secureString = SecureMemory.SecureString("sensitive_data")
        
        XCTAssertEqual(secureString.value, "sensitive_data")
        
        secureString.clear()
        XCTAssertEqual(secureString.value, "")
    }
    
    func testWithSecureString() {
        let result = SecureMemory.withSecureString("test_data") { secureString in
            return secureString.value.uppercased()
        }
        
        XCTAssertEqual(result, "TEST_DATA")
    }
    
    func testZeroOutString() {
        var sensitiveString = "password123"
        SecureMemory.zeroOut(&sensitiveString)
        
        XCTAssertEqual(sensitiveString, "")
    }
    
    func testConstantTimeCompare() {
        let str1 = "test123"
        let str2 = "test123"
        let str3 = "test456"
        
        XCTAssertTrue(SecureMemory.constantTimeCompare(str1, str2))
        XCTAssertFalse(SecureMemory.constantTimeCompare(str1, str3))
    }
    
    func testConstantTimeCompareData() {
        let data1 = Data([1, 2, 3, 4])
        let data2 = Data([1, 2, 3, 4])
        let data3 = Data([1, 2, 3, 5])
        
        XCTAssertTrue(SecureMemory.constantTimeCompare(data1, data2))
        XCTAssertFalse(SecureMemory.constantTimeCompare(data1, data3))
    }
    
    func testStringRedaction() {
        let apiKey = "api.1234567890abcdef"
        let redacted = apiKey.redacted
        
        XCTAssertTrue(redacted.contains("****"))
        XCTAssertTrue(redacted.hasPrefix("api."))
        XCTAssertTrue(redacted.hasSuffix("cdef"))
    }
    
    func testShortStringRedaction() {
        let short = "test"
        let redacted = short.redacted
        
        XCTAssertEqual(redacted, "****")
    }
    
    func testSensitiveDataDetection() {
        XCTAssertTrue("my_password_here".containsSensitiveData)
        XCTAssertTrue("api_token".containsSensitiveData)
        XCTAssertTrue("secret_key".containsSensitiveData)
        XCTAssertFalse("username".containsSensitiveData)
        XCTAssertFalse("display_name".containsSensitiveData)
    }
    
    func testDataHexString() {
        let data = Data([0xAB, 0xCD, 0xEF])
        XCTAssertEqual(data.hexString, "abcdef")
    }
    
    func testDataRedactedHex() {
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let redacted = data.redactedHex
        
        XCTAssertTrue(redacted.hasPrefix("0102"))
        XCTAssertTrue(redacted.hasSuffix("0506"))
        XCTAssertTrue(redacted.contains("*"))
    }
}

