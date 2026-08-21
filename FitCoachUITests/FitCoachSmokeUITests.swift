import XCTest

final class FitCoachSmokeUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    func testCoachCanContinuePreviousWorkoutAndConsumeOneCredit() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore"]
        app.launch()

        let start = app.buttons["today.startWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["9 节"].exists)
        start.tap()

        XCTAssertTrue(app.descendants(matching: .any)["workout.previousPerformance"].waitForExistence(timeout: 5))
        let firstSet = app.buttons["workout.set.0.complete"]
        XCTAssertTrue(firstSet.exists)
        firstSet.tap()
        XCTAssertTrue(app.descendants(matching: .any)["workout.restTimer"].waitForExistence(timeout: 2))

        for _ in 0..<2 {
            let next = app.buttons["workout.nextExercise"]
            XCTAssertTrue(next.waitForExistence(timeout: 2))
            next.tap()
        }

        let finish = app.buttons["workout.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 2))
        finish.tap()

        let confirm = app.buttons.matching(NSPredicate(format: "label CONTAINS '完成并扣课'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 2))
        confirm.tap()

        XCTAssertTrue(app.descendants(matching: .any)["completion.remainingCredits"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["8 节"].exists)
        XCTAssertTrue(app.buttons["completion.done"].exists)
    }

    func testWorkoutDraftAndRestTimerSurviveRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore"]
        app.launch()

        let start = app.buttons["today.startWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let firstSet = app.buttons["workout.set.0.complete"]
        XCTAssertTrue(firstSet.waitForExistence(timeout: 5))
        firstSet.tap()
        XCTAssertTrue(app.descendants(matching: .any)["workout.restTimer"].waitForExistence(timeout: 2))

        app.terminate()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        let continueButton = app.buttons["today.startWorkout"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        XCTAssertEqual(continueButton.label, "继续本节训练")
        continueButton.tap()

        let restoredSet = app.buttons["workout.set.0.complete"]
        XCTAssertTrue(restoredSet.waitForExistence(timeout: 5))
        XCTAssertEqual(restoredSet.label, "已完成")
        XCTAssertTrue(app.descendants(matching: .any)["workout.restTimer"].exists)
    }

    func testTodayPrimaryActionRemainsReachableAtAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-resetStore",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ]
        app.launch()

        let start = app.buttons["today.startWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
    }
}
