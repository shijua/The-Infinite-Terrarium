import SwiftUI

/// In-app quick guide for controls, quality levels, and species traits.
public struct TerrariumGuideView: View {
    private struct GuideItem {
        let title: String
        let subtitle: String
    }

    private struct KeyValueItem {
        let key: String
        let value: String
    }

    private static let overlayMetricItems: [GuideItem] = [
        GuideItem(
            title: "FPS",
            subtitle: "Current frame rate. Computed from a rolling average of recent frame durations."
        ),
        GuideItem(
            title: "Sim",
            subtitle: "Per-frame simulation time in milliseconds (boid rules, neighbor lookup, and state updates)."
        ),
        GuideItem(
            title: "Render",
            subtitle: "Estimated render cost in milliseconds from the current quality preset (not real-time GPU profiling)."
        ),
        GuideItem(
            title: "Quality",
            subtitle: "Current render tier (HIGH / MEDIUM / LOW). Adaptive quality switches with hysteresis + cooldown, so it should not flicker every frame."
        ),
        GuideItem(
            title: "Population",
            subtitle: "Total number of living boids in the current frame."
        ),
        GuideItem(
            title: "Avg Energy",
            subtitle: "Average energy across all living boids."
        ),
        GuideItem(
            title: "At Risk",
            subtitle: "Number of at-risk species (species count, not individual count). A species is at risk if count < 24 or averageEnergy < 0.23."
        )
    ]

    private static let interactionItems: [GuideItem] = [
        GuideItem(
            title: "Feed",
            subtitle: "Tap directly on the simulation surface to add a local energy pulse. Effect radius is local (~210 world units), so far-away organisms will not react immediately. There is no Feed toolbar button."
        ),
        GuideItem(
            title: "Mutate",
            subtitle: "Retunes DNA of the current dominant color lineage (not all species): social distance, alignment, cohesion, metabolism, and max speed. Also applies a short outward motion impulse."
        ),
        GuideItem(
            title: "Analyze",
            subtitle: "Opens the AI console and requests a short ecosystem explanation from the latest snapshot."
        ),
        GuideItem(
            title: "Inject Species",
            subtitle: "From the AI console, adds a generated species cluster (multiple species, randomized population split) to restore diversity."
        ),
        GuideItem(
            title: "Guide",
            subtitle: "Opening this panel pauses simulation updates. Close Guide to resume the ecosystem."
        ),
        GuideItem(
            title: "Pause Rules",
            subtitle: "Simulation keeps running while the Analyze panel is open. It pauses only while an AI request is in flight, or while Guide is open."
        )
    ]

    public let snapshot: EcosystemSnapshot
    public let renderParameters: RenderParameters
    @AppStorage("hud.showPerformanceOverlay") private var isStatsOverlayVisible = true
    @Environment(\.dismiss) private var dismiss

    private var adaptiveQualityRows: [KeyValueItem] {
        [
            KeyValueItem(key: "Current Quality", value: renderParameters.quality.rawValue.uppercased()),
            KeyValueItem(key: "Refraction Strength", value: fmt1(renderParameters.refractionStrength)),
            KeyValueItem(key: "Chromatic Offset", value: fmt1(renderParameters.chromaticOffset)),
            KeyValueItem(key: "Color Pulse", value: fmt2(renderParameters.colorPulse)),
            KeyValueItem(key: "Organism Radius", value: fmt1(renderParameters.organismRadius)),
            KeyValueItem(key: "Particle Alpha", value: fmt2(renderParameters.backgroundParticleAlpha)),
            KeyValueItem(key: "Max Sample Offset", value: String(format: "%.1f", renderParameters.maxSampleOffset)),
            KeyValueItem(key: "Estimated Render Cost", value: "\(fmt1(renderParameters.estimatedRenderMS)) ms")
        ]
    }

    public init(snapshot: EcosystemSnapshot, renderParameters: RenderParameters) {
        self.snapshot = snapshot
        self.renderParameters = renderParameters
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sectionCard(title: "HUD Visibility") {
                        Toggle(isOn: $isStatsOverlayVisible) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Show Performance Overlay")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Text("Controls the top-left FPS / Sim / Render / Quality panel on the main screen.")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }

                    sectionCard(title: "Performance Overlay Metrics") {
                        guideRows(Self.overlayMetricItems)
                    }

                    sectionCard(title: "Interaction Controls") {
                        guideRows(Self.interactionItems)
                    }

                    sectionCard(title: "Adaptive Quality") {
                        ForEach(adaptiveQualityRows, id: \.key) { row in
                            keyValueRow(key: row.key, value: row.value)
                        }
                        Text("Meaning: higher values improve visual richness but increase GPU cost; adaptive quality automatically switches between HIGH / MEDIUM / LOW to keep frame budget stable. Current quality is shown in the top-left performance overlay.")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    sectionCard(title: "Behavior Notes") {
                        guideRows([
                            GuideItem(
                                title: "Why Feed can feel weak",
                                subtitle: "Feed only affects organisms already inside the pulse radius. If your tap lands in an empty region, visible change is delayed."
                            ),
                            GuideItem(
                                title: "Why groups cluster after Mutate",
                                subtitle: "Mutation changes alignment/cohesion/social-distance together, so temporary flock clustering is expected."
                            ),
                            GuideItem(
                                title: "Why population drops",
                                subtitle: "Organisms continuously lose energy from metabolism; low-energy organisms are removed by the simulation."
                            )
                        ])
                    }

                    sectionCard(title: "Species Traits and Colors") {
                        if snapshot.speciesStats.isEmpty {
                            Text("No active species yet. Inject species or wait for simulation initialization.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(snapshot.speciesStats) { species in
                                speciesCard(species)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Terrarium Guide")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func guideRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func guideRows(_ items: [GuideItem]) -> some View {
        ForEach(items, id: \.title) { item in
            guideRow(title: item.title, subtitle: item.subtitle)
        }
    }

    private func keyValueRow(key: String, value: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
    }

    private func speciesCard(_ species: SpeciesStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hue: Double(species.hue) / 360.0, saturation: 0.85, brightness: 0.95))
                    .frame(width: 12, height: 12)
                Text(species.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Text("ID \(species.speciesID)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            keyValueRow(key: "Population", value: "\(species.count)")
            keyValueRow(key: "Average Energy", value: fmt2(species.averageEnergy))
            keyValueRow(key: "Hue", value: "\(species.hue)")
            keyValueRow(key: "Social Distance", value: fmt2(species.socialDistance))
            keyValueRow(key: "Alignment Weight", value: fmt2(species.alignmentWeight))
            keyValueRow(key: "Cohesion Weight", value: fmt2(species.cohesionWeight))
            keyValueRow(key: "Metabolism Rate", value: fmt2(species.metabolismRate))
            keyValueRow(key: "Max Speed", value: fmt0(species.maxSpeed))
        }
        .padding(12)
        .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func fmt2(_ value: Float) -> String {
        String(format: "%.2f", value)
    }

    private func fmt1(_ value: Float) -> String {
        String(format: "%.1f", value)
    }

    private func fmt1(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func fmt0(_ value: Float) -> String {
        String(format: "%.0f", value)
    }
}
