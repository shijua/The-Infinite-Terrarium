import Foundation

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

public struct EcosystemSnapshot: Sendable, Codable, Hashable {
    public let timestamp: TimeInterval
    public let totalBoids: Int
    public let speciesStats: [SpeciesStats]
    public let avgEnergy: Float
    public let extinctionRiskSpeciesIDs: [Int]

    public static let empty = EcosystemSnapshot(
        timestamp: 0,
        totalBoids: 0,
        speciesStats: [],
        avgEnergy: 0,
        extinctionRiskSpeciesIDs: []
    )
}
