import XCTest

@MainActor
final class The_Infinite_TerrariumUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFeedMutateAnalyzeControls() throws {
        let app = XCUIApplication()
        app.launch()

        // Feed is injected by tapping the simulation surface.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let analyzeButton = app.buttons["toolbar.analyze"]
        XCTAssertTrue(analyzeButton.waitForExistence(timeout: 5))
        analyzeButton.tap()

        let questionField = app.textFields["analyze.question"]
        XCTAssertTrue(questionField.waitForExistence(timeout: 3))
        questionField.tap()
        questionField.typeText("Why is the dominant species stable?")

        let runButton = app.buttons["analyze.run"]
        XCTAssertTrue(runButton.exists)
        runButton.tap()

        let mutateButton = app.buttons["toolbar.mutate"]
        XCTAssertTrue(mutateButton.exists)
        mutateButton.tap()

        let guideButton = app.buttons["toolbar.guide"]
        XCTAssertTrue(guideButton.exists)
        guideButton.tap()

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3))
        doneButton.tap()
    }

    func testControlsRemainReachableAfterRotation() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["toolbar.mutate"].waitForExistence(timeout: 5))

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["toolbar.mutate"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["toolbar.mutate"].exists)
        XCTAssertTrue(app.buttons["toolbar.analyze"].exists)

        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(app.buttons["toolbar.mutate"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["toolbar.mutate"].exists)
        XCTAssertTrue(app.buttons["toolbar.analyze"].exists)
    }
}
