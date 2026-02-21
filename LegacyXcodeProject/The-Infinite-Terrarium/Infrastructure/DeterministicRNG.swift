import Foundation

/// Seeded PRNG used for reproducible simulation and mock AI behavior.
public struct DeterministicRNG: Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    public mutating func nextUInt64() -> UInt64 {
        // xorshift64* variant with good speed/quality tradeoff for gameplay simulation.
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }

    public mutating func nextFloat() -> Float {
        Float(nextUInt64() & 0xFFFFFF) / Float(0x1000000)
    }

    public mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let width = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(nextUInt64() % width)
    }

    public mutating func nextFloat(in range: ClosedRange<Float>) -> Float {
        range.lowerBound + (range.upperBound - range.lowerBound) * nextFloat()
    }
}
