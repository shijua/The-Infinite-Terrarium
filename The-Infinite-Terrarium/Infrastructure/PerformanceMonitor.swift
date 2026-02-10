import Foundation
import Combine

/// Tracks rolling frame timing and recommends quality level transitions.
@MainActor
public final class PerformanceMonitor: ObservableObject {
    @Published public private(set) var fps: Double = 0
    @Published public private(set) var simulationMS: Double = 0
    @Published public private(set) var estimatedRenderMS: Double = 0

    private var frameDurations: [Double] = []
    private var smoothedBudgetMS: Double = 0
    private var overBudgetStreak = 0
    private var underBudgetStreak = 0
    private var qualityCooldownFrames = 0
    private var lastQuality: RenderQualityLevel?

    public init() {}

    public func recordFrame(simulationMS: Double, estimatedRenderMS: Double, frameDurationMS: Double) {
        self.simulationMS = simulationMS
        self.estimatedRenderMS = estimatedRenderMS

        frameDurations.append(frameDurationMS)
        if frameDurations.count > 120 {
            frameDurations.removeFirst(frameDurations.count - 120)
        }

        let avg = frameDurations.reduce(0, +) / Double(frameDurations.count)
        fps = avg == 0 ? 0 : 1000.0 / avg
    }

    public func recommendedQuality(current: RenderQualityLevel) -> RenderQualityLevel {
        if lastQuality != current {
            lastQuality = current
            overBudgetStreak = 0
            underBudgetStreak = 0
        }

        if qualityCooldownFrames > 0 {
            qualityCooldownFrames -= 1
            return current
        }

        // Budget is based on simulation + estimated render time.
        let budget = simulationMS + estimatedRenderMS
        smoothedBudgetMS = smoothedBudgetMS == 0 ? budget : (smoothedBudgetMS * 0.85 + budget * 0.15)

        switch current {
        case .high:
            if smoothedBudgetMS > 17.8 {
                overBudgetStreak += 1
            } else {
                overBudgetStreak = 0
            }
            underBudgetStreak = 0

            if overBudgetStreak >= 18 {
                return switchQuality(to: .medium, cooldownFrames: 120)
            }
        case .medium:
            if smoothedBudgetMS > 20.2 {
                overBudgetStreak += 1
            } else {
                overBudgetStreak = 0
            }

            if smoothedBudgetMS < 12.9 {
                underBudgetStreak += 1
            } else {
                underBudgetStreak = 0
            }

            if overBudgetStreak >= 24 {
                return switchQuality(to: .low, cooldownFrames: 180)
            }
            if underBudgetStreak >= 120 {
                return switchQuality(to: .high, cooldownFrames: 120)
            }
        case .low:
            if smoothedBudgetMS < 13.8 {
                underBudgetStreak += 1
            } else {
                underBudgetStreak = 0
            }
            overBudgetStreak = 0

            if underBudgetStreak >= 180 {
                return switchQuality(to: .medium, cooldownFrames: 180)
            }
        }

        return current
    }

    private func switchQuality(to next: RenderQualityLevel, cooldownFrames: Int) -> RenderQualityLevel {
        overBudgetStreak = 0
        underBudgetStreak = 0
        qualityCooldownFrames = cooldownFrames
        lastQuality = next
        return next
    }
}
