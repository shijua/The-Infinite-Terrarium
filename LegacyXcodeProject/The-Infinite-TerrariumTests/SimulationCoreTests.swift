import XCTest
@testable import The_Infinite_Terrarium
import simd

final class SimulationCoreTests: XCTestCase {
    func testSpeciesDNAClampsInputRange() {
        let dna = SpeciesDNA(
            speciesName: "",
            hue: 999,
            socialDistance: 9,
            alignmentWeight: -2,
            cohesionWeight: 9,
            metabolismRate: -3,
            maxSpeed: 9999
        )

        XCTAssertEqual(dna.speciesName, "Species")
        XCTAssertEqual(dna.hue, 360)
        XCTAssertEqual(dna.socialDistance, 1.0)
        XCTAssertEqual(dna.alignmentWeight, 0.0)
        XCTAssertEqual(dna.cohesionWeight, 2.0)
        XCTAssertEqual(dna.metabolismRate, 0.05)
        XCTAssertEqual(dna.maxSpeed, 220)
    }

    func testQuadtreeQueryMatchesBruteForce() {
        var rng = DeterministicRNG(seed: 42)
        let bounds = SpatialBounds(min: .zero, max: SIMD2<Float>(400, 300))

        var boids: [Boid] = []
        for index in 0..<240 {
            boids.append(
                Boid(
                    id: index,
                    speciesID: index % 3,
                    position: SIMD2<Float>(rng.nextFloat(in: 0...400), rng.nextFloat(in: 0...300)),
                    velocity: .zero,
                    energy: 1
                )
            )
        }

        let tree = QuadtreeSnapshot(boids: boids, bounds: bounds)
        let center = SIMD2<Float>(201, 151)
        let radius: Float = 65

        let treeResult = Set(tree.query(center: center, radius: radius))
        let bruteForce = Set(
            boids.enumerated()
                .filter { simd_length_squared($0.element.position - center) <= radius * radius }
                .map(\.offset)
        )

        XCTAssertEqual(treeResult, bruteForce)
    }

    func testBoidRulesProduceFiniteValues() {
        let bounds = SpatialBounds(min: .zero, max: SIMD2<Float>(800, 600))
        var boid = Boid(id: 1, speciesID: 0, position: SIMD2<Float>(200, 200), velocity: SIMD2<Float>(15, 7), energy: 1)
        let neighbors = [
            Boid(id: 2, speciesID: 0, position: SIMD2<Float>(220, 204), velocity: SIMD2<Float>(5, 2), energy: 1),
            Boid(id: 3, speciesID: 0, position: SIMD2<Float>(208, 188), velocity: SIMD2<Float>(3, 6), energy: 1)
        ]

        BoidRules.update(
            boid: &boid,
            neighbors: neighbors,
            dna: .pioneer,
            bounds: bounds,
            deltaTime: 1.0 / 60.0
        )

        XCTAssertTrue(boid.position.x.isFinite)
        XCTAssertTrue(boid.position.y.isFinite)
        XCTAssertTrue(boid.velocity.x.isFinite)
        XCTAssertTrue(boid.velocity.y.isFinite)
        XCTAssertGreaterThanOrEqual(boid.energy, 0)
    }

    func testBoidRulesHandleZeroNeighbors() {
        let bounds = SpatialBounds(min: .zero, max: SIMD2<Float>(800, 600))
        var boid = Boid(
            id: 8,
            speciesID: 0,
            position: SIMD2<Float>(100, 120),
            velocity: SIMD2<Float>(8, -5),
            energy: 1
        )

        BoidRules.update(
            boid: &boid,
            neighbors: [],
            dna: .pioneer,
            bounds: bounds,
            deltaTime: 1.0 / 60.0
        )

        XCTAssertTrue(boid.position.x.isFinite)
        XCTAssertTrue(boid.position.y.isFinite)
        XCTAssertTrue(boid.velocity.x.isFinite)
        XCTAssertTrue(boid.velocity.y.isFinite)
        XCTAssertGreaterThanOrEqual(boid.energy, 0)
    }

    func testBoidRulesHandleExtremeVelocity() {
        let bounds = SpatialBounds(min: .zero, max: SIMD2<Float>(800, 600))
        var boid = Boid(
            id: 9,
            speciesID: 2,
            position: SIMD2<Float>(790, 590),
            velocity: SIMD2<Float>(9_000, -9_000),
            energy: 1
        )

        BoidRules.update(
            boid: &boid,
            neighbors: [],
            dna: .hunter,
            bounds: bounds,
            deltaTime: 1.0 / 60.0
        )

        XCTAssertLessThanOrEqual(simd_length(boid.velocity), SpeciesDNA.hunter.maxSpeed + 0.001)
        XCTAssertTrue(boid.position.x.isFinite)
        XCTAssertTrue(boid.position.y.isFinite)
        XCTAssertGreaterThanOrEqual(boid.position.x, bounds.min.x)
        XCTAssertLessThanOrEqual(boid.position.x, bounds.max.x)
        XCTAssertGreaterThanOrEqual(boid.position.y, bounds.min.y)
        XCTAssertLessThanOrEqual(boid.position.y, bounds.max.y)
    }

    func testEngineAdvancesWithConsistentSnapshot() async {
        let engine = SimulationEngine(initialPopulation: 320, bounds: SpatialBounds(min: .zero, max: SIMD2<Float>(800, 600)))

        var frame = await engine.step(deltaTime: 1.0 / 60.0, commands: [])
        for _ in 0..<180 {
            frame = await engine.step(deltaTime: 1.0 / 60.0, commands: [])
        }

        XCTAssertEqual(frame.snapshot.totalBoids, frame.boids.count)
        XCTAssertTrue(frame.snapshot.avgEnergy.isFinite)
        XCTAssertGreaterThanOrEqual(frame.snapshot.totalBoids, 0)
        XCTAssertLessThanOrEqual(frame.snapshot.totalBoids, 1_200)

        if frame.snapshot.totalBoids > 0 {
            XCTAssertGreaterThan(frame.snapshot.timestamp, 0)
        } else {
            XCTAssertEqual(frame.snapshot.timestamp, 0)
        }
    }

    func testEngineStepRemainsStableForFiveThousandFrames() async {
        let bounds = SpatialBounds(min: .zero, max: SIMD2<Float>(1_024, 768))
        let engine = SimulationEngine(initialPopulation: 240, bounds: bounds)

        var frame: SimulationFrame?
        for step in 0..<5_000 {
            var commands: [SimulationCommand] = []

            if step % 60 == 0 {
                commands.append(.feed(point: SIMD2<Float>(512, 384), amount: 0.1))
            }
            if step % 500 == 0 {
                commands.append(.mutate(targetHue: nil))
            }

            frame = await engine.step(deltaTime: 1.0 / 60.0, commands: commands)
        }

        guard let frame else {
            XCTFail("Expected a simulation frame after stepping.")
            return
        }

        XCTAssertGreaterThanOrEqual(frame.boids.count, 0)
        XCTAssertLessThanOrEqual(frame.boids.count, 1_200)
        XCTAssertEqual(frame.snapshot.totalBoids, frame.boids.count)
        XCTAssertTrue(frame.snapshot.avgEnergy.isFinite)
        XCTAssertTrue(frame.boids.allSatisfy { $0.position.x.isFinite && $0.position.y.isFinite })
        XCTAssertTrue(frame.boids.allSatisfy { $0.velocity.x.isFinite && $0.velocity.y.isFinite })
    }
}
