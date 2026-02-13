import Foundation
import Synchronization

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
public final class SeededRandomSource: RandomSource, Sendable {
    private struct State: Sendable {
        var generator: SeededGenerator
    }

    private let state: Mutex<State>

    public init(seed: UInt64) {
        self.state = Mutex(State(generator: SeededGenerator(seed: seed)))
    }

    public func int(in range: Range<Int>) -> Int {
        state.withLock { Int.random(in: range, using: &$0.generator) }
    }

    public func double(in range: ClosedRange<Double>) -> Double {
        state.withLock { Double.random(in: range, using: &$0.generator) }
    }

    public func bool() -> Bool {
        state.withLock { Bool.random(using: &$0.generator) }
    }
}

/// Simple seeded RNG using xorshift
private struct SeededGenerator: RandomNumberGenerator, Sendable {
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
public final class FixedRandomSource: RandomSource, Sendable {
    private struct State: Sendable {
        var intValues: [Int]
        var doubleValues: [Double]
        var boolValues: [Bool]
        var intIndex: Int = 0
        var doubleIndex: Int = 0
        var boolIndex: Int = 0
    }

    private let state: Mutex<State>

    public init(ints: [Int] = [0], doubles: [Double] = [0.5], bools: [Bool] = [true]) {
        self.state = Mutex(State(
            intValues: ints,
            doubleValues: doubles,
            boolValues: bools
        ))
    }

    public func int(in range: Range<Int>) -> Int {
        state.withLock { s in
            let value = s.intValues[s.intIndex % s.intValues.count]
            s.intIndex += 1
            return max(range.lowerBound, min(range.upperBound - 1, value))
        }
    }

    public func double(in range: ClosedRange<Double>) -> Double {
        state.withLock { s in
            let normalized = s.doubleValues[s.doubleIndex % s.doubleValues.count]
            s.doubleIndex += 1
            return range.lowerBound + (range.upperBound - range.lowerBound) * normalized
        }
    }

    public func bool() -> Bool {
        state.withLock { s in
            let value = s.boolValues[s.boolIndex % s.boolValues.count]
            s.boolIndex += 1
            return value
        }
    }
}
