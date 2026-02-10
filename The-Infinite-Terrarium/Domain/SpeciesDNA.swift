import Foundation

/// Species-level behavior coefficients shared by all boids in a species.
public struct SpeciesDNA: Codable, Sendable, Hashable {
    public let speciesName: String
    public let hue: Int
    public let socialDistance: Float
    public let alignmentWeight: Float
    public let cohesionWeight: Float
    public let metabolismRate: Float
    public let maxSpeed: Float

    public init(
        speciesName: String,
        hue: Int,
        socialDistance: Float,
        alignmentWeight: Float,
        cohesionWeight: Float,
        metabolismRate: Float,
        maxSpeed: Float
    ) {
        // Clamp every generated value so physics remains stable.
        self.speciesName = speciesName.isEmpty ? "Species" : speciesName
        self.hue = max(0, min(360, hue))
        self.socialDistance = max(0.0, min(1.0, socialDistance))
        self.alignmentWeight = max(0.0, min(2.0, alignmentWeight))
        self.cohesionWeight = max(0.0, min(2.0, cohesionWeight))
        self.metabolismRate = max(0.05, min(2.5, metabolismRate))
        self.maxSpeed = max(10.0, min(220.0, maxSpeed))
    }
}

public extension SpeciesDNA {
    /// Default balanced species used during engine bootstrap.
    static let pioneer = SpeciesDNA(
        speciesName: "Protoflora lucens",
        hue: 145,
        socialDistance: 0.34,
        alignmentWeight: 0.82,
        cohesionWeight: 0.91,
        metabolismRate: 0.65,
        maxSpeed: 88
    )

    /// Mid-range roaming species.
    static let drifter = SpeciesDNA(
        speciesName: "Aether drifter",
        hue: 198,
        socialDistance: 0.48,
        alignmentWeight: 0.72,
        cohesionWeight: 0.66,
        metabolismRate: 0.86,
        maxSpeed: 116
    )

    /// Fast high-pressure predator profile.
    static let hunter = SpeciesDNA(
        speciesName: "Crimson vorax",
        hue: 8,
        socialDistance: 0.84,
        alignmentWeight: 0.48,
        cohesionWeight: 0.34,
        metabolismRate: 1.22,
        maxSpeed: 154
    )
}
