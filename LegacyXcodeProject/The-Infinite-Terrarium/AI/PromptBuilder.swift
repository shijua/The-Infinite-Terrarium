import Foundation

public enum AIStage: String, Sendable {
    case intro
    case mutation
    case analysis
}

/// Prompt templates that inject runtime ecosystem context into both AI paths.
public enum PromptBuilder {
    private static var allowedColorNames: [String] {
        SpeciesDNA.allowedColorNames
    }

    private static var allowedColorNamesText: String {
        allowedColorNames.joined(separator: ", ")
    }

    // Shared injection constraints used by both AI prompts and runtime planning.
    public static let injectPopulationRange: ClosedRange<Int> = 72...300
    public static let injectSpeciesCountRange: ClosedRange<Int> = 4...8
    public static let injectDNATimeoutSecondsRange: ClosedRange<Int> = 9...12

    public static func dnaPrompt(context: EcosystemSnapshot, stage: AIStage = .mutation) -> String {
        let dominant = context.speciesStats.first
        let dominantShare = dominantShare(in: context)
        let topSpecies = topSpeciesSummary(in: context, limit: 4)
        let atRiskSpecies = atRiskSpeciesSummary(in: context)
        let stageDirective = singleStageDirective(for: stage)

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
        Ecosystem: \(context.totalBoids) organisms, avg energy \(fmt2(context.avgEnergy))
        Dominant species: \(dominant.map { "\($0.name)(\($0.count))" } ?? "none")
        At-risk species: \(atRiskSpecies.isEmpty ? "none" : atRiskSpecies)
        Top species: \(topSpecies.isEmpty ? "none" : topSpecies)
        Pressure flags: \(pressureFlags.isEmpty ? "none" : pressureFlags)
        Allowed color names for speciesName (use EXACTLY one): \(allowedColorNamesText)
        Injection constraints: population \(injectPopulationRange.lowerBound)-\(injectPopulationRange.upperBound), species-per-inject \(injectSpeciesCountRange.lowerBound)-\(injectSpeciesCountRange.upperBound), DNA timeout \(injectDNATimeoutSecondsRange.lowerBound)-\(injectDNATimeoutSecondsRange.upperBound)s.
        Rules:
        - speciesName must be one exact color name from the allowed list.
        - Avoid copying dominant-species behavior profile.
        - Prefer moderate-to-low metabolism when at-risk species exist.
        - Keep alignment/cohesion high enough for stable flocking.
        """
    }

    public static func explainPrompt(question: String, context: EcosystemSnapshot, stage: AIStage = .analysis) -> String {
        let requestedColors = requestedColorNames(in: question)
        let colorFocus: String
        if requestedColors.isEmpty {
            colorFocus = "Color query detected: none"
        } else {
            colorFocus = requestedColors.map { colorName in
                let matches = context.speciesStats.filter { species in
                    SpeciesDNA.colorName(forHue: species.hue) == colorName
                }

                if matches.isEmpty {
                    return "\(colorName): no exact hue-band match in current snapshot"
                }

                let rows = matches.prefix(6).map { species in
                    "\(species.name)(id \(species.speciesID), pop \(species.count), energy \(fmt2(species.averageEnergy)), hue \(species.hue))"
                }.joined(separator: "; ")
                return "\(colorName): \(rows)"
            }
            .joined(separator: " | ")
        }

        let speciesDetails = context.speciesStats
            .prefix(12)
            .map(speciesDetailLine)
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
        Ecosystem: \(context.totalBoids) organisms, avg energy \(fmt2(context.avgEnergy))
        Color band reference by hue:
        \(SpeciesDNA.colorReferenceText)
        \(colorFocus)
        Species detail table: \(speciesDetails.isEmpty ? "none" : speciesDetails)
        """
    }

    public static func dnaClusterPrompt(context: EcosystemSnapshot, stage: AIStage = .mutation, count: Int) -> String {
        let target = max(1, count)
        let dominant = context.speciesStats.first
        let topSpecies = topSpeciesSummary(in: context, limit: 4)
        let atRiskSpecies = atRiskSpeciesSummary(in: context)
        let stageDirective = clusterStageDirective(for: stage)

        return """
        Design EXACTLY \(target) distinct digital organism DNA entries in one response.
        Objective: increase biodiversity and reduce extinction risk while staying physically plausible.
        Stage strategy: \(stageDirective)
        Ecosystem: \(context.totalBoids) organisms, avg energy \(fmt2(context.avgEnergy))
        Dominant species: \(dominant.map { "\($0.name)(\($0.count))" } ?? "none")
        At-risk species: \(atRiskSpecies.isEmpty ? "none" : atRiskSpecies)
        Top species: \(topSpecies.isEmpty ? "none" : topSpecies)
        Allowed color names for speciesName (use EXACTLY one): \(allowedColorNamesText)
        Rules:
        - Make entries behaviorally distinct from each other.
        - speciesName must be one exact color name from the allowed list.
        - Use color as top-level species and represent subtype differences via parameters (maxSpeed, metabolismRate, socialDistance, alignmentWeight, cohesionWeight).
        - At least one color should appear in multiple entries as parameter variants.
        - Avoid copying dominant-species behavior profile.
        - Prefer moderate-to-low metabolism when at-risk species exist.
        """
    }

    private static func requestedColorNames(in question: String) -> [String] {
        let lower = question.lowercased()
        let tokenSet = Set(
            lower
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
        )

        return allowedColorNames.filter { colorName in
            tokenSet.contains(colorName)
        }
    }

    private static func hueLabel(for hue: Int) -> String {
        SpeciesDNA.colorName(forHue: hue)
    }

    private static func dominantShare(in context: EcosystemSnapshot) -> Double {
        guard let dominant = context.speciesStats.first else { return 0.0 }
        return Double(Float(dominant.count) / Float(max(1, context.totalBoids)))
    }

    private static func topSpeciesSummary(in context: EcosystemSnapshot, limit: Int) -> String {
        context.speciesStats
            .prefix(limit)
            .map(compactSpeciesSummaryToken)
            .joined(separator: ", ")
    }

    private static func atRiskSpeciesSummary(in context: EcosystemSnapshot) -> String {
        context.speciesStats
            .filter { context.extinctionRiskSpeciesIDs.contains($0.speciesID) }
            .map(compactSpeciesSummaryToken)
            .joined(separator: ", ")
    }

    private static func compactSpeciesSummaryToken(_ species: SpeciesStats) -> String {
        "\(species.name)(\(species.count),E\(fmt2(species.averageEnergy)))"
    }

    private static func speciesDetailLine(_ species: SpeciesStats) -> String {
        "\(species.name) | id \(species.speciesID) | pop \(species.count) | energy \(fmt2(species.averageEnergy)) | hue \(species.hue) (\(hueLabel(for: species.hue))) | social \(fmt2(species.socialDistance)) | align \(fmt2(species.alignmentWeight)) | cohesion \(fmt2(species.cohesionWeight)) | metabolism \(fmt2(species.metabolismRate)) | maxSpeed \(fmt0(species.maxSpeed))"
    }

    private static func singleStageDirective(for stage: AIStage) -> String {
        switch stage {
        case .intro:
            "Create a balanced newcomer that can coexist and increase species variety."
        case .mutation:
            "Create a non-dominant niche strategy that reduces monoculture pressure."
        case .analysis:
            "Prioritize rescuing vulnerable species with supportive, low-metabolism flocking dynamics."
        }
    }

    private static func clusterStageDirective(for stage: AIStage) -> String {
        switch stage {
        case .intro:
            "Create balanced newcomers that can coexist and increase species variety."
        case .mutation:
            "Create non-dominant niche strategies that reduce monoculture pressure."
        case .analysis:
            "Prioritize rescuing vulnerable species with supportive, low-metabolism flocking dynamics."
        }
    }

    private static func fmt2(_ value: Float) -> String {
        String(format: "%.2f", value)
    }

    private static func fmt0(_ value: Float) -> String {
        String(format: "%.0f", value)
    }
}
