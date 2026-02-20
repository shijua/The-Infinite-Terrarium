import SwiftUI

/// Bottom action rail. Feed is now triggered by tapping the simulation surface.
public struct GlassToolbarView: View {
    public let isCompact: Bool
    public let onMutate: () -> Void
    public let onAnalyze: () -> Void
    public let onGuide: () -> Void

    public init(
        isCompact: Bool,
        onMutate: @escaping () -> Void,
        onAnalyze: @escaping () -> Void,
        onGuide: @escaping () -> Void
    ) {
        self.isCompact = isCompact
        self.onMutate = onMutate
        self.onAnalyze = onAnalyze
        self.onGuide = onGuide
    }

    public var body: some View {
        // Wide layout uses one row; compact layout folds into two rows.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: isCompact ? 8 : 12) {
                actionButton(
                    id: "mutate",
                    title: "Mutate",
                    subtitle: "Genetic shift",
                    symbol: "bolt.fill",
                    tint: .orange,
                    compact: false,
                    action: onMutate
                )

                actionButton(
                    id: "analyze",
                    title: "Analyze",
                    subtitle: "AI report",
                    symbol: "waveform.path.ecg",
                    tint: .cyan,
                    compact: false,
                    action: onAnalyze
                )

                guideButton(compact: false)
            }

            VStack(spacing: isCompact ? 8 : 10) {
                HStack(spacing: isCompact ? 8 : 12) {
                    actionButton(
                        id: "mutate",
                        title: "Mutate",
                        subtitle: "Genetic shift",
                        symbol: "bolt.fill",
                        tint: .orange,
                        compact: true,
                        action: onMutate
                    )

                    actionButton(
                        id: "analyze",
                        title: "Analyze",
                        subtitle: "AI report",
                        symbol: "waveform.path.ecg",
                        tint: .cyan,
                        compact: true,
                        action: onAnalyze
                    )
                }

                HStack(spacing: isCompact ? 8 : 12) {
                    guideButton(compact: true)
                }
            }
        }
        .padding(.horizontal, isCompact ? 10 : 14)
        .padding(.vertical, isCompact ? 10 : 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: isCompact ? 8 : 10, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: isCompact ? 8 : 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isCompact ? 8 : 10, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func actionButton(
        id: String,
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        compact: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Label(title, systemImage: symbol)
                    .font(.system(size: compact ? 13 : 14, weight: .semibold, design: .rounded))
                if !compact {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .opacity(0.9)
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, compact ? 9 : 10)
            .background(tint.opacity(compact ? 0.30 : 0.26), in: RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("toolbar.\(id)")
    }

    private func guideButton(compact: Bool) -> some View {
        Button(action: onGuide) {
            Label("Guide", systemImage: "info.circle.fill")
                .font(.system(size: compact ? 12 : 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                .padding(.horizontal, compact ? 10 : 12)
                .padding(.vertical, compact ? 8 : 9)
                .background(Color.black.opacity(0.30), in: RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("toolbar.guide")
    }
}
