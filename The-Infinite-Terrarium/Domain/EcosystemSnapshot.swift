import Foundation

/// Aggregated stats for a single species at a frame boundary.
public struct SpeciesStats: Sendable, Codable, Hashable, Identifiable {
    public let speciesID: Int
    public let name: String
    public let count: Int
    public let averageEnergy: Float
    public let hue: Int

    public var id: Int {
        speciesID
    }
}

/// Read-only frame summary fed to UI and AI systems.
public struct EcosystemSnapshot: Sendable, Codable, Hashable {
    public let timestamp: TimeInterval
    public let totalBoids: Int
    public let speciesStats: [SpeciesStats]
    public let avgEnergy: Float
    public let extinctionRiskSpeciesIDs: [Int]

    /// Empty state used during startup and edge cases.
    public static let empty = EcosystemSnapshot(
        timestamp: 0,
        totalBoids: 0,
        speciesStats: [],
        avgEnergy: 0,
        extinctionRiskSpeciesIDs: []
    )
}
