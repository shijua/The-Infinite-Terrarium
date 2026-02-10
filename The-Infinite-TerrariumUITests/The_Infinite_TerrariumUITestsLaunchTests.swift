import XCTest

@MainActor
final class The_Infinite_TerrariumUITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["toolbar.feed"].waitForExistence(timeout: 5))
    }
}
