import Foundation

public enum AIProviderError: Error, LocalizedError, Sendable {
    case timeout
    case unavailable
    case unavailableWithReason(String)

    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "AI request timed out. The model may be overloaded — try again."
        case .unavailable:
            return "No on-device model is currently available."
        case .unavailableWithReason(let reason):
            return reason
        }
    }
}

/// AI contract used by UI. Both real and mock providers must satisfy this interface.
public protocol AIProvider: Sendable {
    func generateDNA(context: EcosystemSnapshot, stage: AIStage) async throws -> SpeciesDNA
    func generateDNACluster(context: EcosystemSnapshot, stage: AIStage, count: Int) async throws -> [SpeciesDNA]
    func explain(question: String, context: EcosystemSnapshot) async throws -> String
}

public extension AIProvider {
    func generateDNA(context: EcosystemSnapshot) async throws -> SpeciesDNA {
        try await generateDNA(context: context, stage: .mutation)
    }

    func generateDNACluster(context: EcosystemSnapshot, stage: AIStage, count: Int) async throws -> [SpeciesDNA] {
        let target = max(1, count)
        var result: [SpeciesDNA] = []
        result.reserveCapacity(target)

        for _ in 0..<target {
            result.append(try await generateDNA(context: context, stage: stage))
        }

        return result
    }
}

/// Explicit unavailable provider used when FoundationModels cannot be instantiated.
public actor UnavailableAIProvider: AIProvider {
    private let reason: String

    public init(reason: String = "No on-device model is currently available.") {
        self.reason = reason
    }

    private func unavailable<T>() throws -> T {
        throw AIProviderError.unavailableWithReason(reason)
    }

    public func generateDNA(context: EcosystemSnapshot, stage: AIStage) async throws -> SpeciesDNA {
        try unavailable()
    }

    public func generateDNACluster(context: EcosystemSnapshot, stage: AIStage, count: Int) async throws -> [SpeciesDNA] {
        try unavailable()
    }

    public func explain(question: String, context: EcosystemSnapshot) async throws -> String {
        try unavailable()
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
