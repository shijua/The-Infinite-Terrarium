import Foundation
import simd

/// World-space bounds used by both simulation and rendering transforms.
public struct SpatialBounds: Sendable, Hashable, Codable {
    public var min: SIMD2<Float>
    public var max: SIMD2<Float>

    public init(min: SIMD2<Float>, max: SIMD2<Float>) {
        self.min = min
        self.max = max
    }

    public var size: SIMD2<Float> {
        max - min
    }

    public var center: SIMD2<Float> {
        (min + max) / 2
    }

    public func contains(_ point: SIMD2<Float>) -> Bool {
        point.x >= min.x && point.x <= max.x && point.y >= min.y && point.y <= max.y
    }

    public func clamp(_ point: SIMD2<Float>) -> SIMD2<Float> {
        let clampedX = Swift.max(min.x, Swift.min(max.x, point.x))
        let clampedY = Swift.max(min.y, Swift.min(max.y, point.y))
        return SIMD2<Float>(clampedX, clampedY)
    }

    public func intersectsCircle(center: SIMD2<Float>, radius: Float) -> Bool {
        let clamped = clamp(center)
        let delta = clamped - center
        return simd_length_squared(delta) <= radius * radius
    }
}

/// Immutable spatial index built at frame start for lock-free neighbor queries.
public struct QuadtreeSnapshot: Sendable {
    private struct SpatialPoint: Sendable {
        let index: Int
        let position: SIMD2<Float>
    }

    private struct Node: Sendable {
        let bounds: SpatialBounds
        var points: [SpatialPoint]
        var children: [Node]?

        init(bounds: SpatialBounds) {
            self.bounds = bounds
            self.points = []
            self.children = nil
        }

        mutating func insert(_ point: SpatialPoint, capacity: Int, depth: Int, maxDepth: Int) {
            guard bounds.contains(point.position) else {
                return
            }

            if children == nil, points.count < capacity || depth >= maxDepth {
                points.append(point)
                return
            }

            if children == nil {
                // Split once capacity is exceeded so future queries prune aggressively.
                subdivide()
                let existing = points
                points.removeAll(keepingCapacity: true)
                for existingPoint in existing {
                    insertIntoChild(existingPoint, capacity: capacity, depth: depth + 1, maxDepth: maxDepth)
                }
            }

            insertIntoChild(point, capacity: capacity, depth: depth + 1, maxDepth: maxDepth)
        }

        private mutating func insertIntoChild(_ point: SpatialPoint, capacity: Int, depth: Int, maxDepth: Int) {
            guard var children else {
                points.append(point)
                return
            }

            for idx in children.indices {
                if children[idx].bounds.contains(point.position) {
                    children[idx].insert(point, capacity: capacity, depth: depth, maxDepth: maxDepth)
                    self.children = children
                    return
                }
            }

            points.append(point)
            self.children = children
        }

        private mutating func subdivide() {
            let center = bounds.center
            let min = bounds.min
            let max = bounds.max

            children = [
                Node(bounds: SpatialBounds(min: min, max: center)),
                Node(bounds: SpatialBounds(min: SIMD2<Float>(center.x, min.y), max: SIMD2<Float>(max.x, center.y))),
                Node(bounds: SpatialBounds(min: SIMD2<Float>(min.x, center.y), max: SIMD2<Float>(center.x, max.y))),
                Node(bounds: SpatialBounds(min: center, max: max))
            ]
        }

        func query(center: SIMD2<Float>, radius: Float, into result: inout [Int]) {
            guard bounds.intersectsCircle(center: center, radius: radius) else {
                return
            }

            for point in points {
                let delta = point.position - center
                if simd_length_squared(delta) <= radius * radius {
                    result.append(point.index)
                }
            }

            guard let children else {
                return
            }

            for child in children {
                child.query(center: center, radius: radius, into: &result)
            }
        }
    }

    public let bounds: SpatialBounds

    private let root: Node

    public init(boids: [Boid], bounds: SpatialBounds, capacity: Int = 16, maxDepth: Int = 8) {
        self.bounds = bounds

        // Store boid indices so lookup remains aligned with the source boid array.
        var mutableRoot = Node(bounds: bounds)
        for (index, boid) in boids.enumerated() {
            let point = SpatialPoint(index: index, position: boid.position)
            mutableRoot.insert(point, capacity: capacity, depth: 0, maxDepth: maxDepth)
        }

        root = mutableRoot
    }

    public func query(center: SIMD2<Float>, radius: Float) -> [Int] {
        var result: [Int] = []
        result.reserveCapacity(32)
        root.query(center: center, radius: radius, into: &result)
        return result
    }
}
