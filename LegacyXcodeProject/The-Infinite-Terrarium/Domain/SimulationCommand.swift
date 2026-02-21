import simd

/// User or AI actions that mutate simulation state at the next frame boundary.
public enum SimulationCommand: Sendable {
    case feed(point: SIMD2<Float>, amount: Float)
    case mutate(targetHue: Int?)
    case injectSpecies(dna: SpeciesDNA, count: Int)
}
