import SwiftUI
import Combine
import simd
import UIKit
import os

/// Main UI coordinator that bridges user actions, simulation ticks, and AI output.
@MainActor
final class RootViewModel: ObservableObject {
    @Published private(set) var boids: [Boid] = []
    @Published private(set) var snapshot: EcosystemSnapshot = .empty
    @Published private(set) var worldBounds: SpatialBounds = SpatialBounds(min: .zero, max: SIMD2<Float>(1_366, 1_024))

    @Published var renderParameters: RenderParameters = .preset(for: .high)
    @Published var analyzeQuestion: String = "Why are red organisms disappearing?"
    @Published var analyzeResponse: String = "Tap Analyze to receive a scientific interpretation of the current biome."
    @Published var isAnalyzePresented = false
    @Published var isGuidePresented = false
    @Published var isAnalyzing = false
    @Published private(set) var actionHint: String = "Feed adds local energy. Mutate retunes dominant species DNA."
    @Published private(set) var feedPulse: FeedPulse?

    @Published private(set) var fps: Double = 0
    @Published private(set) var simulationMS: Double = 0
    @Published private(set) var renderMS: Double = 0

    private let simulation: SimulationEngine
    private let aiProvider: any AIProvider
    private var frameStepper = FrameStepper()
    private var pendingCommands: [SimulationCommand] = []
    private var isTicking = false
    private let monitor = PerformanceMonitor()
    private var deterministicSeed: UInt64 = 0xA17E_600D

    init(simulation: SimulationEngine = SimulationEngine(), aiProvider: any AIProvider = AIProviderFactory.makeDefault()) {
        self.simulation = simulation
        self.aiProvider = aiProvider
        snapshot = simulation.snapshot()
    }

    func enqueueFeed() {
        var rng = DeterministicRNG(seed: deterministicSeed)
        deterministicSeed = rng.nextUInt64()

        let point: SIMD2<Float>
        if boids.isEmpty {
            point = SIMD2<Float>(
                rng.nextFloat(in: worldBounds.min.x...worldBounds.max.x),
                rng.nextFloat(in: worldBounds.min.y...worldBounds.max.y)
            )
        } else {
            let centroid = boids.reduce(SIMD2<Float>(repeating: 0)) { partial, boid in
                partial + boid.position
            } / Float(boids.count)
            let jitter = SIMD2<Float>(
                rng.nextFloat(in: -95...95),
                rng.nextFloat(in: -95...95)
            )
            point = worldBounds.clamp(centroid + jitter)
        }

        let feedRadius: Float = 210
        let feedRadiusSq = feedRadius * feedRadius
        let affectedCount = boids.reduce(0) { partialResult, boid in
            let distanceSq = simd_length_squared(boid.position - point)
            return partialResult + (distanceSq <= feedRadiusSq ? 1 : 0)
        }

        pendingCommands.append(.feed(point: point, amount: 0.30))
        feedPulse = FeedPulse(worldPoint: point, issuedAtReferenceTime: Date().timeIntervalSinceReferenceDate)
        actionHint = affectedCount > 0
            ? "Feed boosted \(affectedCount) nearby organisms with an energy pulse."
            : "Feed pulse queued near colony center; effect appears when organisms pass through it."
    }

    func enqueueMutation() {
        if let dominant = snapshot.speciesStats.first {
            pendingCommands.append(.mutate(targetSpeciesID: dominant.speciesID))
            actionHint = "Mutate shifted DNA of \(dominant.name): spacing, speed, and metabolism for \(dominant.count) organisms."
        } else {
            pendingCommands.append(.mutate(targetSpeciesID: nil))
            actionHint = "Mutate queued. Waiting for stable species clusters."
        }
    }

    func toggleAnalyze() {
        isAnalyzePresented.toggle()

        if isAnalyzePresented {
            Task {
                await analyzeCurrentEcosystem()
            }
        }
    }

    func injectSpeciesFromAI(stage: AIStage) async {
        do {
            let dna = try await aiProvider.generateDNA(context: snapshot)
            pendingCommands.append(.injectSpecies(dna: dna, count: 48))
            analyzeResponse = "Injected \(dna.speciesName). Observe how social distance and metabolism alter the biome."
            actionHint = "Injected \(dna.speciesName)."

        } catch {
            analyzeResponse = "AI injection failed. Fallback genes were unavailable in this session."
            actionHint = "Injection failed. Fallback DNA unavailable."
        }
    }

    func analyzeCurrentEcosystem() async {
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let text = try await aiProvider.explain(question: analyzeQuestion, context: snapshot)
            analyzeResponse = text
            actionHint = "Analysis updated."
        } catch {
            analyzeResponse = "Analysis unavailable. The fallback narrator could not complete this request."
            actionHint = "Analysis failed. Fallback narrator unavailable."
        }
    }

    func tick(at date: Date) async {
        guard !isTicking else {
            return
        }

        isTicking = true
        defer { isTicking = false }

        let dt = frameStepper.step(at: date)

        // Commands are consumed exactly once at frame boundary.
        let commands = pendingCommands
        pendingCommands.removeAll(keepingCapacity: true)

        let frame = await simulation.step(deltaTime: dt, commands: commands)
        boids = frame.boids
        snapshot = frame.snapshot
        worldBounds = frame.worldBounds

        if let feedPulse, date.timeIntervalSinceReferenceDate - feedPulse.issuedAtReferenceTime > 1.2 {
            self.feedPulse = nil
        }

        let frameDurationMS = Double(dt * 1000)
        monitor.recordFrame(
            simulationMS: frame.simulationMS,
            estimatedRenderMS: renderParameters.estimatedRenderMS,
            frameDurationMS: frameDurationMS
        )

        fps = monitor.fps
        simulationMS = monitor.simulationMS
        renderMS = monitor.estimatedRenderMS

        let quality = monitor.recommendedQuality(current: renderParameters.quality)
        if quality != renderParameters.quality {
            renderParameters = .preset(for: quality)
            actionHint = "Adaptive quality switched to \(quality.rawValue.uppercased())."
        }

        // Lowest quality tier enforces a lower boid ceiling to keep frame budget.
        if quality == .low {
            simulation.trimPopulationIfNeeded(maxCount: 800)
        }
    }
}

/// Root composition:
/// 1) Timeline-driven simulation canvas
/// 2) Top HUD metrics
/// 3) Bottom glass controls + optional analysis panel
struct RootView: View {
    @StateObject private var viewModel = RootViewModel()
    @State private var didAppear = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Timeline drives both render animation and simulation stepping.
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
                TerrariumCanvasView(
                    boids: viewModel.boids,
                    snapshot: viewModel.snapshot,
                    worldBounds: viewModel.worldBounds,
                    renderParameters: viewModel.renderParameters,
                    timelineDate: timeline.date,
                    feedPulse: viewModel.feedPulse
                )
                .opacity(didAppear ? 1 : 0)
                .scaleEffect(didAppear ? 1 : 1.04)
                .task(id: timeline.date) {
                    await viewModel.tick(at: timeline.date)
                }
            }

            VStack(spacing: isCompact ? 8 : 12) {
                StatsOverlayView(
                    snapshot: viewModel.snapshot,
                    fps: viewModel.fps,
                    simulationMS: viewModel.simulationMS,
                    renderMS: viewModel.renderMS,
                    isCompact: isCompact
                )

                Spacer()

                if viewModel.isAnalyzePresented {
                    AnalyzePanelView(
                        question: $viewModel.analyzeQuestion,
                        response: viewModel.analyzeResponse,
                        isLoading: viewModel.isAnalyzing,
                        isCompact: isCompact,
                        onAsk: {
                            Task {
                                await viewModel.analyzeCurrentEcosystem()
                            }
                        },
                        onInjectSpecies: {
                            Task {
                                await viewModel.injectSpeciesFromAI(stage: .analysis)
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if !viewModel.actionHint.isEmpty {
                    Text(viewModel.actionHint)
                        .font(.system(size: isCompact ? 12 : 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.96))
                        .padding(.horizontal, isCompact ? 12 : 14)
                        .padding(.vertical, isCompact ? 8 : 10)
                        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: isCompact ? 10 : 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: isCompact ? 10 : 12, style: .continuous)
                                .stroke(Color.white.opacity(0.20), lineWidth: 1)
                        )
                }

                GlassToolbarView(
                    quality: viewModel.renderParameters.quality,
                    isCompact: isCompact,
                    onFeed: {
                        viewModel.enqueueFeed()
                    },
                    onMutate: {
                        viewModel.enqueueMutation()
                    },
                    onAnalyze: {
                        viewModel.toggleAnalyze()
                    },
                    onGuide: {
                        viewModel.isGuidePresented = true
                    }
                )
            }
            .padding(.horizontal, isCompact ? 12 : 18)
            .padding(.top, isCompact ? 8 : 12)
            .padding(.bottom, isCompact ? 10 : 20)
            .animation(.spring(duration: 0.32, bounce: 0.16), value: viewModel.isAnalyzePresented)
        }
        .onAppear {
            requestLandscapeOrientationIfNeeded()
            withAnimation(.easeOut(duration: 1.2)) {
                didAppear = true
            }
        }
        .sheet(isPresented: $viewModel.isGuidePresented) {
            TerrariumGuideView(
                snapshot: viewModel.snapshot,
                renderParameters: viewModel.renderParameters
            )
        }
    }

    private func requestLandscapeOrientationIfNeeded() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { error in
            AppLogger.rendering.error("Failed to request landscape orientation: \(error.localizedDescription)")
        }
    }
}

#Preview {
    RootView()
}
