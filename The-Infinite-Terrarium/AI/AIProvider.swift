import Foundation

public enum AIProviderError: Error, LocalizedError, Sendable {
    case timeout
    case unavailable

    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "The model response timed out."
        case .unavailable:
            return "No on-device model is currently available."
        }
    }
}

/// AI contract used by UI. Both real and mock providers must satisfy this interface.
public protocol AIProvider: Sendable {
    func generateDNA(context: EcosystemSnapshot) async throws -> SpeciesDNA
    func explain(question: String, context: EcosystemSnapshot) async throws -> String
}

/// Explicit unavailable provider used when FoundationModels cannot be instantiated.
public actor UnavailableAIProvider: AIProvider {
    public init() {}

    public func generateDNA(context: EcosystemSnapshot) async throws -> SpeciesDNA {
        throw AIProviderError.unavailable
    }

    public func explain(question: String, context: EcosystemSnapshot) async throws -> String {
        throw AIProviderError.unavailable
    }
}

public enum AIProviderFactory {
    public static func makeDefault() -> any AIProvider {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), let provider = FoundationModelsProvider() {
            return provider
        }
        #endif

        return UnavailableAIProvider()
    }
}
