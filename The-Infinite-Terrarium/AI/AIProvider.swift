import Foundation
import os

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

public protocol AIProvider: Sendable {
    func generateDNA(context: EcosystemSnapshot) async throws -> SpeciesDNA
    func explain(question: String, context: EcosystemSnapshot) async throws -> String
}

public actor FallbackAIProvider: AIProvider {
    private let primary: (any AIProvider)?
    private let fallback: any AIProvider

    public init(primary: (any AIProvider)?, fallback: any AIProvider) {
        self.primary = primary
        self.fallback = fallback
    }

    public func generateDNA(context: EcosystemSnapshot) async throws -> SpeciesDNA {
        if let primary {
            do {
                return try await withTimeout(seconds: 1.2) {
                    try await primary.generateDNA(context: context)
                }
            } catch {
                AppLogger.ai.error("Primary DNA generation failed, using fallback: \(error.localizedDescription)")
            }
        }

        return try await fallback.generateDNA(context: context)
    }

    public func explain(question: String, context: EcosystemSnapshot) async throws -> String {
        if let primary {
            do {
                let response = try await withTimeout(seconds: 1.2) {
                    try await primary.explain(question: question, context: context)
                }

                return response.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                AppLogger.ai.error("Primary explanation failed, using fallback: \(error.localizedDescription)")
            }
        }

        return try await fallback.explain(question: question, context: context)
    }
}

public enum AIProviderFactory {
    public static func makeDefault() -> any AIProvider {
        let fallback = MockAIProvider()

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), let provider = FoundationModelsProvider() {
            return FallbackAIProvider(primary: provider, fallback: fallback)
        }
        #endif

        return fallback
    }
}

public func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            let ns = UInt64(max(0, seconds) * 1_000_000_000)
            try await Task.sleep(nanoseconds: ns)
            throw AIProviderError.timeout
        }

        guard let first = try await group.next() else {
            throw AIProviderError.timeout
        }

        group.cancelAll()
        return first
    }
}
