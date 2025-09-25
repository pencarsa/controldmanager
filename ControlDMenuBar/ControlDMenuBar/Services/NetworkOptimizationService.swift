import Foundation
import Combine

/// Service for optimizing network requests with debouncing, caching, and request management
@MainActor
class NetworkOptimizationService: ObservableObject {
    static let shared = NetworkOptimizationService()
    
    // MARK: - Properties
    
    private var pendingTasks: [String: Task<Any, Error>] = [:]
    private var requestCache: [String: CachedResponse] = [:]
    private let debounceInterval: TimeInterval = 0.5
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    private let maxCacheSize = 50
    
    // MARK: - Data Models
    
    private struct CachedResponse {
        let data: Any
        let timestamp: Date
        let expiresAt: Date
        
        var isExpired: Bool {
            return Date() > expiresAt
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Start cache cleanup timer
        startCacheCleanup()
    }
    
    // MARK: - Debounced Requests
    
    /// Debounces network requests to prevent excessive API calls
    func debounceRequest<T>(
        key: String,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        // Cancel existing task for this key
        pendingTasks[key]?.cancel()
        
        // Create new debounced task
        let task = Task<Any, Error> {
            // Wait for debounce interval
            try await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            
            // Check if task was cancelled
            try Task.checkCancellation()
            
            // Execute the operation
            return try await operation()
        }
        
        pendingTasks[key] = task
        
        do {
            let result = try await task.value
            pendingTasks.removeValue(forKey: key)
            return result as! T
        } catch {
            pendingTasks.removeValue(forKey: key)
            throw error
        }
    }
    
    // MARK: - Request Caching
    
    /// Caches network responses with automatic expiration
    func cachedRequest<T>(
        key: String,
        cacheTimeout: TimeInterval? = nil,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        let timeout = cacheTimeout ?? self.cacheTimeout
        
        // Check if we have a valid cached response
        if let cached = requestCache[key], !cached.isExpired {
            print("📦 Cache hit for key: \(key)")
            return cached.data as! T
        }
        
        // Execute the operation
        print("🌐 Cache miss for key: \(key), fetching...")
        let result = try await operation()
        
        // Cache the result
        let cachedResponse = CachedResponse(
            data: result,
            timestamp: Date(),
            expiresAt: Date().addingTimeInterval(timeout)
        )
        
        requestCache[key] = cachedResponse
        
        // Cleanup cache if it's getting too large
        cleanupCacheIfNeeded()
        
        return result
    }
    
    /// Combines debouncing and caching for optimal performance
    func optimizedRequest<T>(
        key: String,
        cacheTimeout: TimeInterval? = nil,
        debounce: Bool = true,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        if debounce {
            return try await debounceRequest(key: key) {
                return try await cachedRequest(
                    key: key,
                    cacheTimeout: cacheTimeout,
                    operation: operation
                )
            }
        } else {
            return try await cachedRequest(
                key: key,
                cacheTimeout: cacheTimeout,
                operation: operation
            )
        }
    }
    
    // MARK: - Cache Management
    
    /// Invalidates cached response for a specific key
    func invalidateCache(for key: String) {
        requestCache.removeValue(forKey: key)
        print("🗑️ Cache invalidated for key: \(key)")
    }
    
    /// Invalidates all cached responses
    func clearCache() {
        requestCache.removeAll()
        print("🗑️ All cache cleared")
    }
    
    /// Invalidates cache entries matching a pattern
    func invalidateCache(matching pattern: String) {
        let keysToRemove = requestCache.keys.filter { $0.contains(pattern) }
        for key in keysToRemove {
            requestCache.removeValue(forKey: key)
        }
        print("🗑️ Cache invalidated for pattern: \(pattern) (\(keysToRemove.count) entries)")
    }
    
    // MARK: - Request Cancellation
    
    /// Cancels pending request for a specific key
    func cancelRequest(for key: String) {
        pendingTasks[key]?.cancel()
        pendingTasks.removeValue(forKey: key)
        print("❌ Request cancelled for key: \(key)")
    }
    
    /// Cancels all pending requests
    func cancelAllRequests() {
        for task in pendingTasks.values {
            task.cancel()
        }
        pendingTasks.removeAll()
        print("❌ All pending requests cancelled")
    }
    
    // MARK: - Private Methods
    
    private func cleanupCacheIfNeeded() {
        guard requestCache.count > maxCacheSize else { return }
        
        // Remove expired entries first
        let expiredKeys = requestCache.compactMap { key, value in
            value.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            requestCache.removeValue(forKey: key)
        }
        
        // If still over limit, remove oldest entries
        if requestCache.count > maxCacheSize {
            let sortedEntries = requestCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let entriesToRemove = sortedEntries.prefix(requestCache.count - maxCacheSize)
            
            for (key, _) in entriesToRemove {
                requestCache.removeValue(forKey: key)
            }
        }
        
        print("🧹 Cache cleanup completed. Current size: \(requestCache.count)")
    }
    
    private func startCacheCleanup() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupExpiredCache()
            }
        }
    }
    
    private func cleanupExpiredCache() {
        let expiredKeys = requestCache.compactMap { key, value in
            value.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            requestCache.removeValue(forKey: key)
        }
        
        if !expiredKeys.isEmpty {
            print("🧹 Removed \(expiredKeys.count) expired cache entries")
        }
    }
    
    // MARK: - Debug Information
    
    var cacheInfo: String {
        let totalEntries = requestCache.count
        let expiredEntries = requestCache.values.filter { $0.isExpired }.count
        let pendingRequests = pendingTasks.count
        
        return """
        Cache Info:
        - Total entries: \(totalEntries)
        - Expired entries: \(expiredEntries)
        - Pending requests: \(pendingRequests)
        """
    }
}

// MARK: - Convenience Extensions

extension NetworkOptimizationService {
    
    /// Optimized API key validation with debouncing
    func validateApiKey(_ apiKey: String, using validator: @escaping (String) async throws -> Bool) async throws -> Bool {
        let key = "validate_api_key_\(apiKey.prefix(10))" // Use prefix to avoid storing full key
        
        return try await optimizedRequest(
            key: key,
            cacheTimeout: 60, // Cache validation for 1 minute
            debounce: true
        ) {
            return try await validator(apiKey)
        }
    }
    
    /// Optimized profile fetching with caching
    func fetchProfiles(using fetcher: @escaping () async throws -> [Any]) async throws -> [Any] {
        return try await optimizedRequest(
            key: "fetch_profiles",
            cacheTimeout: 300, // Cache profiles for 5 minutes
            debounce: false // Don't debounce profile fetching
        ) {
            return try await fetcher()
        }
    }
    
    /// Optimized profile status checking
    func getProfileStatus(profileId: String, using fetcher: @escaping (String) async throws -> String) async throws -> String {
        return try await optimizedRequest(
            key: "profile_status_\(profileId)",
            cacheTimeout: 30, // Cache status for 30 seconds
            debounce: true
        ) {
            return try await fetcher(profileId)
        }
    }
}