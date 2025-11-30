import XCTest
@testable import ControlD

final class DebouncerTests: XCTestCase {
    
    func testDebounce() async throws {
        let debouncer = Debouncer(delay: 0.1)
        var executionCount = 0
        
        // Trigger multiple times rapidly
        debouncer.debounce { executionCount += 1 }
        debouncer.debounce { executionCount += 1 }
        debouncer.debounce { executionCount += 1 }
        
        // Wait for debounce delay
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Should only execute once
        XCTAssertEqual(executionCount, 1)
    }
    
    func testCancel() async throws {
        let debouncer = Debouncer(delay: 0.1)
        var executed = false
        
        debouncer.debounce { executed = true }
        debouncer.cancel()
        
        // Wait past debounce delay
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Should not execute
        XCTAssertFalse(executed)
    }
    
    func testThrottle() async throws {
        let throttler = Throttler(interval: 0.1)
        var executionCount = 0
        
        // Trigger multiple times
        throttler.throttle { executionCount += 1 }
        throttler.throttle { executionCount += 1 }
        throttler.throttle { executionCount += 1 }
        
        // Wait a moment
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Should only execute first time
        XCTAssertEqual(executionCount, 1)
        
        // Wait for throttle interval
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Now should execute again
        throttler.throttle { executionCount += 1 }
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        XCTAssertEqual(executionCount, 2)
    }
    
    func testThrottlerReset() async throws {
        let throttler = Throttler(interval: 1.0)
        var executionCount = 0
        
        throttler.throttle { executionCount += 1 }
        throttler.reset()
        throttler.throttle { executionCount += 1 }
        
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Should execute both times due to reset
        XCTAssertEqual(executionCount, 2)
    }
}

