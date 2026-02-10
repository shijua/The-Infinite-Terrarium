import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Structured output contract for model-guided DNA generation.
@available(iOS 26.0, *)
@Generable(description: "A digital organism DNA blueprint")
private struct GeneratedSpeciesDNA {
    @Guide(description: "Scientific style species name")
    let speciesName: String

    @Guide(description: "Color hue 0 to 360", .range(0...360))
    let hue: Int

    @Guide(description: "Separation pressure 0.0 to 1.0", .range(0.0...1.0))
    let socialDistance: Float

    @Guide(description: "Alignment weight 0.0 to 2.0", .range(0.0...2.0))
    let alignmentWeight: Float

    @Guide(description: "Cohesion weight 0.0 to 2.0", .range(0.0...2.0))
    let cohesionWeight: Float

    @Guide(description: "Metabolic rate 0.05 to 2.5", .range(0.05...2.5))
    let metabolismRate: Float

    @Guide(description: "Maximum speed 10 to 220", .range(10.0...220.0))
    let maxSpeed: Float
}

/// On-device provider backed by iOS Foundation Models.
@available(iOS 26.0, *)
public actor FoundationModelsProvider: AIProvider {
    private let session: LanguageModelSession

    public init?() {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            return nil
        }

        session = LanguageModelSession(
            model: model,
            instructions: """
            You are an AI exobiologist observing and designing digital organisms.
            Keep outputs concise and analytical.
            Prioritize physically plausible flocking traits and ecosystem balance.
            """
        )
    }

    public func generateDNA(context: EcosystemSnapshot) async throws -> SpeciesDNA {
        // Typed generation avoids manual JSON parsing and keeps value ranges constrained.
        let response = try await session.respond(
            to: PromptBuilder.dnaPrompt(context: context),
            generating: GeneratedSpeciesDNA.self
        )

        return SpeciesDNA(
            speciesName: response.content.speciesName,
            hue: response.content.hue,
            socialDistance: response.content.socialDistance,
            alignmentWeight: response.content.alignmentWeight,
            cohesionWeight: response.content.cohesionWeight,
            metabolismRate: response.content.metabolismRate,
            maxSpeed: response.content.maxSpeed
        )
    }

    public func explain(question: String, context: EcosystemSnapshot) async throws -> String {
        let response = try await session.respond(
            to: PromptBuilder.explainPrompt(question: question, context: context)
        )

        return response.content
    }
}

#else

/// Compile-time unavailable placeholder when FoundationModels framework is unavailable.
public actor FoundationModelsProvider: AIProvider {
    public init?() {
        nil
    }

    public func generateDNA(context: EcosystemSnapshot) async throws -> SpeciesDNA {
        throw AIProviderError.unavailable
    }

    public func explain(question: String, context: EcosystemSnapshot) async throws -> String {
        throw AIProviderError.unavailable
    }
}

#endif
