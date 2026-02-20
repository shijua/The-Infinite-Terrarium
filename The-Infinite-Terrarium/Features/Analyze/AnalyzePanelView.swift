import SwiftUI
import MarkdownUI

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

            TextField(
                "",
                text: $question,
                prompt: Text("Ask about ecosystem dynamics...")
                    .foregroundStyle(.white.opacity(0.78))
            )
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
                        Text("AI is processing...")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.system(size: isCompact ? 12 : 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                } else {
                    responseContent
                        .frame(maxHeight: isCompact ? 220 : 300, alignment: .top)
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

    private var responseContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Markdown(normalizedResponse)
                .markdownTheme(whiteMarkdownTheme)
                .tint(.white)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    private var whiteMarkdownTheme: Theme {
        Theme.basic
            .text {
                ForegroundColor(.white.opacity(0.95))
                BackgroundColor(nil)
            }
            .strong {
                ForegroundColor(.white)
                FontWeight(.semibold)
            }
            .emphasis {
                ForegroundColor(.white.opacity(0.95))
                FontStyle(.italic)
            }
            .code {
                ForegroundColor(.white.opacity(0.95))
                BackgroundColor(nil)
                FontFamilyVariant(.monospaced)
            }
            .link {
                ForegroundColor(.white)
                UnderlineStyle(.single)
            }
            .codeBlock { configuration in
                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(.white.opacity(0.95))
                        BackgroundColor(nil)
                        FontFamilyVariant(.monospaced)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(0.15))
                    .relativePadding(.leading, length: .rem(1))
                    .markdownMargin(top: .zero, bottom: .em(1))
            }
    }

    private var normalizedResponse: String {
        normalizeResponse(response)
    }

    private func normalizeResponse(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutFence = unwrapMarkdownFenceIfNeeded(trimmed)
        return decodeEscapedNewlinesIfNeeded(withoutFence)
    }

    private func unwrapMarkdownFenceIfNeeded(_ text: String) -> String {
        guard text.hasPrefix("```"), text.hasSuffix("```") else { return text }

        let lines = text.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return text }

        let firstLine = lines[0].trimmingCharacters(in: .whitespaces)
        let lastLine = lines[lines.count - 1].trimmingCharacters(in: .whitespaces)
        guard firstLine.hasPrefix("```"), lastLine == "```" else { return text }

        let language = firstLine
            .dropFirst(3)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let allowed: Set<String> = ["", "markdown", "md", "gfm", "text", "txt"]
        guard allowed.contains(language) else { return text }

        return lines.dropFirst().dropLast().joined(separator: "\n")
    }

    private func decodeEscapedNewlinesIfNeeded(_ text: String) -> String {
        guard !text.contains("\n"), text.contains("\\n") else { return text }

        var output = text
        if output.hasPrefix("\""), output.hasSuffix("\""), output.count >= 2 {
            output.removeFirst()
            output.removeLast()
        }

        output = output
            .replacingOccurrences(of: "\\r\\n", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "\t")
            .replacingOccurrences(of: "\\\"", with: "\"")

        return output
    }
}
