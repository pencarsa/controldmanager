import Foundation

/// Thread-safe cache for API responses with TTL support
final class APICache {
    
    // MARK: - Cache Entry
    
    private struct CacheEntry {
        let value: Any
        let expiresAt: Date
        
        var isExpired: Bool {
            return Date() > expiresAt
        }
    }
    
    // MARK: - Properties
    
    private var cache: [String: CacheEntry] = [:]
    private let queue = DispatchQueue(label: "com.controld.menubar.cache", attributes: .concurrent)
    private let defaultTTL: TimeInterval
    
    // MARK: - Initialization
    
    init(defaultTTL: TimeInterval = 300) { // 5 minutes default
        self.defaultTTL = defaultTTL
        
        // Start cleanup timer
        startCleanupTimer()
    }
    
    // MARK: - Cache Operations
    
    /// Store a value in the cache
    func set<T>(_ value: T, forKey key: String, ttl: TimeInterval? = nil) {
        let expiresAt = Date().addingTimeInterval(ttl ?? defaultTTL)
        let entry = CacheEntry(value: value, expiresAt: expiresAt)
        
        queue.async(flags: .barrier) {
            self.cache[key] = entry
        }
    }
    
    /// Retrieve a value from the cache
    func get<T>(forKey key: String) -> T? {
        var entry: CacheEntry?
        
        queue.sync {
            entry = cache[key]
        }
        
        guard let entry = entry else {
            return nil
        }
        
        // Check if expired
        if entry.isExpired {
            remove(forKey: key)
            return nil
        }
        
        return entry.value as? T
    }
    
    /// Remove a value from the cache
    func remove(forKey key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }
    
    /// Clear all cached values
    func clearAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
    
    /// Remove expired entries
    private func removeExpired() {
        queue.async(flags: .barrier) {
            let now = Date()
            self.cache = self.cache.filter { !$0.value.isExpired }
        }
    }
    
    /// Get cache statistics
    func statistics() -> (count: Int, memoryEstimate: Int) {
        var count = 0
        queue.sync {
            count = cache.count
        }
        // Rough estimate: 1KB per entry
        return (count: count, memoryEstimate: count * 1024)
    }
    
    // MARK: - Cleanup Timer
    
    private func startCleanupTimer() {
        // Clean expired entries every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.removeExpired()
        }
    }
}

// MARK: - Cache Key Builder

extension APICache {
    /// Build a cache key from components
    static func key(endpoint: String, parameters: [String: Any] = [:]) -> String {
        var components = [endpoint]
        
        // Sort parameters for consistent keys
        let sortedKeys = parameters.keys.sorted()
        for key in sortedKeys {
            if let value = parameters[key] {
                components.append("\(key)=\(value)")
            }
        }
        
        return components.joined(separator: "|")
    }
}

// MARK: - Codable Cache Support

extension APICache {
    /// Store a codable value
    func setCodable<T: Codable>(_ value: T, forKey key: String, ttl: TimeInterval? = nil) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        set(data, forKey: key, ttl: ttl)
    }
    
    /// Retrieve a codable value
    func getCodable<T: Codable>(forKey key: String) throws -> T? {
        guard let data: Data = get(forKey: key) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}

