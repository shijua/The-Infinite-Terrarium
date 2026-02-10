import simd

public enum SimulationCommand: Sendable {
    case feed(point: SIMD2<Float>, amount: Float)
    case mutate(targetSpeciesID: Int?)
    case injectSpecies(dna: SpeciesDNA, count: Int)
}
