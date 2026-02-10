import Foundation

/// Deterministic offline fallback provider used when the on-device model is unavailable.
public actor MockAIProvider: AIProvider {
    public init() {}

    public func generateDNA(context: EcosystemSnapshot) async throws -> SpeciesDNA {
        // Snapshot-derived seed ensures reproducible outputs for testability.
        let dominantHash = context.speciesStats.prefix(4).reduce(UInt64(0)) { partial, species in
            partial
                ^ (UInt64(species.speciesID) << 8)
                ^ (UInt64(species.count) << 16)
                ^ (UInt64(species.hue) << 24)
                ^ (UInt64(Int(species.averageEnergy * 1_000)) << 40)
        }

        let seed = UInt64(max(1, context.totalBoids))
            ^ (UInt64(max(1, Int(context.avgEnergy * 10_000))) << 32)
            ^ UInt64(context.extinctionRiskSpeciesIDs.reduce(0, +))
            ^ dominantHash

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
        let seed = contextSeed(for: question, context: context)
        var rng = DeterministicRNG(seed: seed)

        let dominant = context.speciesStats.first
        let riskCount = context.extinctionRiskSpeciesIDs.count
        let questionLower = question.lowercased()

        if questionLower.contains("red") {
            let redStats = context.speciesStats.filter { $0.hue <= 25 || $0.hue >= 335 }
            let redCount = redStats.reduce(0) { $0 + $1.count }
            let redAvgEnergy = redStats.isEmpty
                ? 0
                : redStats.reduce(0 as Float) { $0 + $1.averageEnergy } / Float(redStats.count)
            let pressure = redAvgEnergy < 0.40 ? "energy pressure" : "competition pressure"

            let verb = ["declining", "contracting", "under stress"][rng.nextInt(in: 0...2)]
            return "Red lineages are \(verb): \(redCount) individuals, mean energy \(String(format: "%.2f", redAvgEnergy)). Current driver appears to be \(pressure)."
        }

        if riskCount > 0 {
            let topRiskSpecies = context.speciesStats
                .filter { context.extinctionRiskSpeciesIDs.contains($0.speciesID) }
                .prefix(2)
                .map(\.name)
                .joined(separator: ", ")

            let term = ["instability", "selective pressure", "resource imbalance"][rng.nextInt(in: 0...2)]
            if topRiskSpecies.isEmpty {
                return "The ecosystem shows partial \(term). \(riskCount) lineages are currently near extinction thresholds."
            }

            return "The ecosystem shows partial \(term). \(riskCount) lineages are at risk, especially \(topRiskSpecies)."
        }

        if let dominant {
            let drift = ["low", "moderate", "elevated"][rng.nextInt(in: 0...2)]
            let tone = ["homeostasis", "dynamic balance", "stable competition"][rng.nextInt(in: 0...2)]
            return "\(dominant.name) currently leads (\(dominant.count) organisms, avg energy \(String(format: "%.2f", dominant.averageEnergy))). The biome sits in \(tone) with \(drift) drift."
        }

        return "The biome remains adaptive. Local alignment and cohesion are balancing dispersal pressure."
    }

    private func contextSeed(for question: String, context: EcosystemSnapshot) -> UInt64 {
        let questionHash = fnv1a64(question)
        let speciesHash = context.speciesStats.prefix(6).reduce(UInt64(0)) { partial, species in
            partial
                ^ (UInt64(species.speciesID) << 4)
                ^ (UInt64(species.count) << 12)
                ^ (UInt64(Int(species.averageEnergy * 1_000)) << 28)
                ^ (UInt64(species.hue) << 44)
        }

        return questionHash
            ^ UInt64(max(1, context.totalBoids))
            ^ (UInt64(max(1, Int(context.avgEnergy * 10_000))) << 24)
            ^ (UInt64(context.extinctionRiskSpeciesIDs.reduce(0, +)) << 40)
            ^ speciesHash
    }

    private func fnv1a64(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }
}
