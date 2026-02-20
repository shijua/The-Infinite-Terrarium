import XCTest
@testable import The_Infinite_Terrarium

final class PromptBuilderTests: XCTestCase {
    func testDNAPromptIncludesDiversityObjective() {
        let context = EcosystemSnapshot(
            timestamp: 120,
            totalBoids: 300,
            speciesStats: [
                SpeciesStats(
                    speciesID: 1,
                    name: "Crimson vorax",
                    count: 210,
                    averageEnergy: 0.41,
                    hue: 8,
                    socialDistance: 0.82,
                    alignmentWeight: 0.52,
                    cohesionWeight: 0.36,
                    metabolismRate: 1.12,
                    maxSpeed: 150
                )
            ],
            avgEnergy: 0.34,
            extinctionRiskSpeciesIDs: []
        )

        let prompt = PromptBuilder.dnaPrompt(context: context, stage: .mutation)
        XCTAssertTrue(prompt.contains("increase biodiversity"))
        XCTAssertTrue(prompt.contains("non-dominant niche strategy"))
        XCTAssertTrue(prompt.contains("Dominant species"))
        XCTAssertTrue(prompt.contains("Injection constraints"))
    }

    func testDNAPromptIncludesAtRiskSpeciesForRescueStage() {
        let context = EcosystemSnapshot(
            timestamp: 240,
            totalBoids: 220,
            speciesStats: [
                SpeciesStats(
                    speciesID: 3,
                    name: "Aether drifter",
                    count: 16,
                    averageEnergy: 0.17,
                    hue: 198,
                    socialDistance: 0.46,
                    alignmentWeight: 0.74,
                    cohesionWeight: 0.70,
                    metabolismRate: 0.94,
                    maxSpeed: 118
                ),
                SpeciesStats(
                    speciesID: 4,
                    name: "Protoflora lucens",
                    count: 130,
                    averageEnergy: 0.48,
                    hue: 145,
                    socialDistance: 0.34,
                    alignmentWeight: 0.82,
                    cohesionWeight: 0.91,
                    metabolismRate: 0.65,
                    maxSpeed: 88
                )
            ],
            avgEnergy: 0.29,
            extinctionRiskSpeciesIDs: [3]
        )

        let prompt = PromptBuilder.dnaPrompt(context: context, stage: .analysis)
        XCTAssertTrue(prompt.contains("Prioritize rescuing vulnerable species"))
        XCTAssertTrue(prompt.contains("At-risk species: Aether drifter"))
        XCTAssertTrue(prompt.contains("extinction-risk-present"))
    }

    func testDNAClusterPromptRequestsExactSpeciesCount() {
        let context = EcosystemSnapshot(
            timestamp: 90,
            totalBoids: 180,
            speciesStats: [
                SpeciesStats(
                    speciesID: 2,
                    name: "Protoflora lucens",
                    count: 88,
                    averageEnergy: 0.52,
                    hue: 145,
                    socialDistance: 0.34,
                    alignmentWeight: 0.82,
                    cohesionWeight: 0.91,
                    metabolismRate: 0.65,
                    maxSpeed: 88
                )
            ],
            avgEnergy: 0.44,
            extinctionRiskSpeciesIDs: []
        )

        let prompt = PromptBuilder.dnaClusterPrompt(context: context, stage: .mutation, count: 5)
        XCTAssertTrue(prompt.contains("EXACTLY 5"))
        XCTAssertTrue(prompt.contains("Make entries behaviorally distinct"))
    }

    func testExplainPromptSupportsFlexibleOutputFormat() {
        let context = EcosystemSnapshot(
            timestamp: 64,
            totalBoids: 120,
            speciesStats: [
                SpeciesStats(
                    speciesID: 1,
                    name: "Crimson vorax",
                    count: 48,
                    averageEnergy: 0.41,
                    hue: 8,
                    socialDistance: 0.82,
                    alignmentWeight: 0.52,
                    cohesionWeight: 0.36,
                    metabolismRate: 1.12,
                    maxSpeed: 150
                )
            ],
            avgEnergy: 0.39,
            extinctionRiskSpeciesIDs: []
        )

        let prompt = PromptBuilder.explainPrompt(question: "Please answer in table format.", context: context)
        XCTAssertTrue(prompt.contains("Answer in English only."))
        XCTAssertTrue(prompt.contains("GitHub-flavored Markdown"))
        XCTAssertTrue(prompt.contains("Do not wrap the entire response in triple-backtick code fences."))
        XCTAssertTrue(prompt.contains("Follow the user's requested output format and structure"))
        XCTAssertTrue(prompt.contains("Species detail table"))
    }

    func testExplainPromptIncludesColorFocusedSpeciesData() {
        let context = EcosystemSnapshot(
            timestamp: 180,
            totalBoids: 260,
            speciesStats: [
                SpeciesStats(
                    speciesID: 1,
                    name: "Crimson vorax",
                    count: 72,
                    averageEnergy: 0.44,
                    hue: 8,
                    socialDistance: 0.82,
                    alignmentWeight: 0.52,
                    cohesionWeight: 0.36,
                    metabolismRate: 1.12,
                    maxSpeed: 150
                ),
                SpeciesStats(
                    speciesID: 2,
                    name: "Aether drifter",
                    count: 66,
                    averageEnergy: 0.51,
                    hue: 198,
                    socialDistance: 0.48,
                    alignmentWeight: 0.72,
                    cohesionWeight: 0.66,
                    metabolismRate: 0.86,
                    maxSpeed: 116
                )
            ],
            avgEnergy: 0.46,
            extinctionRiskSpeciesIDs: []
        )

        let prompt = PromptBuilder.explainPrompt(question: "red species data", context: context)
        XCTAssertTrue(prompt.contains("Color query detected"))
        XCTAssertTrue(prompt.contains("red:"))
        XCTAssertTrue(prompt.contains("Crimson vorax"))
    }
}
