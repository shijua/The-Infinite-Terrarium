import SwiftUI

/// Expandable AI console for ecosystem explanation and species injection.
public struct AnalyzePanelView: View {
    @Binding public var question: String
    public let response: String
    public let isLoading: Bool
    public let isAIBusy: Bool
    public let isCompact: Bool
    public let onAsk: () -> Void
    public let onInjectSpecies: () -> Void

    public init(
        question: Binding<String>,
        response: String,
        isLoading: Bool,
        isAIBusy: Bool = false,
        isCompact: Bool,
        onAsk: @escaping () -> Void,
        onInjectSpecies: @escaping () -> Void
    ) {
        _question = question
        self.response = response
        self.isLoading = isLoading
        self.isAIBusy = isAIBusy
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
                .background(Color.black.opacity(0.40), in: RoundedRectangle(cornerRadius: isCompact ? 8 : 10, style: .continuous))
                .foregroundStyle(.white)
                .font(.system(size: isCompact ? 15 : 16, weight: .medium, design: .rounded))
                .accessibilityIdentifier("analyze.question")

            HStack(spacing: 10) {
                Button(action: onAsk) {
                    Label("Analyze", systemImage: "sparkles")
                        .font(.system(size: isCompact ? 14 : 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.28), radius: 1, x: 0, y: 1)
                        .padding(.vertical, isCompact ? 10 : 11)
                        .frame(maxWidth: .infinity)
                        .background(Color.cyan.opacity(isAIBusy ? 0.35 : 0.72), in: RoundedRectangle(cornerRadius: isCompact ? 8 : 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isAIBusy)
                .accessibilityIdentifier("analyze.run")

                Button(action: onInjectSpecies) {
                    Label("Inject Species", systemImage: "leaf.fill")
                        .font(.system(size: isCompact ? 14 : 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(isAIBusy ? 0.40 : 0.95))
                        .shadow(color: .black.opacity(0.26), radius: 1, x: 0, y: 1)
                        .padding(.vertical, isCompact ? 10 : 11)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: isCompact ? 8 : 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isAIBusy)
                .accessibilityIdentifier("analyze.inject")
            }

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
                        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: isCompact ? 8 : 10, style: .continuous))
                }
            }
            .frame(minHeight: 72)
        }
        .padding(isCompact ? 12 : 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: isCompact ? 8 : 10, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: isCompact ? 8 : 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isCompact ? 8 : 10, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
        .frame(maxWidth: isCompact ? .infinity : 520)
    }
}
