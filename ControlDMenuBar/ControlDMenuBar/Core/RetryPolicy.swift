import Foundation

/// Retry policy with exponential backoff
final class RetryPolicy {
    
    // MARK: - Configuration
    
    struct Configuration {
        let maxAttempts: Int
        let baseDelay: TimeInterval
        let maxDelay: TimeInterval
        let multiplier: Double
        let jitter: Bool
        
        static let `default` = Configuration(
            maxAttempts: 3,
            baseDelay: 1.0,
            maxDelay: 30.0,
            multiplier: 2.0,
            jitter: true
        )
        
        static let aggressive = Configuration(
            maxAttempts: 5,
            baseDelay: 0.5,
            maxDelay: 60.0,
            multiplier: 2.0,
            jitter: true
        )
        
        static let conservative = Configuration(
            maxAttempts: 2,
            baseDelay: 2.0,
            maxDelay: 15.0,
            multiplier: 1.5,
            jitter: false
        )
    }
    
    // MARK: - Properties
    
    private let configuration: Configuration
    
    // MARK: - Initialization
    
    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Retry Logic
    
    /// Determines if an error should be retried
    func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < configuration.maxAttempts else {
            return false
        }
        
        // Check if error is retryable
        if let appError = error as? AppError {
            return appError.isRetryable
        }
        
        // Check for network errors
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorTimedOut,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorDNSLookupFailed:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    /// Calculates delay before next retry attempt
    func delayBeforeRetry(attempt: Int) -> TimeInterval {
        // Calculate exponential backoff
        let delay = configuration.baseDelay * pow(configuration.multiplier, Double(attempt))
        
        // Cap at maximum delay
        var finalDelay = min(delay, configuration.maxDelay)
        
        // Add jitter to prevent thundering herd
        if configuration.jitter {
            let jitterAmount = finalDelay * 0.3 // 30% jitter
            let randomJitter = Double.random(in: -jitterAmount...jitterAmount)
            finalDelay += randomJitter
        }
        
        return max(0, finalDelay)
    }
    
    /// Execute an operation with retry logic
    func execute<T>(
        operation: @escaping () async throws -> T,
        onRetry: ((Int, Error) -> Void)? = nil
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<configuration.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if we should retry
                guard shouldRetry(error: error, attempt: attempt) else {
                    throw error
                }
                
                // Notify about retry
                onRetry?(attempt + 1, error)
                
                // Wait before retrying
                let delay = delayBeforeRetry(attempt: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // All attempts failed
        throw lastError ?? AppError.networkError("All retry attempts failed")
    }
}

// MARK: - Convenience Extensions

extension RetryPolicy {
    /// Execute an operation with default retry policy
    static func withRetry<T>(
        maxAttempts: Int = 3,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        let policy = RetryPolicy(configuration: Configuration(
            maxAttempts: maxAttempts,
            baseDelay: 1.0,
            maxDelay: 30.0,
            multiplier: 2.0,
            jitter: true
        ))
        
        return try await policy.execute(operation: operation)
    }
}

