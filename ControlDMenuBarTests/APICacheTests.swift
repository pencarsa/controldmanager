import XCTest
@testable import ControlD

final class APICacheTests: XCTestCase {
    
    var cache: APICache!
    
    override func setUp() {
        super.setUp()
        cache = APICache(defaultTTL: 1.0) // 1 second for testing
    }
    
    override func tearDown() {
        cache.clearAll()
        cache = nil
        super.tearDown()
    }
    
    func testSetAndGet() {
        cache.set("Test Value", forKey: "test_key")
        
        let value: String? = cache.get(forKey: "test_key")
        XCTAssertEqual(value, "Test Value")
    }
    
    func testGetNonExistent() {
        let value: String? = cache.get(forKey: "non_existent")
        XCTAssertNil(value)
    }
    
    func testExpiration() async throws {
        cache.set("Test Value", forKey: "test_key", ttl: 0.1) // 100ms
        
        // Should be available immediately
        let value1: String? = cache.get(forKey: "test_key")
        XCTAssertNotNil(value1)
        
        // Wait for expiration
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Should be nil after expiration
        let value2: String? = cache.get(forKey: "test_key")
        XCTAssertNil(value2)
    }
    
    func testRemove() {
        cache.set("Test Value", forKey: "test_key")
        cache.remove(forKey: "test_key")
        
        let value: String? = cache.get(forKey: "test_key")
        XCTAssertNil(value)
    }
    
    func testClearAll() {
        cache.set("Value 1", forKey: "key1")
        cache.set("Value 2", forKey: "key2")
        cache.set("Value 3", forKey: "key3")
        
        cache.clearAll()
        
        let value1: String? = cache.get(forKey: "key1")
        let value2: String? = cache.get(forKey: "key2")
        let value3: String? = cache.get(forKey: "key3")
        
        XCTAssertNil(value1)
        XCTAssertNil(value2)
        XCTAssertNil(value3)
    }
    
    func testStatistics() {
        cache.set("Value 1", forKey: "key1")
        cache.set("Value 2", forKey: "key2")
        
        let stats = cache.statistics()
        XCTAssertEqual(stats.count, 2)
        XCTAssertGreaterThan(stats.memoryEstimate, 0)
    }
    
    func testCacheKeyBuilder() {
        let key1 = APICache.key(endpoint: "/test", parameters: ["id": "123"])
        let key2 = APICache.key(endpoint: "/test", parameters: ["id": "123"])
        let key3 = APICache.key(endpoint: "/test", parameters: ["id": "456"])
        
        XCTAssertEqual(key1, key2)
        XCTAssertNotEqual(key1, key3)
    }
    
    func testCodableCache() throws {
        struct TestData: Codable, Equatable {
            let id: Int
            let name: String
        }
        
        let data = TestData(id: 1, name: "Test")
        try cache.setCodable(data, forKey: "test_codable")
        
        let retrieved: TestData? = try cache.getCodable(forKey: "test_codable")
        XCTAssertEqual(retrieved, data)
    }
}

