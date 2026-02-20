import Foundation

public enum AIStage: String, Sendable {
    case intro
    case mutation
    case analysis
}

/// Prompt templates that inject runtime ecosystem context into both AI paths.
public enum PromptBuilder {
    private struct HueBand {
        let name: String
        let aliases: [String]
        let ranges: [ClosedRange<Int>]
    }

    private static let hueBands: [HueBand] = [
        HueBand(name: "red", aliases: ["red", "crimson", "scarlet"], ranges: [0...20, 340...360]),
        HueBand(name: "orange", aliases: ["orange"], ranges: [21...45]),
        HueBand(name: "yellow", aliases: ["yellow"], ranges: [46...70]),
        HueBand(name: "green", aliases: ["green", "lime"], ranges: [71...170]),
        HueBand(name: "cyan", aliases: ["cyan", "teal", "aqua"], ranges: [171...200]),
        HueBand(name: "blue", aliases: ["blue", "azure"], ranges: [201...250]),
        HueBand(name: "purple", aliases: ["purple", "violet", "magenta"], ranges: [251...300]),
        HueBand(name: "pink", aliases: ["pink", "rose"], ranges: [301...339])
    ]

    // Shared injection constraints used by both AI prompts and runtime planning.
    public static let injectPopulationRange: ClosedRange<Int> = 72...300
    public static let injectSpeciesCountRange: ClosedRange<Int> = 4...8
    public static let injectDNATimeoutSecondsRange: ClosedRange<Int> = 9...12

    public static func dnaPrompt(context: EcosystemSnapshot, stage: AIStage = .mutation) -> String {
        let dominant = context.speciesStats.first
        let dominantShare = {
            guard let dominant else { return 0.0 }
            return Double(Float(dominant.count) / Float(max(1, context.totalBoids)))
        }()

        let topSpecies = context.speciesStats
            .prefix(4)
            .map { "\($0.name)(\($0.count),E\(String(format: "%.2f", $0.averageEnergy)))" }
            .joined(separator: ", ")

        let atRiskSpecies = context.speciesStats
            .filter { context.extinctionRiskSpeciesIDs.contains($0.speciesID) }
            .map { "\($0.name)(\($0.count),E\(String(format: "%.2f", $0.averageEnergy)))" }
            .joined(separator: ", ")

        let stageDirective: String = switch stage {
        case .intro:
            "Create a balanced newcomer that can coexist and increase species variety."
        case .mutation:
            "Create a non-dominant niche strategy that reduces monoculture pressure."
        case .analysis:
            "Prioritize rescuing vulnerable species with supportive, low-metabolism flocking dynamics."
        }

        let pressureFlags = [
            dominantShare > 0.55 ? "dominance-high" : nil,
            context.extinctionRiskSpeciesIDs.isEmpty ? nil : "extinction-risk-present",
            context.avgEnergy < 0.32 ? "low-energy-system" : nil
        ]
        .compactMap { $0 }
        .joined(separator: ", ")

        return """
        Design ONE new digital organism DNA.
        Objective: increase biodiversity and reduce extinction risk while staying physically plausible.
        Stage strategy: \(stageDirective)
        Ecosystem: \(context.totalBoids) organisms, avg energy \(String(format: "%.2f", context.avgEnergy))
        Dominant species: \(dominant.map { "\($0.name)(\($0.count))" } ?? "none")
        At-risk species: \(atRiskSpecies.isEmpty ? "none" : atRiskSpecies)
        Top species: \(topSpecies.isEmpty ? "none" : topSpecies)
        Pressure flags: \(pressureFlags.isEmpty ? "none" : pressureFlags)
        Injection constraints: population \(injectPopulationRange.lowerBound)-\(injectPopulationRange.upperBound), species-per-inject \(injectSpeciesCountRange.lowerBound)-\(injectSpeciesCountRange.upperBound), DNA timeout \(injectDNATimeoutSecondsRange.lowerBound)-\(injectDNATimeoutSecondsRange.upperBound)s.
        Rules:
        - Avoid copying dominant-species behavior profile.
        - Prefer moderate-to-low metabolism when at-risk species exist.
        - Keep alignment/cohesion high enough for stable flocking.
        """
    }

    public static func explainPrompt(question: String, context: EcosystemSnapshot, stage: AIStage = .analysis) -> String {
        let requestedBands = requestedHueBands(in: question)
        let colorFocus: String
        if requestedBands.isEmpty {
            colorFocus = "Color query detected: none"
        } else {
            colorFocus = requestedBands.map { band in
                let matches = context.speciesStats.filter { species in
                    hueInBand(species.hue, band: band)
                }

                if matches.isEmpty {
                    return "\(band.name): no exact hue-band match in current snapshot"
                }

                let rows = matches.prefix(6).map { species in
                    "\(species.name)(id \(species.speciesID), pop \(species.count), energy \(String(format: "%.2f", species.averageEnergy)), hue \(species.hue))"
                }.joined(separator: "; ")
                return "\(band.name): \(rows)"
            }
            .joined(separator: " | ")
        }

        let speciesDetails = context.speciesStats
            .prefix(12)
            .map { species in
                "\(species.name) | id \(species.speciesID) | pop \(species.count) | energy \(String(format: "%.2f", species.averageEnergy)) | hue \(species.hue) (\(hueLabel(for: species.hue))) | social \(String(format: "%.2f", species.socialDistance)) | align \(String(format: "%.2f", species.alignmentWeight)) | cohesion \(String(format: "%.2f", species.cohesionWeight)) | metabolism \(String(format: "%.2f", species.metabolismRate)) | maxSpeed \(String(format: "%.0f", species.maxSpeed))"
            }
            .joined(separator: " || ")

        return """
        You are an ecosystem analyst. Answer in English only.
        Respond using GitHub-flavored Markdown.
        Do not wrap the entire response in triple-backtick code fences.
        Follow the user's requested output format and structure if specified.
        If no explicit format is requested, use a short analytical summary plus evidence bullets.
        If the user asks about a specific color/species, answer that target first with exact numbers from the data.
        If data is missing, say it directly instead of guessing.
        Question: \(question)
        Ecosystem: \(context.totalBoids) organisms, avg energy \(String(format: "%.2f", context.avgEnergy))
        Color band reference by hue:
        red 0-20/340-360 | orange 21-45 | yellow 46-70 | green 71-170 | cyan 171-200 | blue 201-250 | purple 251-300 | pink 301-339
        \(colorFocus)
        Species detail table: \(speciesDetails.isEmpty ? "none" : speciesDetails)
        """
    }

    public static func dnaClusterPrompt(context: EcosystemSnapshot, stage: AIStage = .mutation, count: Int) -> String {
        let target = max(1, count)
        let dominant = context.speciesStats.first

        let topSpecies = context.speciesStats
            .prefix(4)
            .map { "\($0.name)(\($0.count),E\(String(format: "%.2f", $0.averageEnergy)))" }
            .joined(separator: ", ")

        let atRiskSpecies = context.speciesStats
            .filter { context.extinctionRiskSpeciesIDs.contains($0.speciesID) }
            .map { "\($0.name)(\($0.count),E\(String(format: "%.2f", $0.averageEnergy)))" }
            .joined(separator: ", ")

        let stageDirective: String = switch stage {
        case .intro:
            "Create balanced newcomers that can coexist and increase species variety."
        case .mutation:
            "Create non-dominant niche strategies that reduce monoculture pressure."
        case .analysis:
            "Prioritize rescuing vulnerable species with supportive, low-metabolism flocking dynamics."
        }

        return """
        Design EXACTLY \(target) distinct digital organism DNA entries in one response.
        Objective: increase biodiversity and reduce extinction risk while staying physically plausible.
        Stage strategy: \(stageDirective)
        Ecosystem: \(context.totalBoids) organisms, avg energy \(String(format: "%.2f", context.avgEnergy))
        Dominant species: \(dominant.map { "\($0.name)(\($0.count))" } ?? "none")
        At-risk species: \(atRiskSpecies.isEmpty ? "none" : atRiskSpecies)
        Top species: \(topSpecies.isEmpty ? "none" : topSpecies)
        Rules:
        - Make entries behaviorally distinct from each other.
        - Avoid copying dominant-species behavior profile.
        - Prefer moderate-to-low metabolism when at-risk species exist.
        """
    }

    private static func requestedHueBands(in question: String) -> [HueBand] {
        let lower = question.lowercased()
        let tokenSet = Set(
            lower
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
        )

        return hueBands.filter { band in
            band.aliases.contains { alias in
                let asciiWord = alias.allSatisfy { $0.isASCII && $0.isLetter }
                return asciiWord ? tokenSet.contains(alias) : lower.contains(alias)
            }
        }
    }

    private static func hueLabel(for hue: Int) -> String {
        let normalized = normalizedHue(hue)
        if let band = hueBands.first(where: { hueInBand(normalized, band: $0) }) {
            return band.name
        }
        return "unknown"
    }

    private static func hueInBand(_ hue: Int, band: HueBand) -> Bool {
        let normalized = normalizedHue(hue)
        return band.ranges.contains { range in
            range.contains(normalized)
        }
    }

    private static func normalizedHue(_ hue: Int) -> Int {
        let value = hue % 360
        return value < 0 ? value + 360 : value
    }
}
