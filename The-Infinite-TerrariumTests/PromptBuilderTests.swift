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
}
