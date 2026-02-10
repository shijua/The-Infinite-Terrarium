import Foundation

public final class Quadtree {
    public let capacity: Int
    public let maxDepth: Int

    public init(capacity: Int = 16, maxDepth: Int = 8) {
        self.capacity = capacity
        self.maxDepth = maxDepth
    }

    public func buildSnapshot(boids: [Boid], bounds: SpatialBounds) -> QuadtreeSnapshot {
        QuadtreeSnapshot(boids: boids, bounds: bounds, capacity: capacity, maxDepth: maxDepth)
    }
}
