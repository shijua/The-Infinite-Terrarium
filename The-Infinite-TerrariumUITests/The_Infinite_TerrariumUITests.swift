import XCTest

@MainActor
final class The_Infinite_TerrariumUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFeedMutateAnalyzeControls() throws {
        let app = XCUIApplication()
        app.launch()

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

        let feedButton = app.buttons["toolbar.feed"]
        XCTAssertTrue(feedButton.exists)
        feedButton.tap()

        let mutateButton = app.buttons["toolbar.mutate"]
        XCTAssertTrue(mutateButton.exists)
        mutateButton.tap()
    }

    func testControlsRemainReachableAfterRotation() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["toolbar.feed"].waitForExistence(timeout: 5))

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["toolbar.feed"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["toolbar.mutate"].exists)
        XCTAssertTrue(app.buttons["toolbar.analyze"].exists)

        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(app.buttons["toolbar.feed"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["toolbar.mutate"].exists)
        XCTAssertTrue(app.buttons["toolbar.analyze"].exists)
    }
}
