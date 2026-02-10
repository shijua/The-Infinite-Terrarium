import Foundation
import os
import simd

/// Frame output consumed by UI. Includes raw boids and aggregated snapshot data.
public struct SimulationFrame: Sendable {
    public let boids: [Boid]
    public let snapshot: EcosystemSnapshot
    public let worldBounds: SpatialBounds
    public let simulationMS: Double

    public init(boids: [Boid], snapshot: EcosystemSnapshot, worldBounds: SpatialBounds, simulationMS: Double) {
        self.boids = boids
        self.snapshot = snapshot
        self.worldBounds = worldBounds
        self.simulationMS = simulationMS
    }
}

public protocol SimulationEngineProtocol: Sendable {
    func step(deltaTime: Float, commands: [SimulationCommand]) async -> SimulationFrame
    func snapshot() -> EcosystemSnapshot
}

/// High-frequency simulation core.
/// State mutation is serialized at frame boundaries, while boid updates run in parallel.
public final class SimulationEngine: SimulationEngineProtocol, @unchecked Sendable {
    private struct EngineState: Sendable {
        var boids: [Boid]
        var speciesByID: [Int: SpeciesDNA]
        var snapshot: EcosystemSnapshot
        var nextBoidID: Int
        var simulationTime: TimeInterval
        var bounds: SpatialBounds
        var rng: DeterministicRNG
    }

    private let stateLock: OSAllocatedUnfairLock<EngineState>
    private let quadtree = Quadtree(capacity: 16, maxDepth: 7)
    private let batchSize = 128

    public init(initialPopulation: Int = 1_000, bounds: SpatialBounds = SpatialBounds(min: .zero, max: SIMD2<Float>(1_366, 1_024))) {
        var rng = DeterministicRNG(seed: 0xA17E_B01D)

        let speciesByID: [Int: SpeciesDNA] = [
            0: .pioneer,
            1: .drifter,
            2: .hunter
        ]

        var boids: [Boid] = []
        boids.reserveCapacity(initialPopulation)

        for _ in 0..<initialPopulation {
            let speciesID = rng.nextInt(in: 0...2)
            let position = SIMD2<Float>(
                rng.nextFloat(in: bounds.min.x...bounds.max.x),
                rng.nextFloat(in: bounds.min.y...bounds.max.y)
            )
            let velocity = SIMD2<Float>(
                rng.nextFloat(in: -45...45),
                rng.nextFloat(in: -45...45)
            )

            boids.append(
                Boid(
                    id: boids.count,
                    speciesID: speciesID,
                    position: position,
                    velocity: velocity,
                    energy: rng.nextFloat(in: 0.5...1.0)
                )
            )
        }

        let snapshot = Self.buildSnapshot(boids: boids, speciesByID: speciesByID, simulationTime: 0)

        stateLock = OSAllocatedUnfairLock(
            initialState: EngineState(
                boids: boids,
                speciesByID: speciesByID,
                snapshot: snapshot,
                nextBoidID: boids.count,
                simulationTime: 0,
                bounds: bounds,
                rng: rng
            )
        )
    }

    public func snapshot() -> EcosystemSnapshot {
        stateLock.withLock { state in
            state.snapshot
        }
    }

    /// Safety valve used by adaptive quality mode to protect frame time.
    public func trimPopulationIfNeeded(maxCount: Int) {
        stateLock.withLock { state in
            guard state.boids.count > maxCount else {
                return
            }

            state.boids.shuffle()
            state.boids.removeLast(state.boids.count - maxCount)
            state.snapshot = Self.buildSnapshot(
                boids: state.boids,
                speciesByID: state.speciesByID,
                simulationTime: state.simulationTime
            )
        }
    }

    public func step(deltaTime: Float, commands: [SimulationCommand]) async -> SimulationFrame {
        let start = ContinuousClock.now

        // Copy shared state once, compute off-lock, then swap state at frame end.
        let localState = stateLock.withLock { state in
            state
        }

        var workingBoids = localState.boids
        var speciesByID = localState.speciesByID
        var nextBoidID = localState.nextBoidID
        var rng = localState.rng

        apply(commands: commands, boids: &workingBoids, speciesByID: &speciesByID, nextBoidID: &nextBoidID, bounds: localState.bounds, rng: &rng)

        // Build an immutable spatial index for lock-free parallel neighbor lookup.
        let snapshot = quadtree.buildSnapshot(boids: workingBoids, bounds: localState.bounds)

        let updatedBoids = await updateBoids(
            boids: workingBoids,
            speciesByID: speciesByID,
            quadtreeSnapshot: snapshot,
            bounds: localState.bounds,
            deltaTime: deltaTime
        )

        let aliveBoids = updatedBoids.filter { $0.energy > 0.02 }

        let newTime = localState.simulationTime + TimeInterval(deltaTime)
        let newSnapshot = Self.buildSnapshot(boids: aliveBoids, speciesByID: speciesByID, simulationTime: newTime)
        let nextSpeciesByID = speciesByID
        let nextBoidIDValue = nextBoidID
        let nextRNG = rng

        // Commit next frame state atomically.
        stateLock.withLock { state in
            state.boids = aliveBoids
            state.speciesByID = nextSpeciesByID
            state.nextBoidID = nextBoidIDValue
            state.simulationTime = newTime
            state.snapshot = newSnapshot
            state.rng = nextRNG
        }

        let end = ContinuousClock.now
        let elapsed = start.duration(to: end).components
        let elapsedSeconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1_000_000_000_000_000_000
        let simulationMS = elapsedSeconds * 1000

        return SimulationFrame(
            boids: aliveBoids,
            snapshot: newSnapshot,
            worldBounds: localState.bounds,
            simulationMS: simulationMS
        )
    }

    private func updateBoids(
        boids: [Boid],
        speciesByID: [Int: SpeciesDNA],
        quadtreeSnapshot: QuadtreeSnapshot,
        bounds: SpatialBounds,
        deltaTime: Float
    ) async -> [Boid] {
        await withTaskGroup(of: [(Int, Boid)].self, returning: [Boid].self) { group in
            for start in stride(from: 0, to: boids.count, by: batchSize) {
                let end = min(start + batchSize, boids.count)

                group.addTask {
                    // Each task updates a disjoint index range to avoid shared writes.
                    var batch: [(Int, Boid)] = []
                    batch.reserveCapacity(end - start)

                    for index in start..<end {
                        var boid = boids[index]
                        let dna = speciesByID[boid.speciesID] ?? .pioneer

                        let neighborIndices = quadtreeSnapshot.query(center: boid.position, radius: boid.sensingRange)
                        let neighbors = neighborIndices.compactMap { neighborIndex in
                            neighborIndex == index ? nil : boids[neighborIndex]
                        }

                        BoidRules.update(
                            boid: &boid,
                            neighbors: neighbors,
                            dna: dna,
                            bounds: bounds,
                            deltaTime: deltaTime
                        )

                        batch.append((index, boid))
                    }

                    return batch
                }
            }

            var result = boids
            for await batch in group {
                for (index, boid) in batch {
                    result[index] = boid
                }
            }

            return result
        }
    }

    private func apply(
        commands: [SimulationCommand],
        boids: inout [Boid],
        speciesByID: inout [Int: SpeciesDNA],
        nextBoidID: inout Int,
        bounds: SpatialBounds,
        rng: inout DeterministicRNG
    ) {
        for command in commands {
            switch command {
            case let .feed(point, amount):
                applyFeed(point: point, amount: amount, boids: &boids)

            case let .mutate(targetSpeciesID):
                applyMutation(targetSpeciesID: targetSpeciesID, boids: &boids, speciesByID: &speciesByID, rng: &rng)

            case let .injectSpecies(dna, count):
                let speciesID = (speciesByID.keys.max() ?? -1) + 1
                speciesByID[speciesID] = dna

                for _ in 0..<max(1, count) {
                    let position = SIMD2<Float>(
                        rng.nextFloat(in: bounds.min.x...bounds.max.x),
                        rng.nextFloat(in: bounds.min.y...bounds.max.y)
                    )
                    let velocity = SIMD2<Float>(
                        rng.nextFloat(in: -70...70),
                        rng.nextFloat(in: -70...70)
                    )
                    boids.append(
                        Boid(
                            id: nextBoidID,
                            speciesID: speciesID,
                            position: position,
                            velocity: velocity,
                            energy: rng.nextFloat(in: 0.7...1.0)
                        )
                    )
                    nextBoidID += 1
                }
            }
        }

        if boids.count > 1_200 {
            // Hard cap for performance budget protection.
            boids.shuffle()
            boids.removeLast(boids.count - 1_200)
        }
    }

    private func applyFeed(point: SIMD2<Float>, amount: Float, boids: inout [Boid]) {
        let radius: Float = 210
        let deltaEnergy = max(0.02, min(0.45, amount))

        for index in boids.indices {
            let distanceSq = simd_length_squared(boids[index].position - point)
            if distanceSq <= radius * radius {
                boids[index].energy = min(1.5, boids[index].energy + deltaEnergy)
            }
        }
    }

    private func applyMutation(
        targetSpeciesID: Int?,
        boids: inout [Boid],
        speciesByID: inout [Int: SpeciesDNA],
        rng: inout DeterministicRNG
    ) {
        let selected: Int
        if let targetSpeciesID {
            selected = targetSpeciesID
        } else {
            let counts = boids.reduce(into: [Int: Int]()) { partialResult, boid in
                partialResult[boid.speciesID, default: 0] += 1
            }

            guard let dominant = counts.max(by: { $0.value < $1.value })?.key else {
                return
            }
            selected = dominant
        }

        guard let dna = speciesByID[selected] else {
            return
        }

        let baseName = normalizedMutationName(from: dna.speciesName)
        let mutated = SpeciesDNA(
            speciesName: "\(baseName) var",
            hue: Int((Float(dna.hue) + rng.nextFloat(in: -20...20)).rounded()),
            socialDistance: max(0.30, dna.socialDistance + rng.nextFloat(in: -0.08...0.10)),
            alignmentWeight: dna.alignmentWeight + rng.nextFloat(in: -0.12...0.12),
            cohesionWeight: min(0.95, dna.cohesionWeight + rng.nextFloat(in: -0.18...0.08)),
            metabolismRate: dna.metabolismRate + rng.nextFloat(in: -0.08...0.10),
            maxSpeed: dna.maxSpeed + rng.nextFloat(in: -18...18)
        )

        speciesByID[selected] = mutated

        let selectedIndices = boids.indices.filter { boids[$0].speciesID == selected }
        guard !selectedIndices.isEmpty else {
            return
        }

        var centroid = SIMD2<Float>(repeating: 0)
        for index in selectedIndices {
            centroid += boids[index].position
        }
        centroid /= Float(selectedIndices.count)

        for index in selectedIndices {
            let delta = boids[index].position - centroid
            let outwardDirection: SIMD2<Float>
            if simd_length_squared(delta) < 0.0001 {
                let random = SIMD2<Float>(
                    rng.nextFloat(in: -1...1),
                    rng.nextFloat(in: -1...1)
                )
                outwardDirection = simd_length_squared(random) < 0.0001 ? SIMD2<Float>(1, 0) : simd_normalize(random)
            } else {
                outwardDirection = simd_normalize(delta)
            }

            let outwardImpulse = outwardDirection * rng.nextFloat(in: 22...46)
            let jitter = SIMD2<Float>(
                rng.nextFloat(in: -9...9),
                rng.nextFloat(in: -9...9)
            )
            boids[index].energy = min(1.35, boids[index].energy + 0.10)
            boids[index].velocity += outwardImpulse + jitter
        }
    }

    private func normalizedMutationName(from rawName: String) -> String {
        var name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        while name.hasSuffix(" var.") || name.hasSuffix(" var") {
            if name.hasSuffix(" var.") {
                name.removeLast(5)
            } else {
                name.removeLast(4)
            }
            name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return name.isEmpty ? "Species" : name
    }

    private static func buildSnapshot(
        boids: [Boid],
        speciesByID: [Int: SpeciesDNA],
        simulationTime: TimeInterval
    ) -> EcosystemSnapshot {
        guard !boids.isEmpty else {
            return .empty
        }

        var grouped: [Int: [Boid]] = [:]
        grouped.reserveCapacity(speciesByID.count)

        for boid in boids {
            grouped[boid.speciesID, default: []].append(boid)
        }

        let stats = grouped.map { speciesID, members in
            let avgEnergy = members.map(\.energy).reduce(0, +) / Float(max(1, members.count))
            let dna = speciesByID[speciesID] ?? .pioneer
            return SpeciesStats(
                speciesID: speciesID,
                name: dna.speciesName,
                count: members.count,
                averageEnergy: avgEnergy,
                hue: dna.hue
            )
        }
        .sorted { $0.count > $1.count }

        let avgEnergy = boids.map(\.energy).reduce(0, +) / Float(max(1, boids.count))

        let extinctionRisk = stats.filter { $0.count < 24 || $0.averageEnergy < 0.23 }.map(\.speciesID)

        return EcosystemSnapshot(
            timestamp: simulationTime,
            totalBoids: boids.count,
            speciesStats: stats,
            avgEnergy: avgEnergy,
            extinctionRiskSpeciesIDs: extinctionRisk
        )
    }
}
