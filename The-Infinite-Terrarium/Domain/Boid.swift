import Foundation
import simd

public struct Boid: Sendable, Identifiable, Hashable {
    public let id: Int
    public var speciesID: Int
    public var position: SIMD2<Float>
    public var velocity: SIMD2<Float>
    public var energy: Float

    public init(
        id: Int,
        speciesID: Int,
        position: SIMD2<Float>,
        velocity: SIMD2<Float>,
        energy: Float
    ) {
        self.id = id
        self.speciesID = speciesID
        self.position = position
        self.velocity = velocity
        self.energy = max(0.0, energy)
    }

    public var sensingRange: Float {
        78
    }
}
