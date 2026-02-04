import Foundation

/// Protocol for random number generation (testability)
public protocol RandomSource: Sendable {
    func int(in range: Range<Int>) -> Int
    func double(in range: ClosedRange<Double>) -> Double
    func bool() -> Bool
}

/// System random source
public struct SystemRandomSource: RandomSource {
    public init() {}

    public func int(in range: Range<Int>) -> Int {
        Int.random(in: range)
    }

    public func double(in range: ClosedRange<Double>) -> Double {
        Double.random(in: range)
    }

    public func bool() -> Bool {
        Bool.random()
    }
}

/// Seeded random source for reproducible tests
public final class SeededRandomSource: RandomSource, @unchecked Sendable {
    private var generator: RandomNumberGenerator
    private let lock = NSLock()

    public init(seed: UInt64) {
        self.generator = SeededGenerator(seed: seed)
    }

    public func int(in range: Range<Int>) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return Int.random(in: range, using: &generator)
    }

    public func double(in range: ClosedRange<Double>) -> Double {
        lock.lock()
        defer { lock.unlock() }
        return Double.random(in: range, using: &generator)
    }

    public func bool() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return Bool.random(using: &generator)
    }
}

/// Simple seeded RNG using xorshift
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

/// Fixed sequence random source for deterministic testing
public final class FixedRandomSource: RandomSource, @unchecked Sendable {
    private var intValues: [Int]
    private var doubleValues: [Double]
    private var boolValues: [Bool]
    private var intIndex = 0
    private var doubleIndex = 0
    private var boolIndex = 0
    private let lock = NSLock()

    public init(ints: [Int] = [0], doubles: [Double] = [0.5], bools: [Bool] = [true]) {
        self.intValues = ints
        self.doubleValues = doubles
        self.boolValues = bools
    }

    public func int(in range: Range<Int>) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let value = intValues[intIndex % intValues.count]
        intIndex += 1
        return max(range.lowerBound, min(range.upperBound - 1, value))
    }

    public func double(in range: ClosedRange<Double>) -> Double {
        lock.lock()
        defer { lock.unlock() }
        let normalized = doubleValues[doubleIndex % doubleValues.count]
        doubleIndex += 1
        return range.lowerBound + (range.upperBound - range.lowerBound) * normalized
    }

    public func bool() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let value = boolValues[boolIndex % boolValues.count]
        boolIndex += 1
        return value
    }
}
