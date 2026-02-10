import Foundation

public enum AIStage: String, Sendable {
    case intro
    case mutation
    case analysis
}

/// Prompt templates that inject runtime ecosystem context into both AI paths.
public enum PromptBuilder {
    public static func dnaPrompt(context: EcosystemSnapshot, stage: AIStage = .mutation) -> String {
        """
        You are an AI exobiologist engineering a new digital organism.
        Stage: \(stage.rawValue)
        Constraints:
        - Keep values physically plausible for flocking.
        - Prefer balancing ecosystem diversity and survival pressure.
        - Return concise traits.

        Ecosystem snapshot:
        - totalBoids: \(context.totalBoids)
        - avgEnergy: \(String(format: "%.3f", context.avgEnergy))
        - extinctionRiskSpeciesIDs: \(context.extinctionRiskSpeciesIDs)
        - topSpecies: \(context.speciesStats.prefix(4).map { "\($0.name):\($0.count)" }.joined(separator: ", "))
        """
    }

    public static func explainPrompt(question: String, context: EcosystemSnapshot, stage: AIStage = .analysis) -> String {
        """
        You are an AI exobiologist narrating a synthetic ecosystem.
        Stage: \(stage.rawValue)
        Speak in short analytical sentences.
        Use terms such as homeostasis, drift, selective pressure when relevant.

        User question: \(question)

        Ecosystem snapshot:
        - totalBoids: \(context.totalBoids)
        - avgEnergy: \(String(format: "%.3f", context.avgEnergy))
        - extinctionRiskSpeciesIDs: \(context.extinctionRiskSpeciesIDs)
        - species: \(context.speciesStats.map { "id=\($0.speciesID),name=\($0.name),count=\($0.count),avgEnergy=\(String(format: "%.3f", $0.averageEnergy)),hue=\($0.hue),socialDistance=\(String(format: "%.2f", $0.socialDistance)),alignment=\(String(format: "%.2f", $0.alignmentWeight)),cohesion=\(String(format: "%.2f", $0.cohesionWeight)),metabolism=\(String(format: "%.2f", $0.metabolismRate)),maxSpeed=\(String(format: "%.0f", $0.maxSpeed))" }.joined(separator: " | "))
        """
    }
}
