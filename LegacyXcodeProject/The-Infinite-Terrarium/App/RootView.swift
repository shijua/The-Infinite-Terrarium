import SwiftUI
import Combine
import simd
import UIKit
import os

/// Timeout error for AI requests.
struct TimeoutError: Error {}

/// Execute an async operation with a timeout.
func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError()
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

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
    /// Shared lock: true while any AI request (analyze or inject) is in flight.
    @Published private(set) var isAIBusy = false
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

    func enqueueFeed(at worldPoint: SIMD2<Float>? = nil) {
        var rng = DeterministicRNG(seed: deterministicSeed)
        deterministicSeed = rng.nextUInt64()

        let isTapFeed = worldPoint != nil
        let point = worldPoint.map(worldBounds.clamp) ?? {
            if boids.isEmpty {
                return SIMD2<Float>(
                    rng.nextFloat(in: worldBounds.min.x...worldBounds.max.x),
                    rng.nextFloat(in: worldBounds.min.y...worldBounds.max.y)
                )
            }

            let centroid = boids.reduce(SIMD2<Float>(repeating: 0)) { partial, boid in
                partial + boid.position
            } / Float(boids.count)
            let jitter = SIMD2<Float>(
                rng.nextFloat(in: -95...95),
                rng.nextFloat(in: -95...95)
            )
            return worldBounds.clamp(centroid + jitter)
        }()

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
            : (isTapFeed
                ? "Feed pulse queued at tapped location; effect appears when organisms pass through it."
                : "Feed pulse queued near colony center; effect appears when organisms pass through it.")
    }

    func enqueueFeed() {
        enqueueFeed(at: nil)
    }

    func worldPointFromCanvasTap(location: CGPoint, canvasSize: CGSize) -> SIMD2<Float>? {
        guard canvasSize.width > 1, canvasSize.height > 1 else {
            return nil
        }

        let nx = Float(max(0.0, min(1.0, location.x / canvasSize.width)))
        let ny = Float(max(0.0, min(1.0, location.y / canvasSize.height)))
        let worldSize = worldBounds.size
        let world = SIMD2<Float>(
            worldBounds.min.x + nx * worldSize.x,
            worldBounds.min.y + ny * worldSize.y
        )
        return worldBounds.clamp(world)
    }

    func enqueueFeedFromCanvasTap(location: CGPoint, canvasSize: CGSize) {
        guard let worldPoint = worldPointFromCanvasTap(location: location, canvasSize: canvasSize) else {
            enqueueFeed()
            return
        }
        enqueueFeed(at: worldPoint)
    }

    func enqueueMutation() {
        if let dominant = snapshot.speciesStats.first {
            pendingCommands.append(.mutate(targetHue: dominant.hue))
            actionHint = "Mutate shifted DNA of \(dominant.name): spacing, speed, and metabolism for \(dominant.count) organisms."
        } else {
            pendingCommands.append(.mutate(targetHue: nil))
            actionHint = "Mutate queued. Waiting for stable species clusters."
        }
    }

    func toggleAnalyze() {
        isAnalyzePresented.toggle()
    }

    func injectSpeciesFromAI(stage: AIStage) async {
        guard !isAIBusy else {
            actionHint = "AI is already working — please wait."
            return
        }
        isAIBusy = true
        defer { isAIBusy = false }

        do {
            let plan = makeInjectPlan()
            let dnas = try await generateAICluster(stage: stage, speciesCount: plan.speciesCount, timeoutSeconds: plan.timeoutSeconds)
            let counts = distributePopulation(total: plan.population, buckets: dnas.count)

            for (dna, count) in zip(dnas, counts) {
                pendingCommands.append(.injectSpecies(dna: dna, count: count))
            }

            analyzeResponse = "AI inject complete: +\(plan.population) organisms across \(dnas.count) species."
            actionHint = "AI injection complete: +\(plan.population) organisms / \(dnas.count) species."
        } catch is TimeoutError {
            analyzeResponse = AIProviderError.timeout.localizedDescription
            actionHint = "AI injection timed out. No species injected."
        } catch {
            analyzeResponse = error.localizedDescription
            actionHint = "AI injection failed: \(error.localizedDescription)"
        }
    }

    private func makeInjectPlan() -> (population: Int, speciesCount: Int, timeoutSeconds: TimeInterval) {
        var rng = DeterministicRNG(seed: deterministicSeed ^ UInt64(max(1, snapshot.totalBoids)))
        let population = rng.nextInt(in: PromptBuilder.injectPopulationRange)
        let speciesCount = rng.nextInt(in: PromptBuilder.injectSpeciesCountRange)
        let timeoutSeconds = TimeInterval(rng.nextInt(in: PromptBuilder.injectDNATimeoutSecondsRange))
        deterministicSeed = rng.nextUInt64()
        return (population, speciesCount, timeoutSeconds)
    }

    private func generateAICluster(
        stage: AIStage,
        speciesCount: Int,
        timeoutSeconds: TimeInterval
    ) async throws -> [SpeciesDNA] {
        let target = max(1, speciesCount)
        return try await withTimeout(seconds: timeoutSeconds) {
            try await self.aiProvider.generateDNACluster(
                context: self.snapshot,
                stage: stage,
                count: target
            )
        }
    }

    private func distributePopulation(total: Int, buckets: Int) -> [Int] {
        let safeBuckets = max(1, buckets)
        let safeTotal = max(safeBuckets, total)

        var rng = DeterministicRNG(seed: deterministicSeed ^ UInt64(safeTotal) ^ UInt64(safeBuckets))
        var weights: [Float] = []
        weights.reserveCapacity(safeBuckets)
        var weightSum: Float = 0

        for _ in 0..<safeBuckets {
            let weight = rng.nextFloat(in: 0.6...1.4)
            weights.append(weight)
            weightSum += weight
        }

        var counts = Array(repeating: 1, count: safeBuckets)
        var remaining = safeTotal - safeBuckets

        for index in 0..<safeBuckets {
            if remaining <= 0 {
                break
            }

            let slotsLeft = safeBuckets - index
            if slotsLeft == 1 {
                counts[index] += remaining
                remaining = 0
                break
            }

            let share = Int((Float(remaining) * (weights[index] / max(weightSum, 0.0001))).rounded())
            let maxAlloc = remaining - (slotsLeft - 1)
            let allocated = max(0, min(maxAlloc, share))
            counts[index] += allocated
            remaining -= allocated
        }

        deterministicSeed = rng.nextUInt64()
        return counts
    }

    func analyzeCurrentEcosystem() async {
        guard !isAIBusy else {
            actionHint = "AI is already working — please wait."
            return
        }
        isAIBusy = true
        isAnalyzing = true
        defer {
            isAnalyzing = false
            isAIBusy = false
        }

        do {
            let text = try await withTimeout(seconds: 15) {
                try await self.aiProvider.explain(question: self.analyzeQuestion, context: self.snapshot)
            }
            analyzeResponse = text
            actionHint = "Analysis updated."
        } catch is TimeoutError {
            analyzeResponse = AIProviderError.timeout.localizedDescription
            actionHint = "Analysis timed out."
        } catch {
            analyzeResponse = error.localizedDescription
            actionHint = "Analysis failed: \(error.localizedDescription)"
        }
    }

    func tick(at date: Date) async {
        guard !isTicking else {
            return
        }

        isTicking = true
        defer { isTicking = false }

        let dt = frameStepper.step(at: date)

        if isAIBusy || isGuidePresented {
            if let feedPulse, date.timeIntervalSinceReferenceDate - feedPulse.issuedAtReferenceTime > 1.2 {
                self.feedPulse = nil
            }
            return
        }

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
    @AppStorage("hud.showPerformanceOverlay") private var isStatsOverlayVisible = true
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Timeline drives both render animation and simulation stepping.
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
                GeometryReader { geometry in
                    TerrariumCanvasView(
                        boids: viewModel.boids,
                        snapshot: viewModel.snapshot,
                        worldBounds: viewModel.worldBounds,
                        renderParameters: viewModel.renderParameters,
                        timelineDate: timeline.date,
                        feedPulse: viewModel.feedPulse
                    )
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                viewModel.enqueueFeedFromCanvasTap(
                                    location: value.location,
                                    canvasSize: geometry.size
                                )
                            }
                    )
                    .opacity(didAppear ? 1 : 0)
                    .scaleEffect(didAppear ? 1 : 1.04)
                    .task(id: timeline.date) {
                        await viewModel.tick(at: timeline.date)
                    }
                }
            }

            VStack(spacing: isCompact ? 8 : 12) {
                if isStatsOverlayVisible {
                    StatsOverlayView(
                        snapshot: viewModel.snapshot,
                        fps: viewModel.fps,
                        simulationMS: viewModel.simulationMS,
                        renderMS: viewModel.renderMS,
                        quality: viewModel.renderParameters.quality,
                        isCompact: isCompact
                    )
                }

                Spacer()

                if viewModel.isAnalyzePresented {
                    AnalyzePanelView(
                        question: $viewModel.analyzeQuestion,
                        response: viewModel.analyzeResponse,
                        isLoading: viewModel.isAIBusy,
                        isAIBusy: viewModel.isAIBusy,
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
                    isCompact: isCompact,
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
            configureWindowSceneIfNeeded()
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

    private func configureWindowSceneIfNeeded() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        #if targetEnvironment(macCatalyst)
        if let titlebar = windowScene.titlebar {
            titlebar.titleVisibility = .hidden
            titlebar.toolbar = nil
        }
        #else
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { error in
            AppLogger.rendering.error("Failed to request landscape orientation: \(error.localizedDescription)")
        }
        #endif
    }
}

#Preview {
    RootView()
}
