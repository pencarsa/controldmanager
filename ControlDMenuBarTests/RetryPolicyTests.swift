import XCTest
@testable import ControlD

final class RetryPolicyTests: XCTestCase {
    
    func testShouldRetryNetworkErrors() {
        let policy = RetryPolicy()
        
        // Should retry network errors
        let networkError = AppError.networkUnavailable
        XCTAssertTrue(policy.shouldRetry(error: networkError, attempt: 0))
        XCTAssertTrue(policy.shouldRetry(error: networkError, attempt: 1))
        
        // Should not retry after max attempts
        XCTAssertFalse(policy.shouldRetry(error: networkError, attempt: 3))
    }
    
    func testShouldNotRetryConfigurationErrors() {
        let policy = RetryPolicy()
        
        let configError = AppError.configurationMissing
        XCTAssertFalse(policy.shouldRetry(error: configError, attempt: 0))
    }
    
    func testExponentialBackoff() {
        let policy = RetryPolicy(configuration: .init(
            maxAttempts: 3,
            baseDelay: 1.0,
            maxDelay: 30.0,
            multiplier: 2.0,
            jitter: false
        ))
        
        let delay0 = policy.delayBeforeRetry(attempt: 0)
        let delay1 = policy.delayBeforeRetry(attempt: 1)
        let delay2 = policy.delayBeforeRetry(attempt: 2)
        
        XCTAssertEqual(delay0, 1.0, accuracy: 0.01)
        XCTAssertEqual(delay1, 2.0, accuracy: 0.01)
        XCTAssertEqual(delay2, 4.0, accuracy: 0.01)
    }
    
    func testMaxDelayCap() {
        let policy = RetryPolicy(configuration: .init(
            maxAttempts: 10,
            baseDelay: 1.0,
            maxDelay: 5.0,
            multiplier: 2.0,
            jitter: false
        ))
        
        let delay5 = policy.delayBeforeRetry(attempt: 5)
        XCTAssertEqual(delay5, 5.0, accuracy: 0.01) // Should be capped at maxDelay
    }
    
    func testRetryExecution() async throws {
        var attemptCount = 0
        let policy = RetryPolicy(configuration: .init(
            maxAttempts: 3,
            baseDelay: 0.1,
            maxDelay: 1.0,
            multiplier: 2.0,
            jitter: false
        ))
        
        do {
            _ = try await policy.execute {
                attemptCount += 1
                if attemptCount < 3 {
                    throw AppError.networkTimeout
                }
                return "Success"
            }
            
            XCTAssertEqual(attemptCount, 3)
        } catch {
            XCTFail("Should have succeeded on third attempt")
        }
    }
    
    func testRetryExecutionFailsAfterMaxAttempts() async {
        let policy = RetryPolicy(configuration: .init(
            maxAttempts: 2,
            baseDelay: 0.1,
            maxDelay: 1.0,
            multiplier: 2.0,
            jitter: false
        ))
        
        do {
            _ = try await policy.execute {
                throw AppError.networkTimeout
            }
            XCTFail("Should have thrown error")
        } catch {
            // Expected
            XCTAssertTrue(error is AppError)
        }
    }
}

