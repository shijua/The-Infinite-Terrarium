import SwiftUI

/// Top-left metrics panel for frame-time and ecosystem health.
public struct StatsOverlayView: View {
    private struct Metric {
        let title: String
        let value: String
    }

    public let snapshot: EcosystemSnapshot
    public let fps: Double
    public let simulationMS: Double
    public let renderMS: Double
    public let quality: RenderQualityLevel
    public let isCompact: Bool

    private var rowSpacing: CGFloat { isCompact ? 6 : 8 }
    private var panelPadding: CGFloat { isCompact ? 10 : 12 }
    private var panelCornerRadius: CGFloat { isCompact ? 8 : 10 }
    private var chipCornerRadius: CGFloat { isCompact ? 7 : 8 }

    private var performanceMetrics: [Metric] {
        [
            Metric(title: "FPS", value: String(format: "%.0f", fps)),
            Metric(title: "Sim", value: String(format: "%.1f ms", simulationMS)),
            Metric(title: "Render", value: String(format: "%.1f ms", renderMS)),
            Metric(title: "Quality", value: quality.rawValue.uppercased())
        ]
    }

    private var ecosystemMetrics: [Metric] {
        [
            Metric(title: "Population", value: "\(snapshot.totalBoids)"),
            Metric(title: "Avg Energy", value: String(format: "%.2f", snapshot.avgEnergy)),
            Metric(title: "At Risk", value: "\(snapshot.extinctionRiskSpeciesIDs.count)")
        ]
    }

    public init(
        snapshot: EcosystemSnapshot,
        fps: Double,
        simulationMS: Double,
        renderMS: Double,
        quality: RenderQualityLevel,
        isCompact: Bool
    ) {
        self.snapshot = snapshot
        self.fps = fps
        self.simulationMS = simulationMS
        self.renderMS = renderMS
        self.quality = quality
        self.isCompact = isCompact
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            metricRow(performanceMetrics)
            metricRow(ecosystemMetrics)
        }
        .padding(panelPadding)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricRow(_ metrics: [Metric]) -> some View {
        HStack(spacing: rowSpacing) {
            ForEach(metrics, id: \.title) { metric in
                metricChip(title: metric.title, value: metric.value)
            }
        }
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
        .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: chipCornerRadius, style: .continuous))
    }
}
