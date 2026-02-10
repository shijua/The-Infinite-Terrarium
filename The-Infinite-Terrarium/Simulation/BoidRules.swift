import Foundation
import simd

public enum BoidRules {
    public static func update(
        boid: inout Boid,
        neighbors: [Boid],
        dna: SpeciesDNA,
        bounds: SpatialBounds,
        deltaTime: Float
    ) {
        let separationRadius: Float = 18 + dna.socialDistance * 52
        let alignmentRadius: Float = 62
        let cohesionRadius: Float = 72

        var separation = SIMD2<Float>(repeating: 0)
        var alignment = SIMD2<Float>(repeating: 0)
        var cohesion = SIMD2<Float>(repeating: 0)

        var alignmentCount: Float = 0
        var cohesionCount: Float = 0

        for neighbor in neighbors {
            let delta = boid.position - neighbor.position
            let distanceSq = simd_length_squared(delta)
            if distanceSq <= 0.0001 {
                continue
            }

            let distance = sqrt(distanceSq)

            if distance < separationRadius {
                separation += simd_normalize(delta) / max(distance, 0.001)
            }

            if distance < alignmentRadius {
                alignment += neighbor.velocity
                alignmentCount += 1
            }

            if distance < cohesionRadius {
                cohesion += neighbor.position
                cohesionCount += 1
            }
        }

        if alignmentCount > 0 {
            alignment /= alignmentCount
            alignment = limit(steer(from: boid.velocity, to: alignment), maxLength: 16)
        }

        if cohesionCount > 0 {
            cohesion /= cohesionCount
            cohesion = steer(from: boid.velocity, to: cohesion - boid.position)
            cohesion = limit(cohesion, maxLength: 14)
        }

        separation = limit(separation, maxLength: 18)

        let boundary = boundaryForce(for: boid.position, in: bounds)

        var acceleration = SIMD2<Float>(repeating: 0)
        acceleration += separation * (0.8 + dna.socialDistance * 1.2)
        acceleration += alignment * dna.alignmentWeight
        acceleration += cohesion * dna.cohesionWeight
        acceleration += boundary

        boid.velocity += acceleration * deltaTime
        boid.velocity = limit(boid.velocity, maxLength: dna.maxSpeed)

        boid.position += boid.velocity * deltaTime
        boid.position = wrap(boid.position, in: bounds)

        boid.energy = max(0, boid.energy - dna.metabolismRate * deltaTime)
    }

    private static func steer(from velocity: SIMD2<Float>, to desired: SIMD2<Float>) -> SIMD2<Float> {
        guard simd_length_squared(desired) > 0.0001 else {
            return .zero
        }

        return simd_normalize(desired) * max(simd_length(velocity), 24) - velocity
    }

    private static func limit(_ value: SIMD2<Float>, maxLength: Float) -> SIMD2<Float> {
        let length = simd_length(value)
        guard length > maxLength, length > 0 else {
            return value
        }

        return (value / length) * maxLength
    }

    private static func boundaryForce(for position: SIMD2<Float>, in bounds: SpatialBounds) -> SIMD2<Float> {
        let margin: Float = 52
        var force = SIMD2<Float>(repeating: 0)

        if position.x < bounds.min.x + margin {
            force.x += 12
        } else if position.x > bounds.max.x - margin {
            force.x -= 12
        }

        if position.y < bounds.min.y + margin {
            force.y += 12
        } else if position.y > bounds.max.y - margin {
            force.y -= 12
        }

        return force
    }

    private static func wrap(_ point: SIMD2<Float>, in bounds: SpatialBounds) -> SIMD2<Float> {
        var wrapped = point
        let width = bounds.max.x - bounds.min.x
        let height = bounds.max.y - bounds.min.y

        if wrapped.x < bounds.min.x { wrapped.x += width }
        if wrapped.x > bounds.max.x { wrapped.x -= width }
        if wrapped.y < bounds.min.y { wrapped.y += height }
        if wrapped.y > bounds.max.y { wrapped.y -= height }

        return wrapped
    }
}
