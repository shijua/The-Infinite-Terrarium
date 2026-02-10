import SwiftUI

public struct FeedPulse: Sendable {
    public let worldPoint: SIMD2<Float>
    public let issuedAtReferenceTime: TimeInterval

    public init(worldPoint: SIMD2<Float>, issuedAtReferenceTime: TimeInterval) {
        self.worldPoint = worldPoint
        self.issuedAtReferenceTime = issuedAtReferenceTime
    }
}

/// Primary visual surface that renders background, boids, and shader effects.
public struct TerrariumCanvasView: View {
    public let boids: [Boid]
    public let snapshot: EcosystemSnapshot
    public let worldBounds: SpatialBounds
    public let renderParameters: RenderParameters
    public let timelineDate: Date
    public let feedPulse: FeedPulse?

    public init(
        boids: [Boid],
        snapshot: EcosystemSnapshot,
        worldBounds: SpatialBounds,
        renderParameters: RenderParameters,
        timelineDate: Date,
        feedPulse: FeedPulse?
    ) {
        self.boids = boids
        self.snapshot = snapshot
        self.worldBounds = worldBounds
        self.renderParameters = renderParameters
        self.timelineDate = timelineDate
        self.feedPulse = feedPulse
    }

    public var body: some View {
        GeometryReader { geometry in
            let time = Float(timelineDate.timeIntervalSinceReferenceDate)

            Canvas(opaque: false, colorMode: .extendedLinear, rendersAsynchronously: true) { context, size in
                drawBackground(in: &context, size: size, time: time)
                drawOrganisms(in: &context, size: size)
                drawFeedPulse(in: &context, size: size, time: time)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.08, blue: 0.14),
                        Color(red: 0.03, green: 0.13, blue: 0.1),
                        Color(red: 0.06, green: 0.06, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .drawingGroup(opaque: false)
            .layerEffect(
                ShaderLibrary.terrariumDistortion(
                    .float(time),
                    .float(renderParameters.refractionStrength),
                    .float(renderParameters.chromaticOffset)
                ),
                maxSampleOffset: CGSize(width: renderParameters.maxSampleOffset, height: renderParameters.maxSampleOffset),
                isEnabled: true
            )
            .colorEffect(
                ShaderLibrary.terrariumColorPulse(
                    .float(time),
                    .float(renderParameters.colorPulse)
                ),
                isEnabled: true
            )
            .animation(.easeInOut(duration: 0.22), value: renderParameters.quality)
            .overlay(alignment: .topTrailing) {
                Text("\(snapshot.totalBoids)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white.opacity(0.8))
                    .background(Color.black.opacity(0.22), in: Capsule())
                    .padding(.top, 14)
                    .padding(.trailing, 14)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }

    private func drawBackground(in context: inout GraphicsContext, size: CGSize, time: Float) {
        let particleCount = 120

        for index in 0..<particleCount {
            let phase = Float(index) * 0.13
            let x = (sin(time * 0.14 + phase) * 0.45 + 0.5) * Float(size.width)
            let y = (cos(time * 0.11 + phase * 1.7) * 0.45 + 0.5) * Float(size.height)
            let r = CGFloat((sin(time * 0.35 + phase) * 0.5 + 0.5) * 2.8 + 0.6)

            let rect = CGRect(x: CGFloat(x) - r, y: CGFloat(y) - r, width: r * 2, height: r * 2)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(Color.white.opacity(Double(renderParameters.backgroundParticleAlpha) * 0.4))
            )
        }
    }

    private func drawOrganisms(in context: inout GraphicsContext, size: CGSize) {
        context.blendMode = .plusLighter

        // Map simulation coordinates into canvas pixel space.
        let worldSize = worldBounds.size
        let sx = size.width / CGFloat(max(worldSize.x, 1))
        let sy = size.height / CGFloat(max(worldSize.y, 1))

        for boid in boids {
            let normalized = boid.position - worldBounds.min
            let point = CGPoint(x: CGFloat(normalized.x) * sx, y: CGFloat(normalized.y) * sy)

            let radius = CGFloat(renderParameters.organismRadius + boid.energy * 2.2)
            let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)

            let hue = hueForSpecies(boid.speciesID)
            let energyAlpha = min(1.0, max(0.15, Double(boid.energy)))

            context.fill(
                Path(ellipseIn: rect),
                with: .color(Color(hue: hue, saturation: 0.82, brightness: 0.98, opacity: energyAlpha * 0.6))
            )
        }
    }

    private func drawFeedPulse(in context: inout GraphicsContext, size: CGSize, time: Float) {
        guard let feedPulse else {
            return
        }

        let age = time - Float(feedPulse.issuedAtReferenceTime)
        guard age >= 0, age <= 1.2 else {
            return
        }

        let progress = age / 1.2
        let alpha = Double(pow(1 - progress, 2)) * 0.8

        let worldSize = worldBounds.size
        let sx = size.width / CGFloat(max(worldSize.x, 1))
        let sy = size.height / CGFloat(max(worldSize.y, 1))
        let normalized = feedPulse.worldPoint - worldBounds.min
        let center = CGPoint(x: CGFloat(normalized.x) * sx, y: CGFloat(normalized.y) * sy)

        let outerRadius = CGFloat(36 + progress * 220)
        let innerRadius = CGFloat(18 + progress * 140)

        let outerRect = CGRect(
            x: center.x - outerRadius,
            y: center.y - outerRadius,
            width: outerRadius * 2,
            height: outerRadius * 2
        )

        let innerRect = CGRect(
            x: center.x - innerRadius,
            y: center.y - innerRadius,
            width: innerRadius * 2,
            height: innerRadius * 2
        )

        context.stroke(
            Path(ellipseIn: outerRect),
            with: .color(Color.green.opacity(alpha)),
            lineWidth: 2
        )

        context.stroke(
            Path(ellipseIn: innerRect),
            with: .color(Color.cyan.opacity(alpha * 0.75)),
            lineWidth: 1.5
        )
    }

    private func hueForSpecies(_ speciesID: Int) -> Double {
        // Prefer DNA hue from latest snapshot; fall back to a deterministic hash.
        if let stats = snapshot.speciesStats.first(where: { $0.speciesID == speciesID }) {
            return Double(stats.hue) / 360.0
        }

        return Double((speciesID * 37) % 360) / 360.0
    }
}
