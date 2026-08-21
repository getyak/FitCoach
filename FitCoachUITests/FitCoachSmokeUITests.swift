import XCTest

final class FitCoachSmokeUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    func testWarmLaunchPerformance() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        let options = XCTMeasureOptions()
        options.iterationCount = 3

        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            app.launch()
            app.terminate()
        }
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
        for exerciseIndex in 0..<3 {
            for setIndex in 0..<3 {
                let completeCurrent = app.buttons["workout.completeCurrentSet"]
                XCTAssertTrue(completeCurrent.waitForExistence(timeout: 2))
                completeCurrent.tap()
                if exerciseIndex == 0 && setIndex == 0 {
                    let nextSet = app.buttons["workout.set.1.complete"]
                    XCTAssertTrue(nextSet.waitForExistence(timeout: 1))
                    XCTAssertTrue(nextSet.isHittable)
                    XCTAssertTrue(app.descendants(matching: .any)["workout.control.重量"].isHittable)
                    let attachment = XCTAttachment(screenshot: app.screenshot())
                    attachment.name = "Progressive-current-set-and-rest"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
            XCTAssertTrue(app.descendants(matching: .any)["workout.restTimer"].waitForExistence(timeout: 2))
            if exerciseIndex < 2 {
                let next = app.buttons["workout.nextExercise"]
                XCTAssertTrue(next.waitForExistence(timeout: 2))
                next.tap()
            }
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
        XCTAssertTrue(waitForLabelContaining("撤销第 1 组完成", on: restoredSet, timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["workout.restTimer"].exists)
    }

    func testAllSetFieldsSurviveForcedRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore"]
        app.launch()

        let start = app.buttons["today.startWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let weight = app.descendants(matching: .any)["workout.control.重量"].firstMatch
        let reps = app.descendants(matching: .any)["workout.control.次数"].firstMatch
        let rpe = app.descendants(matching: .any)["workout.control.RPE"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        XCTAssertEqual(rpe.value as? String, "未记录")
        tapAdjustment(on: weight, increment: true)
        tapAdjustment(on: reps, increment: false)
        tapAdjustment(on: rpe, increment: true)

        let note = app.textFields["第 1 组备注"]
        XCTAssertTrue(note.exists)
        note.tap()
        note.typeText("膝盖稳定")
        Thread.sleep(forTimeInterval: 1)

        app.terminate()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        let resume = app.buttons["today.startWorkout"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()

        let restoredWeight = app.descendants(matching: .any)["workout.control.重量"].firstMatch
        let restoredReps = app.descendants(matching: .any)["workout.control.次数"].firstMatch
        let restoredRPE = app.descendants(matching: .any)["workout.control.RPE"].firstMatch
        XCTAssertTrue(restoredWeight.waitForExistence(timeout: 5))
        XCTAssertEqual(restoredWeight.value as? String, "22.5 千克")
        XCTAssertEqual(restoredReps.value as? String, "9 次")
        XCTAssertEqual(restoredRPE.value as? String, "7")
        XCTAssertEqual(app.textFields["第 1 组备注"].value as? String, "膝盖稳定")
    }

    func testTodayPrimaryActionRemainsReachableAtAccessibilityTextSize() {
        let app = XCUIApplication()
        // Use an app-owned SwiftUI override. The old UIKit launch default silently
        // falls back to normal text on iOS 26 and previously gave this test a false green.
        app.launchArguments = ["-uiTesting", "-resetStore", "-uiTestAX5"]
        app.launch()

        let start = app.buttons["today.startWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists)
        XCTAssertLessThanOrEqual(start.frame.maxY, tabBar.frame.minY + 1)

        let name = app.descendants(matching: .any)["today.focusName"]
        let credits = app.descendants(matching: .any)["today.remainingCredits"]
        XCTAssertTrue(name.exists)
        XCTAssertTrue(credits.exists)
        XCTAssertFalse(name.frame.intersects(credits.frame))

        start.tap()
        let completeSet = app.buttons["workout.set.0.complete"]
        XCTAssertTrue(completeSet.waitForExistence(timeout: 5))
        XCTAssertTrue(completeSet.isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["workout.control.重量"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["workout.control.次数"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["workout.control.RPE"].exists)
        XCTAssertTrue(app.buttons["workout.completeCurrentSet"].isHittable)
        assertHorizontallyContained(app.descendants(matching: .any)["workout.elapsedTime"].firstMatch, in: app)
        assertHorizontallyContained(app.descendants(matching: .any)["workout.previousPerformance"].firstMatch, in: app)
        assertHorizontallyContained(app.buttons["workout.completeCurrentSet"], in: app)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Today-and-workout-AX5"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForLabel(_ label: String, on element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForLabelContaining(_ text: String, on element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", text),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func tapAdjustment(on element: XCUIElement, increment: Bool) {
        XCTAssertTrue(element.exists)
        let x: CGFloat = increment ? 0.86 : 0.14
        element.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.72)).tap()
    }

    private func assertHorizontallyContained(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(element.exists, file: file, line: line)
        let frame = element.frame
        let glyphOverhangTolerance: CGFloat = 4
        XCTAssertGreaterThanOrEqual(frame.minX, window.minX - glyphOverhangTolerance, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, window.maxX + glyphOverhangTolerance, file: file, line: line)
    }
}
