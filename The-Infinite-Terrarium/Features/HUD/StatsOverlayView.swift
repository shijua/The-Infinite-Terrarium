import SwiftUI

/// Top-left metrics panel for frame-time and ecosystem health.
public struct StatsOverlayView: View {
    public let snapshot: EcosystemSnapshot
    public let fps: Double
    public let simulationMS: Double
    public let renderMS: Double
    public let isCompact: Bool

    public init(snapshot: EcosystemSnapshot, fps: Double, simulationMS: Double, renderMS: Double, isCompact: Bool) {
        self.snapshot = snapshot
        self.fps = fps
        self.simulationMS = simulationMS
        self.renderMS = renderMS
        self.isCompact = isCompact
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
            HStack(spacing: isCompact ? 6 : 8) {
                metricChip(title: "FPS", value: String(format: "%.0f", fps))
                metricChip(title: "Sim", value: String(format: "%.1f ms", simulationMS))
                metricChip(title: "Render", value: String(format: "%.1f ms", renderMS))
            }

            HStack(spacing: isCompact ? 6 : 8) {
                metricChip(title: "Population", value: "\(snapshot.totalBoids)")
                metricChip(title: "Avg Energy", value: String(format: "%.2f", snapshot.avgEnergy))
                metricChip(title: "At Risk", value: "\(snapshot.extinctionRiskSpeciesIDs.count)")
            }
        }
        .padding(isCompact ? 10 : 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: isCompact ? 8 : 10, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: isCompact ? 8 : 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isCompact ? 8 : 10, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: isCompact ? 9 : 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            Text(value)
                .font(.system(size: isCompact ? 12 : 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 1, x: 0, y: 1)
        }
        .padding(.horizontal, isCompact ? 8 : 10)
        .padding(.vertical, isCompact ? 6 : 8)
        .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: isCompact ? 7 : 8, style: .continuous))
    }
}
