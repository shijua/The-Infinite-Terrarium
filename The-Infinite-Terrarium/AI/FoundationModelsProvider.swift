import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Structured output contract for model-guided DNA generation.
@available(iOS 26.0, macOS 26.0, *)
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

/// Structured batch output for one-shot multi-species injection planning.
@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "A batch of digital organism DNA blueprints")
private struct GeneratedSpeciesDNABatch {
    @Guide(description: "Distinct DNA entries for one injection event")
    let species: [GeneratedSpeciesDNA]
}

/// On-device provider backed by iOS Foundation Models.
@available(iOS 26.0, macOS 26.0, *)
public actor FoundationModelsProvider: AIProvider {
    private var session: LanguageModelSession

    private static let instructions = """
        You are an AI exobiologist observing and designing digital organisms.
        Keep outputs concise and analytical.
        Prioritize physically plausible flocking traits and ecosystem balance.
        """

    private static func makeSession() -> LanguageModelSession {
        LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
    }

    /// Resets the session when the context window is exceeded.
    private func resetSession() {
        session = Self.makeSession()
    }

    /// Returns a ready `FoundationModelsProvider`, or an `UnavailableAIProvider`
    /// carrying the exact system-level reason (e.g. Apple Intelligence not enabled,
    /// model not downloaded, device ineligible).
    public static func makeOrUnavailable() -> any AIProvider {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return FoundationModelsProvider()!
        case .unavailable(let reason):
            let message: String
            switch reason {
            case .appleIntelligenceNotEnabled:
                message = "Apple Intelligence is not enabled. Go to Settings → Apple Intelligence & Siri to turn it on."
            case .deviceNotEligible:
                message = "This device is not eligible for on-device Foundation Models."
            case .modelNotReady:
                message = "The on-device model is not ready yet (still downloading or initialising). Please try again later."
            @unknown default:
                message = "On-device Foundation Model unavailable: \(reason)."
            }
            return UnavailableAIProvider(reason: message)
        }
    }

    public init?() {
        guard SystemLanguageModel.default.isAvailable else { return nil }
        session = Self.makeSession()
    }

    public func generateDNA(context: EcosystemSnapshot, stage: AIStage) async throws -> SpeciesDNA {
        do {
            return try await _generateDNA(context: context, stage: stage)
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error {
                resetSession()
                do {
                    return try await _generateDNA(context: context, stage: stage)
                } catch {
                    // Second attempt failed — give up and propagate clear error
                    throw AIProviderError.unavailableWithReason("Context window exceeded even after reset. Try restarting the app to clear conversation history.")
                }
            }
            throw error
        }
    }

    public func generateDNACluster(context: EcosystemSnapshot, stage: AIStage, count: Int) async throws -> [SpeciesDNA] {
        let target = max(1, count)

        do {
            return try await _generateDNACluster(context: context, stage: stage, count: target)
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error {
                resetSession()
                do {
                    return try await _generateDNACluster(context: context, stage: stage, count: target)
                } catch {
                    throw AIProviderError.unavailableWithReason("Context window exceeded even after reset. Try restarting the app to clear conversation history.")
                }
            }
            throw error
        }
    }

    private func _generateDNA(context: EcosystemSnapshot, stage: AIStage) async throws -> SpeciesDNA {
        let response = try await session.respond(
            to: PromptBuilder.dnaPrompt(context: context, stage: stage),
            generating: GeneratedSpeciesDNA.self
        )
        return Self.mapGeneratedDNA(response.content)
    }

    private func _generateDNACluster(context: EcosystemSnapshot, stage: AIStage, count: Int) async throws -> [SpeciesDNA] {
        let response = try await session.respond(
            to: PromptBuilder.dnaClusterPrompt(context: context, stage: stage, count: count),
            generating: GeneratedSpeciesDNABatch.self
        )

        var species = response.content.species
            .prefix(count)
            .map(Self.mapGeneratedDNA)

        // If the model returns fewer entries than requested, top up with single-shot DNA calls.
        if species.count < count {
            for _ in species.count..<count {
                species.append(try await _generateDNA(context: context, stage: stage))
            }
        }

        return species
    }

    private static func mapGeneratedDNA(_ generated: GeneratedSpeciesDNA) -> SpeciesDNA {
        SpeciesDNA(
            speciesName: generated.speciesName,
            hue: generated.hue,
            socialDistance: generated.socialDistance,
            alignmentWeight: generated.alignmentWeight,
            cohesionWeight: generated.cohesionWeight,
            metabolismRate: generated.metabolismRate,
            maxSpeed: generated.maxSpeed
        )
    }

    public func explain(question: String, context: EcosystemSnapshot) async throws -> String {
        do {
            return try await _explain(question: question, context: context)
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error {
                resetSession()
                do {
                    return try await _explain(question: question, context: context)
                } catch {
                    // Second attempt failed — give up and propagate clear error
                    throw AIProviderError.unavailableWithReason("Context window exceeded even after reset. Try restarting the app to clear conversation history.")
                }
            }
            throw error
        }
    }

    private func _explain(question: String, context: EcosystemSnapshot) async throws -> String {
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

    public func generateDNA(context: EcosystemSnapshot, stage: AIStage) async throws -> SpeciesDNA {
        throw AIProviderError.unavailable
    }

    public func generateDNACluster(context: EcosystemSnapshot, stage: AIStage, count: Int) async throws -> [SpeciesDNA] {
        throw AIProviderError.unavailable
    }

    public func explain(question: String, context: EcosystemSnapshot) async throws -> String {
        throw AIProviderError.unavailable
    }
}

#endif
