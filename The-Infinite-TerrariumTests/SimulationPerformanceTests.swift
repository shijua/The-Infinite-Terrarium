import XCTest
@testable import The_Infinite_Terrarium
import simd
import Dispatch

final class SimulationPerformanceTests: XCTestCase {
    func testSimulationStepPerformanceAtThousandBoids() {
        let engine = SimulationEngine(
            initialPopulation: 1_000,
            bounds: SpatialBounds(min: .zero, max: SIMD2<Float>(1_366, 1_024))
        )

        measure(metrics: [XCTClockMetric()]) {
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                _ = await engine.step(deltaTime: 1.0 / 60.0, commands: [])
                semaphore.signal()
            }

            let result = semaphore.wait(timeout: .now() + 2.0)
            XCTAssertEqual(result, .success, "Timed out while measuring simulation step.")
        }
    }
}
