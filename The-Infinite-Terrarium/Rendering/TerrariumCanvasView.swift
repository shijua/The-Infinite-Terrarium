import SwiftUI

public struct TerrariumCanvasView: View {
    public let boids: [Boid]
    public let snapshot: EcosystemSnapshot
    public let worldBounds: SpatialBounds
    public let renderParameters: RenderParameters
    public let timelineDate: Date

    public init(
        boids: [Boid],
        snapshot: EcosystemSnapshot,
        worldBounds: SpatialBounds,
        renderParameters: RenderParameters,
        timelineDate: Date
    ) {
        self.boids = boids
        self.snapshot = snapshot
        self.worldBounds = worldBounds
        self.renderParameters = renderParameters
        self.timelineDate = timelineDate
    }

    public var body: some View {
        GeometryReader { geometry in
            let time = Float(timelineDate.timeIntervalSinceReferenceDate)

            Canvas(opaque: false, colorMode: .extendedLinear, rendersAsynchronously: true) { context, size in
                drawBackground(in: &context, size: size, time: time)
                drawOrganisms(in: &context, size: size)
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

    private func hueForSpecies(_ speciesID: Int) -> Double {
        if let stats = snapshot.speciesStats.first(where: { $0.speciesID == speciesID }) {
            return Double(stats.hue) / 360.0
        }

        return Double((speciesID * 37) % 360) / 360.0
    }
}
