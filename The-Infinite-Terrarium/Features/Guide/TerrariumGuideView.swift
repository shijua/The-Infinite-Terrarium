import SwiftUI

/// In-app quick guide for controls, quality levels, and species traits.
public struct TerrariumGuideView: View {
    public let snapshot: EcosystemSnapshot
    public let renderParameters: RenderParameters
    @AppStorage("hud.showPerformanceOverlay") private var isStatsOverlayVisible = true
    @Environment(\.dismiss) private var dismiss

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

                    sectionCard(title: "Interaction Controls") {
                        guideRow(title: "Feed", subtitle: "Tap directly on the simulation surface to add a local energy pulse at that location. There is no Feed toolbar button.")
                        guideRow(title: "Mutate", subtitle: "Retunes dominant species DNA: social distance, alignment, cohesion, metabolism, and max speed.")
                        guideRow(title: "Analyze", subtitle: "Asks the AI narrator to explain current ecosystem state using latest snapshot.")
                        guideRow(title: "Guide", subtitle: "Opening this panel pauses simulation updates. Close Guide to resume the ecosystem.")
                    }

                    sectionCard(title: "Adaptive Quality") {
                        keyValueRow(key: "Current Quality", value: renderParameters.quality.rawValue.uppercased())
                        keyValueRow(key: "Refraction Strength", value: String(format: "%.1f", renderParameters.refractionStrength))
                        keyValueRow(key: "Chromatic Offset", value: String(format: "%.1f", renderParameters.chromaticOffset))
                        keyValueRow(key: "Color Pulse", value: String(format: "%.2f", renderParameters.colorPulse))
                        keyValueRow(key: "Organism Radius", value: String(format: "%.1f", renderParameters.organismRadius))
                        keyValueRow(key: "Particle Alpha", value: String(format: "%.2f", renderParameters.backgroundParticleAlpha))
                        keyValueRow(key: "Max Sample Offset", value: String(format: "%.1f", renderParameters.maxSampleOffset))
                        keyValueRow(key: "Estimated Render Cost", value: String(format: "%.1f ms", renderParameters.estimatedRenderMS))
                        Text("Meaning: higher values improve visual richness but increase GPU cost; adaptive quality automatically switches between HIGH / MEDIUM / LOW to keep frame budget stable. Current quality is shown in the top-left performance overlay.")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
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
            keyValueRow(key: "Average Energy", value: String(format: "%.2f", species.averageEnergy))
            keyValueRow(key: "Hue", value: "\(species.hue)")
            keyValueRow(key: "Social Distance", value: String(format: "%.2f", species.socialDistance))
            keyValueRow(key: "Alignment Weight", value: String(format: "%.2f", species.alignmentWeight))
            keyValueRow(key: "Cohesion Weight", value: String(format: "%.2f", species.cohesionWeight))
            keyValueRow(key: "Metabolism Rate", value: String(format: "%.2f", species.metabolismRate))
            keyValueRow(key: "Max Speed", value: String(format: "%.0f", species.maxSpeed))
        }
        .padding(12)
        .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
