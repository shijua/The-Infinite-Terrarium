import SwiftUI

/// Bottom action rail. Triggers the three required interactions: Feed, Mutate, Analyze.
public struct GlassToolbarView: View {
    public let namespace: Namespace.ID
    public let quality: RenderQualityLevel
    public let isCompact: Bool
    public let onFeed: () -> Void
    public let onMutate: () -> Void
    public let onAnalyze: () -> Void

    public init(
        namespace: Namespace.ID,
        quality: RenderQualityLevel,
        isCompact: Bool,
        onFeed: @escaping () -> Void,
        onMutate: @escaping () -> Void,
        onAnalyze: @escaping () -> Void
    ) {
        self.namespace = namespace
        self.quality = quality
        self.isCompact = isCompact
        self.onFeed = onFeed
        self.onMutate = onMutate
        self.onAnalyze = onAnalyze
    }

    public var body: some View {
        GlassEffectContainer(spacing: isCompact ? 8 : 12) {
            // Wide layout uses one row; compact layout folds into two rows.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: isCompact ? 8 : 12) {
                    actionButton(
                        id: "feed",
                        title: "Feed",
                        subtitle: "Energy pulse",
                        symbol: "drop.fill",
                        tint: .green,
                        compact: false,
                        action: onFeed
                    )

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

                    qualityBadge(compact: false)
                }

                VStack(spacing: isCompact ? 8 : 10) {
                    HStack(spacing: isCompact ? 8 : 12) {
                        actionButton(
                            id: "feed",
                            title: "Feed",
                            subtitle: "Energy pulse",
                            symbol: "drop.fill",
                            tint: .green,
                            compact: true,
                            action: onFeed
                        )

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

                    qualityBadge(compact: true)
                }
            }
            .padding(.horizontal, isCompact ? 10 : 14)
            .padding(.vertical, isCompact ? 10 : 12)
        }
        .glassEffect()
        .background(Color.black.opacity(0.30), in: RoundedRectangle(cornerRadius: isCompact ? 14 : 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: isCompact ? 14 : 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isCompact ? 14 : 18, style: .continuous)
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
        .glassEffect()
        .glassEffectID(id, in: namespace)
    }

    private func qualityBadge(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Quality")
                .font(.system(size: compact ? 9 : 10, weight: .medium, design: .rounded))
                .opacity(0.85)
            Text(quality.rawValue.uppercased())
                .font(.system(size: compact ? 11 : 12, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 7 : 8)
        .background(Color.black.opacity(0.36), in: RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous))
        .glassEffect()
        .glassEffectID("quality", in: namespace)
    }
}
