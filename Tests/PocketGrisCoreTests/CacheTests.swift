import XCTest
@testable import PocketGrisCore

final class CacheTests: XCTestCase {

    // MARK: - Basic Operations

    func testGetAndSet() {
        let cache = Cache<String, Int>(maxSize: 10)

        XCTAssertNil(cache.get("key1"))

        cache.set("key1", value: 42)
        XCTAssertEqual(cache.get("key1"), 42)
    }

    func testSetOverwritesExistingValue() {
        let cache = Cache<String, Int>(maxSize: 10)

        cache.set("key", value: 1)
        XCTAssertEqual(cache.get("key"), 1)

        cache.set("key", value: 2)
        XCTAssertEqual(cache.get("key"), 2)
    }

    func testRemove() {
        let cache = Cache<String, Int>(maxSize: 10)

        cache.set("key", value: 42)
        let removed = cache.remove("key")
        XCTAssertEqual(removed, 42)
        XCTAssertNil(cache.get("key"))
    }

    func testRemoveNonexistentKey() {
        let cache = Cache<String, Int>(maxSize: 10)
        let removed = cache.remove("nonexistent")
        XCTAssertNil(removed)
    }

    func testClear() {
        let cache = Cache<String, Int>(maxSize: 10)

        cache.set("a", value: 1)
        cache.set("b", value: 2)
        cache.set("c", value: 3)
        XCTAssertEqual(cache.count, 3)

        cache.clear()
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.get("a"))
    }

    func testCount() {
        let cache = Cache<String, Int>(maxSize: 10)
        XCTAssertEqual(cache.count, 0)

        cache.set("a", value: 1)
        XCTAssertEqual(cache.count, 1)

        cache.set("b", value: 2)
        XCTAssertEqual(cache.count, 2)

        cache.remove("a")
        XCTAssertEqual(cache.count, 1)
    }

    // MARK: - Eviction

    func testEvictionAtMaxSize() {
        let cache = Cache<Int, String>(maxSize: 4)

        // Fill to capacity
        for i in 0..<4 {
            cache.set(i, value: "value-\(i)")
        }
        XCTAssertEqual(cache.count, 4)

        // This should trigger eviction of half (2 entries)
        cache.set(99, value: "overflow")

        // After eviction: 4 - 2 + 1 = 3 entries
        XCTAssertEqual(cache.count, 3)
        // The new entry should be present
        XCTAssertEqual(cache.get(99), "overflow")
    }

    func testEvictionPreservesRecentEntries() {
        let cache = Cache<Int, String>(maxSize: 4)

        for i in 0..<4 {
            cache.set(i, value: "value-\(i)")
        }

        // Trigger eviction
        cache.set(100, value: "new")

        // After eviction, we should have 3 entries: 2 surviving + 1 new
        XCTAssertEqual(cache.count, 3)
        XCTAssertEqual(cache.get(100), "new")
    }

    func testOverwriteDoesNotTriggerEviction() {
        let cache = Cache<Int, String>(maxSize: 4)

        for i in 0..<4 {
            cache.set(i, value: "value-\(i)")
        }

        // Overwriting an existing key should NOT trigger eviction
        cache.set(0, value: "updated")
        XCTAssertEqual(cache.count, 4)
        XCTAssertEqual(cache.get(0), "updated")
    }

    // MARK: - GetOrInsert

    func testGetOrInsertCachesComputedValue() {
        let cache = Cache<String, Int>(maxSize: 10)
        var computeCount = 0

        let value = cache.getOrInsert("key") {
            computeCount += 1
            return 42
        }

        XCTAssertEqual(value, 42)
        XCTAssertEqual(computeCount, 1)

        // Second call should return cached value without computing
        let cached = cache.getOrInsert("key") {
            computeCount += 1
            return 99
        }

        XCTAssertEqual(cached, 42)
        XCTAssertEqual(computeCount, 1, "Compute should not be called again for cached key")
    }

    func testGetOrInsertReturnsNilWhenComputeReturnsNil() {
        let cache = Cache<String, Int>(maxSize: 10)

        let value = cache.getOrInsert("key") { nil }
        XCTAssertNil(value)
        XCTAssertEqual(cache.count, 0, "Nil compute result should not be cached")
    }

    func testGetOrInsertEvictsWhenFull() {
        let cache = Cache<Int, String>(maxSize: 4)

        for i in 0..<4 {
            cache.set(i, value: "value-\(i)")
        }

        let value = cache.getOrInsert(99) { "computed" }
        XCTAssertEqual(value, "computed")
        XCTAssertEqual(cache.count, 3) // 4 - 2 + 1
    }

    // MARK: - Integer Keys

    func testIntegerKeys() {
        let cache = Cache<Int, String>(maxSize: 100)

        cache.set(1, value: "one")
        cache.set(2, value: "two")

        XCTAssertEqual(cache.get(1), "one")
        XCTAssertEqual(cache.get(2), "two")
        XCTAssertNil(cache.get(3))
    }

    // MARK: - Thread Safety (smoke test)

    func testConcurrentAccess() {
        let cache = Cache<Int, Int>(maxSize: 1000)
        let group = DispatchGroup()

        // Write from multiple threads
        for i in 0..<100 {
            group.enter()
            DispatchQueue.global().async {
                cache.set(i, value: i * 10)
                group.leave()
            }
        }

        group.wait()

        // Read should not crash
        for i in 0..<100 {
            let value = cache.get(i)
            if let value = value {
                XCTAssertEqual(value, i * 10)
            }
        }
    }
}
