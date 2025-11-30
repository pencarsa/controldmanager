import XCTest
@testable import ControlD

final class AppErrorTests: XCTestCase {
    
    func testNetworkErrorDescriptions() {
        let error1 = AppError.networkUnavailable
        XCTAssertEqual(error1.errorDescription, "Network is unavailable")
        XCTAssertNotNil(error1.recoverySuggestion)
        
        let error2 = AppError.networkTimeout
        XCTAssertEqual(error2.errorDescription, "Network request timed out")
        
        let error3 = AppError.networkError("Connection failed")
        XCTAssertTrue(error3.errorDescription?.contains("Connection failed") ?? false)
    }
    
    func testAPIErrorDescriptions() {
        let error1 = AppError.invalidApiKey
        XCTAssertEqual(error1.errorDescription, "Invalid API key")
        
        let error2 = AppError.apiServerError(statusCode: 500, message: "Internal error")
        XCTAssertTrue(error2.errorDescription?.contains("500") ?? false)
        
        let error3 = AppError.apiRateLimited(retryAfter: 60)
        XCTAssertTrue(error3.errorDescription?.contains("60") ?? false)
    }
    
    func testConfigurationErrorDescriptions() {
        let error1 = AppError.configurationMissing
        XCTAssertEqual(error1.errorDescription, "Configuration is incomplete")
        
        let error2 = AppError.invalidConfiguration("Bad value")
        XCTAssertTrue(error2.errorDescription?.contains("Bad value") ?? false)
        
        let error3 = AppError.profileNotFound
        XCTAssertEqual(error3.errorDescription, "Selected profile not found")
    }
    
    func testRecoveryActions() {
        XCTAssertEqual(AppError.networkUnavailable.recoveryAction, .retry)
        XCTAssertEqual(AppError.invalidApiKey.recoveryAction, .reconfigure)
        XCTAssertEqual(AppError.configurationMissing.recoveryAction, .configure)
        XCTAssertEqual(AppError.profileNotFound.recoveryAction, .selectProfile)
    }
    
    func testRetryability() {
        XCTAssertTrue(AppError.networkUnavailable.isRetryable)
        XCTAssertTrue(AppError.networkTimeout.isRetryable)
        XCTAssertTrue(AppError.apiServerError(statusCode: 500, message: "Error").isRetryable)
        
        XCTAssertFalse(AppError.invalidApiKey.isRetryable)
        XCTAssertFalse(AppError.configurationMissing.isRetryable)
        XCTAssertFalse(AppError.profileNotFound.isRetryable)
    }
    
    func testErrorEquality() {
        let error1 = AppError.networkUnavailable
        let error2 = AppError.networkUnavailable
        XCTAssertEqual(error1, error2)
        
        let error3 = AppError.networkError("Test")
        let error4 = AppError.networkError("Test")
        XCTAssertEqual(error3, error4)
        
        let error5 = AppError.networkError("Test1")
        let error6 = AppError.networkError("Test2")
        XCTAssertNotEqual(error5, error6)
    }
}

