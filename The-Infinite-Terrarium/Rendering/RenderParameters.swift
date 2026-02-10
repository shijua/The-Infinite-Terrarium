import Foundation

public enum RenderQualityLevel: String, CaseIterable, Sendable {
    case high
    case medium
    case low
}

/// Tunable rendering knobs grouped by quality tier.
public struct RenderParameters: Sendable {
    public let quality: RenderQualityLevel
    public let refractionStrength: Float
    public let chromaticOffset: Float
    public let colorPulse: Float
    public let organismRadius: Float
    public let backgroundParticleAlpha: Float
    public let maxSampleOffset: CGFloat
    public let estimatedRenderMS: Double

    public init(
        quality: RenderQualityLevel,
        refractionStrength: Float,
        chromaticOffset: Float,
        colorPulse: Float,
        organismRadius: Float,
        backgroundParticleAlpha: Float,
        maxSampleOffset: CGFloat,
        estimatedRenderMS: Double
    ) {
        self.quality = quality
        self.refractionStrength = refractionStrength
        self.chromaticOffset = chromaticOffset
        self.colorPulse = colorPulse
        self.organismRadius = organismRadius
        self.backgroundParticleAlpha = backgroundParticleAlpha
        self.maxSampleOffset = maxSampleOffset
        self.estimatedRenderMS = estimatedRenderMS
    }

    public static func preset(for quality: RenderQualityLevel) -> RenderParameters {
        switch quality {
        case .high:
            return RenderParameters(
                quality: .high,
                refractionStrength: 11,
                chromaticOffset: 1.5,
                colorPulse: 0.22,
                organismRadius: 4.8,
                backgroundParticleAlpha: 0.45,
                maxSampleOffset: 20,
                estimatedRenderMS: 6.6
            )

        case .medium:
            return RenderParameters(
                quality: .medium,
                refractionStrength: 8.2,
                chromaticOffset: 0.8,
                colorPulse: 0.16,
                organismRadius: 4.2,
                backgroundParticleAlpha: 0.34,
                maxSampleOffset: 14,
                estimatedRenderMS: 5.3
            )

        case .low:
            return RenderParameters(
                quality: .low,
                refractionStrength: 5.4,
                chromaticOffset: 0,
                colorPulse: 0.1,
                organismRadius: 3.6,
                backgroundParticleAlpha: 0.24,
                maxSampleOffset: 8,
                estimatedRenderMS: 4.1
            )
        }
    }
}
