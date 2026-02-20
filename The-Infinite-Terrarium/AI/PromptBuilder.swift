import Foundation

public enum AIStage: String, Sendable {
    case intro
    case mutation
    case analysis
}

/// Prompt templates that inject runtime ecosystem context into both AI paths.
public enum PromptBuilder {
    // Shared injection constraints used by both AI prompts and runtime planning.
    public static let injectPopulationRange: ClosedRange<Int> = 72...300
    public static let injectSpeciesCountRange: ClosedRange<Int> = 4...8
    public static let injectDNATimeoutSecondsRange: ClosedRange<Int> = 9...12

    public static func dnaPrompt(context: EcosystemSnapshot, stage: AIStage = .mutation) -> String {
        let dominant = context.speciesStats.first
        let dominantShare = {
            guard let dominant else { return 0.0 }
            return Double(Float(dominant.count) / Float(max(1, context.totalBoids)))
        }()

        let topSpecies = context.speciesStats
            .prefix(4)
            .map { "\($0.name)(\($0.count),E\(String(format: "%.2f", $0.averageEnergy)))" }
            .joined(separator: ", ")

        let atRiskSpecies = context.speciesStats
            .filter { context.extinctionRiskSpeciesIDs.contains($0.speciesID) }
            .map { "\($0.name)(\($0.count),E\(String(format: "%.2f", $0.averageEnergy)))" }
            .joined(separator: ", ")

        let stageDirective: String = switch stage {
        case .intro:
            "Create a balanced newcomer that can coexist and increase species variety."
        case .mutation:
            "Create a non-dominant niche strategy that reduces monoculture pressure."
        case .analysis:
            "Prioritize rescuing vulnerable species with supportive, low-metabolism flocking dynamics."
        }

        let pressureFlags = [
            dominantShare > 0.55 ? "dominance-high" : nil,
            context.extinctionRiskSpeciesIDs.isEmpty ? nil : "extinction-risk-present",
            context.avgEnergy < 0.32 ? "low-energy-system" : nil
        ]
        .compactMap { $0 }
        .joined(separator: ", ")

        return """
        Design ONE new digital organism DNA.
        Objective: increase biodiversity and reduce extinction risk while staying physically plausible.
        Stage strategy: \(stageDirective)
        Ecosystem: \(context.totalBoids) organisms, avg energy \(String(format: "%.2f", context.avgEnergy))
        Dominant species: \(dominant.map { "\($0.name)(\($0.count))" } ?? "none")
        At-risk species: \(atRiskSpecies.isEmpty ? "none" : atRiskSpecies)
        Top species: \(topSpecies.isEmpty ? "none" : topSpecies)
        Pressure flags: \(pressureFlags.isEmpty ? "none" : pressureFlags)
        Injection constraints: population \(injectPopulationRange.lowerBound)-\(injectPopulationRange.upperBound), species-per-inject \(injectSpeciesCountRange.lowerBound)-\(injectSpeciesCountRange.upperBound), DNA timeout \(injectDNATimeoutSecondsRange.lowerBound)-\(injectDNATimeoutSecondsRange.upperBound)s.
        Rules:
        - Avoid copying dominant-species behavior profile.
        - Prefer moderate-to-low metabolism when at-risk species exist.
        - Keep alignment/cohesion high enough for stable flocking.
        """
    }

    public static func explainPrompt(question: String, context: EcosystemSnapshot, stage: AIStage = .analysis) -> String {
        let topSpecies = context.speciesStats.prefix(5).map { 
            "\($0.name): \($0.count) organisms, energy \(String(format: "%.2f", $0.averageEnergy))" 
        }.joined(separator: " | ")
        
        return """
        Explain concisely in 2-3 analytical sentences.
        Question: \(question)
        Ecosystem: \(context.totalBoids) organisms, avg energy \(String(format: "%.2f", context.avgEnergy))
        Species: \(topSpecies)
        """
    }

    public static func dnaClusterPrompt(context: EcosystemSnapshot, stage: AIStage = .mutation, count: Int) -> String {
        let target = max(1, count)
        let dominant = context.speciesStats.first

        let topSpecies = context.speciesStats
            .prefix(4)
            .map { "\($0.name)(\($0.count),E\(String(format: "%.2f", $0.averageEnergy)))" }
            .joined(separator: ", ")

        let atRiskSpecies = context.speciesStats
            .filter { context.extinctionRiskSpeciesIDs.contains($0.speciesID) }
            .map { "\($0.name)(\($0.count),E\(String(format: "%.2f", $0.averageEnergy)))" }
            .joined(separator: ", ")

        let stageDirective: String = switch stage {
        case .intro:
            "Create balanced newcomers that can coexist and increase species variety."
        case .mutation:
            "Create non-dominant niche strategies that reduce monoculture pressure."
        case .analysis:
            "Prioritize rescuing vulnerable species with supportive, low-metabolism flocking dynamics."
        }

        return """
        Design EXACTLY \(target) distinct digital organism DNA entries in one response.
        Objective: increase biodiversity and reduce extinction risk while staying physically plausible.
        Stage strategy: \(stageDirective)
        Ecosystem: \(context.totalBoids) organisms, avg energy \(String(format: "%.2f", context.avgEnergy))
        Dominant species: \(dominant.map { "\($0.name)(\($0.count))" } ?? "none")
        At-risk species: \(atRiskSpecies.isEmpty ? "none" : atRiskSpecies)
        Top species: \(topSpecies.isEmpty ? "none" : topSpecies)
        Rules:
        - Make entries behaviorally distinct from each other.
        - Avoid copying dominant-species behavior profile.
        - Prefer moderate-to-low metabolism when at-risk species exist.
        """
    }
}
