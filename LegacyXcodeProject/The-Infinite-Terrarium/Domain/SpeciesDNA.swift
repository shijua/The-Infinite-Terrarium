import Foundation

/// Species-level behavior coefficients shared by all boids in a species.
public struct SpeciesDNA: Codable, Sendable, Hashable {
    public let speciesName: String
    public let hue: Int
    public let socialDistance: Float
    public let alignmentWeight: Float
    public let cohesionWeight: Float
    public let metabolismRate: Float
    public let maxSpeed: Float

    public init(
        speciesName: String,
        hue: Int,
        socialDistance: Float,
        alignmentWeight: Float,
        cohesionWeight: Float,
        metabolismRate: Float,
        maxSpeed: Float
    ) {
        // Clamp every generated value so physics remains stable.
        let normalizedName = speciesName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.speciesName = normalizedName.isEmpty ? "Species" : normalizedName

        let clampedHue = max(0, min(360, hue))
        self.hue = Self.mappedHue(forSpeciesName: self.speciesName) ?? clampedHue
        self.socialDistance = max(0.0, min(1.0, socialDistance))
        self.alignmentWeight = max(0.0, min(2.0, alignmentWeight))
        self.cohesionWeight = max(0.0, min(2.0, cohesionWeight))
        self.metabolismRate = max(0.05, min(2.5, metabolismRate))
        self.maxSpeed = max(10.0, min(220.0, maxSpeed))
    }
}

public extension SpeciesDNA {
    private struct HueBand {
        let name: String
        let ranges: [ClosedRange<Int>]
        let canonicalHue: Int
    }

    private static let hueBands: [HueBand] = [
        HueBand(name: "red", ranges: [0...14, 345...359], canonicalHue: 0),
        HueBand(name: "vermilion", ranges: [15...29], canonicalHue: 22),
        HueBand(name: "orange", ranges: [30...44], canonicalHue: 37),
        HueBand(name: "amber", ranges: [45...59], canonicalHue: 52),
        HueBand(name: "yellow", ranges: [60...74], canonicalHue: 67),
        HueBand(name: "lime", ranges: [75...99], canonicalHue: 87),
        HueBand(name: "green", ranges: [100...129], canonicalHue: 114),
        HueBand(name: "emerald", ranges: [130...154], canonicalHue: 142),
        HueBand(name: "teal", ranges: [155...174], canonicalHue: 164),
        HueBand(name: "cyan", ranges: [175...194], canonicalHue: 184),
        HueBand(name: "sky", ranges: [195...214], canonicalHue: 204),
        HueBand(name: "blue", ranges: [215...239], canonicalHue: 227),
        HueBand(name: "indigo", ranges: [240...259], canonicalHue: 249),
        HueBand(name: "violet", ranges: [260...279], canonicalHue: 269),
        HueBand(name: "purple", ranges: [280...299], canonicalHue: 289),
        HueBand(name: "magenta", ranges: [300...319], canonicalHue: 309),
        HueBand(name: "pink", ranges: [320...334], canonicalHue: 327),
        HueBand(name: "rose", ranges: [335...344], canonicalHue: 339)
    ]

    static var allowedColorNames: [String] {
        hueBands.map(\.name)
    }

    static var colorReferenceText: String {
        hueBands
            .map { band in
                let rangeText = band.ranges
                    .map { "\($0.lowerBound)-\($0.upperBound)" }
                    .joined(separator: "/")
                return "\(band.name) \(rangeText)"
            }
            .joined(separator: " | ")
    }

    static func mappedHue(forSpeciesName name: String) -> Int? {
        let lower = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return nil }
        return hueBands.first(where: { $0.name == lower })?.canonicalHue
    }

    static func canonicalHue(forColorName name: String) -> Int? {
        mappedHue(forSpeciesName: name)
    }

    static func canonicalColorName(from rawName: String, fallbackHue: Int) -> String {
        let lower = rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let matched = hueBands.first(where: { $0.name == lower }) {
            return matched.name
        }
        return colorName(forHue: fallbackHue)
    }

    static func colorName(forHue hue: Int) -> String {
        let normalized = normalizedHue(hue)
        if let band = hueBands.first(where: { hueInBand(normalized, band: $0) }) {
            return band.name
        }
        return "unknown"
    }

    static func speciesGroupName(forHue hue: Int) -> String {
        colorName(forHue: hue).capitalized
    }

    static func normalizedHue(_ hue: Int) -> Int {
        let value = hue % 360
        return value < 0 ? value + 360 : value
    }

    private static func hueInBand(_ hue: Int, band: HueBand) -> Bool {
        band.ranges.contains { range in
            range.contains(hue)
        }
    }

    /// Default balanced species used during engine bootstrap.
    static let pioneer = SpeciesDNA(
        speciesName: "Protoflora lucens",
        hue: 145,
        socialDistance: 0.34,
        alignmentWeight: 0.82,
        cohesionWeight: 0.91,
        metabolismRate: 0.65,
        maxSpeed: 88
    )

    /// Mid-range roaming species.
    static let drifter = SpeciesDNA(
        speciesName: "Aether drifter",
        hue: 198,
        socialDistance: 0.48,
        alignmentWeight: 0.72,
        cohesionWeight: 0.66,
        metabolismRate: 0.86,
        maxSpeed: 116
    )

    /// Fast high-pressure predator profile.
    static let hunter = SpeciesDNA(
        speciesName: "Crimson vorax",
        hue: 8,
        socialDistance: 0.84,
        alignmentWeight: 0.48,
        cohesionWeight: 0.34,
        metabolismRate: 1.22,
        maxSpeed: 154
    )
}
