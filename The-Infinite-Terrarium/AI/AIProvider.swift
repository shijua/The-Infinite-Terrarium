import Foundation

public enum AIProviderError: Error, LocalizedError, Sendable {
    case timeout
    case unavailable
    case unavailableWithReason(String)

    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "AI request timed out after 30 seconds. The model may be overloaded — try again."
        case .unavailable:
            return "No on-device model is currently available."
        case .unavailableWithReason(let reason):
            return reason
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
    private let reason: String

    public init(reason: String = "No on-device model is currently available.") {
        self.reason = reason
    }

    public func generateDNA(context: EcosystemSnapshot) async throws -> SpeciesDNA {
        throw AIProviderError.unavailableWithReason(reason)
    }

    public func explain(question: String, context: EcosystemSnapshot) async throws -> String {
        throw AIProviderError.unavailableWithReason(reason)
    }
}

public enum AIProviderFactory {
    public static func makeDefault() -> any AIProvider {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return FoundationModelsProvider.makeOrUnavailable()
        }
        #endif

        return UnavailableAIProvider(reason: "FoundationModels framework is not available on this platform.")
    }
}
