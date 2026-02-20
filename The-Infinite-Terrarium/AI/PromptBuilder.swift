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
        Create a new digital organism with plausible flocking traits.
        Current ecosystem: \(context.totalBoids) organisms, avg energy \(String(format: "%.2f", context.avgEnergy))
        Top species: \(context.speciesStats.prefix(3).map { "\($0.name)(\($0.count))" }.joined(separator: ", "))
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
}
