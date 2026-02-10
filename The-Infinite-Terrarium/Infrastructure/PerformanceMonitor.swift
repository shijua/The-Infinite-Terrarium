import Foundation
import Combine

/// Tracks rolling frame timing and recommends quality level transitions.
@MainActor
public final class PerformanceMonitor: ObservableObject {
    @Published public private(set) var fps: Double = 0
    @Published public private(set) var simulationMS: Double = 0
    @Published public private(set) var estimatedRenderMS: Double = 0

    private var frameDurations: [Double] = []

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
        // Budget is based on simulation + estimated render time.
        let budget = simulationMS + estimatedRenderMS
        switch current {
        case .high:
            if budget > 17.2 {
                return .medium
            }
        case .medium:
            if budget > 19.0 {
                return .low
            }
            if budget < 13.5 {
                return .high
            }
        case .low:
            if budget < 14.8 {
                return .medium
            }
        }

        return current
    }
}
