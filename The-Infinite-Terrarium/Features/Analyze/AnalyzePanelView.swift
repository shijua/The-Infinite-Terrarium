import SwiftUI

public struct AnalyzePanelView: View {
    public let namespace: Namespace.ID
    @Binding public var question: String
    public let response: String
    public let isLoading: Bool
    public let isCompact: Bool
    public let onAsk: () -> Void
    public let onInjectSpecies: () -> Void

    public init(
        namespace: Namespace.ID,
        question: Binding<String>,
        response: String,
        isLoading: Bool,
        isCompact: Bool,
        onAsk: @escaping () -> Void,
        onInjectSpecies: @escaping () -> Void
    ) {
        self.namespace = namespace
        _question = question
        self.response = response
        self.isLoading = isLoading
        self.isCompact = isCompact
        self.onAsk = onAsk
        self.onInjectSpecies = onInjectSpecies
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
            Text("Exobiology Console")
                .font(.system(size: isCompact ? 18 : 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)

            TextField("Ask about ecosystem dynamics...", text: $question)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: isCompact ? 10 : 12, style: .continuous))
                .foregroundStyle(.white)
                .font(.system(size: isCompact ? 15 : 16, weight: .medium, design: .rounded))
                .accessibilityIdentifier("analyze.question")

            HStack(spacing: 10) {
                Button(action: onAsk) {
                    Label("Analyze", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("analyze.run")

                Button(action: onInjectSpecies) {
                    Label("Inject Species", systemImage: "leaf.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("analyze.inject")
            }
            .controlSize(isCompact ? .small : .regular)

            Group {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Synthesizing explanation...")
                    }
                    .font(.system(size: isCompact ? 12 : 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                } else {
                    Text(response)
                        .font(.system(size: isCompact ? 13 : 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.black.opacity(0.30), in: RoundedRectangle(cornerRadius: isCompact ? 10 : 12, style: .continuous))
                }
            }
            .frame(minHeight: 72)
        }
        .padding(isCompact ? 12 : 16)
        .glassEffect()
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: isCompact ? 22 : 26, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: isCompact ? 22 : 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isCompact ? 22 : 26, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .glassEffectID("analyze.panel", in: namespace)
        .frame(maxWidth: isCompact ? .infinity : 520)
    }
}
