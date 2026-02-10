import Foundation

/// Deterministic offline fallback provider used when the on-device model is unavailable.
public actor MockAIProvider: AIProvider {
    public init() {}

    public func generateDNA(context: EcosystemSnapshot) async throws -> SpeciesDNA {
        // Snapshot-derived seed ensures reproducible outputs for testability.
        let seed = UInt64(max(1, context.totalBoids))
            ^ (UInt64(max(1, Int(context.avgEnergy * 10_000))) << 32)
            ^ UInt64(context.extinctionRiskSpeciesIDs.reduce(0, +))

        var rng = DeterministicRNG(seed: seed)

        let names = ["Nema", "Sylva", "Aure", "Ceto", "Vitra", "Krya", "Luma", "Voro"]
        let suffix = ["aris", "ora", "ion", "is", "idae", "on", "um", "ea"]

        let speciesName = "\(names[rng.nextInt(in: 0...(names.count - 1))]) \(suffix[rng.nextInt(in: 0...(suffix.count - 1))])"

        return SpeciesDNA(
            speciesName: speciesName,
            hue: rng.nextInt(in: 0...360),
            socialDistance: rng.nextFloat(in: 0.15...0.9),
            alignmentWeight: rng.nextFloat(in: 0.4...1.3),
            cohesionWeight: rng.nextFloat(in: 0.35...1.25),
            metabolismRate: rng.nextFloat(in: 0.3...1.6),
            maxSpeed: rng.nextFloat(in: 55...165)
        )
    }

    public func explain(question: String, context: EcosystemSnapshot) async throws -> String {
        let dominant = context.speciesStats.first
        let riskCount = context.extinctionRiskSpeciesIDs.count

        if question.lowercased().contains("red") {
            return "Red-line populations show energetic collapse under current pressure. Their average intake is below maintenance threshold."
        }

        if riskCount > 0 {
            return "The ecosystem is in partial instability. \(riskCount) lineages are near extinction, likely from high metabolic cost and weak food access."
        }

        if let dominant {
            return "Current homeostasis is dominated by \(dominant.name). Drift is moderate, and niche competition remains active across species clusters."
        }

        return "The biome remains adaptive. Local alignment and cohesion are balancing dispersal pressure."
    }
}
