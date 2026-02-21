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

    private enum Threshold {
        static let highOverBudgetMS = 17.8
        static let mediumOverBudgetMS = 20.2
        static let mediumUnderBudgetMS = 12.9
        static let lowUnderBudgetMS = 13.8

        static let highToMediumStreak = 18
        static let mediumToLowStreak = 24
        static let mediumToHighStreak = 120
        static let lowToMediumStreak = 180
    }

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
            resetStreaks()
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
            overBudgetStreak = nextStreak(overBudgetStreak, condition: smoothedBudgetMS > Threshold.highOverBudgetMS)
            underBudgetStreak = 0

            if overBudgetStreak >= Threshold.highToMediumStreak {
                return switchQuality(to: .medium, cooldownFrames: 120)
            }
        case .medium:
            overBudgetStreak = nextStreak(overBudgetStreak, condition: smoothedBudgetMS > Threshold.mediumOverBudgetMS)
            underBudgetStreak = nextStreak(underBudgetStreak, condition: smoothedBudgetMS < Threshold.mediumUnderBudgetMS)

            if overBudgetStreak >= Threshold.mediumToLowStreak {
                return switchQuality(to: .low, cooldownFrames: 180)
            }
            if underBudgetStreak >= Threshold.mediumToHighStreak {
                return switchQuality(to: .high, cooldownFrames: 120)
            }
        case .low:
            underBudgetStreak = nextStreak(underBudgetStreak, condition: smoothedBudgetMS < Threshold.lowUnderBudgetMS)
            overBudgetStreak = 0

            if underBudgetStreak >= Threshold.lowToMediumStreak {
                return switchQuality(to: .medium, cooldownFrames: 180)
            }
        }

        return current
    }

    private func switchQuality(to next: RenderQualityLevel, cooldownFrames: Int) -> RenderQualityLevel {
        resetStreaks()
        qualityCooldownFrames = cooldownFrames
        lastQuality = next
        return next
    }

    private func resetStreaks() {
        overBudgetStreak = 0
        underBudgetStreak = 0
    }

    private func nextStreak(_ current: Int, condition: Bool) -> Int {
        condition ? current + 1 : 0
    }
}
