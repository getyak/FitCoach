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

    func testCoachCanContinuePreviousWorkoutAndConsumeOneCredit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore"]
        app.launch()

        let start = app.buttons["today.startWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["9 节"].exists)
        start.tap()

        XCTAssertTrue(app.descendants(matching: .any)["workout.previousPerformance"].waitForExistence(timeout: 5))
        let plannedSecondSet = app.buttons["workout.set.1.select"]
        XCTAssertTrue(plannedSecondSet.waitForExistence(timeout: 2))
        XCTAssertTrue(waitForValueContaining("计划", on: plannedSecondSet, timeout: 2))
        for exerciseIndex in 0..<3 {
            for setIndex in 0..<3 {
                let completeCurrent = app.buttons["workout.completeCurrentSet"]
                XCTAssertTrue(completeCurrent.waitForExistence(timeout: 2))
                completeCurrent.tap()
                let skipRest = app.buttons["workout.skipRest"]
                XCTAssertTrue(skipRest.waitForExistence(timeout: 2))
                if exerciseIndex == 0 && setIndex == 0 {
                    let nextSet = app.descendants(matching: .any)["workout.set.1.editor"]
                    XCTAssertTrue(nextSet.waitForExistence(timeout: 1))
                    XCTAssertTrue(nextSet.isHittable)
                    XCTAssertTrue(app.descendants(matching: .any)["workout.control.重量"].isHittable)
                    XCTAssertFalse(app.buttons["workout.completeCurrentSet"].exists)
                    XCTAssertFalse(app.buttons["workout.set.1.addNote"].exists)
                    XCTAssertTrue(waitForLabelContaining(
                        "第 1 组完成",
                        on: app.descendants(matching: .any)["workout.restTimer"],
                        timeout: 2
                    ))
                    let attachment = XCTAttachment(screenshot: app.screenshot())
                    attachment.name = "Progressive-current-set-and-rest"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                skipRest.tap()
            }
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
        let done = app.buttons["completion.done"]
        XCTAssertTrue(done.isHittable)
        assertHorizontallyContained(done, in: app)
        XCTAssertLessThanOrEqual(done.frame.width, app.windows.firstMatch.frame.width * 0.35)
        let completionTitle = app.staticTexts["本节训练完成"]
        XCTAssertTrue(completionTitle.exists)
        XCTAssertFalse(done.frame.intersects(completionTitle.frame))
        let completionAttachment = XCTAttachment(screenshot: app.screenshot())
        completionAttachment.name = "Workout-completion"
        completionAttachment.lifetime = .keepAlways
        add(completionAttachment)
        try auditAccessibility(in: app)

        let summary = app.descendants(matching: .any)["completion.summary"]
        XCTAssertTrue(summary.exists)
        XCTAssertTrue((summary.value as? String)?.contains("本次完成") == true)
        app.buttons["completion.summary.edit"].tap()
        XCTAssertTrue(app.textViews["completion.summary.editor"].waitForExistence(timeout: 2))
        app.buttons["completion.summary.edit"].tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 2))
        let trend = app.buttons["completion.trend"]
        XCTAssertTrue(trend.exists)
        for _ in 0..<3 where !trend.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(trend.isHittable)
        trend.tap()
        XCTAssertTrue(app.buttons["measurement.add"].waitForExistence(timeout: 3))
        app.buttons["完成"].tap()
        XCTAssertTrue(done.waitForExistence(timeout: 3))

        let reopen = app.buttons["completion.reopen"]
        XCTAssertTrue(reopen.exists)
        for _ in 0..<4 where !reopen.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(reopen.isHittable)
        reopen.tap()
        XCTAssertTrue(app.buttons["撤销并返还 1 节课"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["8 节"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        XCTAssertTrue(done.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["8 节"].exists)
    }

    func testWorkoutDraftAndRestTimerSurviveRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore"]
        app.launch()

        let start = app.buttons["today.startWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let firstSet = app.buttons["workout.completeCurrentSet"]
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
        let skipRest = app.buttons["workout.skipRest"]
        XCTAssertTrue(skipRest.isHittable)
        skipRest.tap()
        XCTAssertFalse(app.descendants(matching: .any)["workout.restTimer"].exists)
    }

    func testRestAutomaticallyFinishesAndRestoresNextSet() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore", "-seedShortRest"]
        app.launch()

        let resume = app.buttons["today.startWorkout"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()

        let restTimer = app.descendants(matching: .any)["workout.restTimer"]
        XCTAssertTrue(restTimer.waitForExistence(timeout: 4))
        XCTAssertTrue(waitForLabelContaining("第 1 组完成", on: restTimer, timeout: 2))
        XCTAssertFalse(app.buttons["workout.completeCurrentSet"].exists)
        XCTAssertTrue(restTimer.waitForNonExistence(timeout: 9))
        XCTAssertTrue(app.buttons["workout.completeCurrentSet"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["workout.set.1.editor"].isHittable)
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
        XCTAssertEqual(rpe.label, "记录 RPE")
        XCTAssertEqual(rpe.value as? String, "未记录")
        tapAdjustment(on: weight, increment: true)
        tapAdjustment(on: reps, increment: false)
        rpe.tap()
        let rpeField = app.textFields["workout.directInput.field"]
        XCTAssertTrue(rpeField.waitForExistence(timeout: 3))
        rpeField.typeText("7.5")
        app.buttons["workout.directInput.save"].tap()

        let addNote = app.buttons["workout.set.0.addNote"]
        XCTAssertTrue(addNote.isHittable)
        addNote.tap()
        let note = app.textFields["第 1 组备注"]
        XCTAssertTrue(note.waitForExistence(timeout: 2))
        note.tap()
        note.typeText("膝盖稳定")

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
        XCTAssertEqual(restoredRPE.value as? String, "7.5")
        XCTAssertEqual(app.textFields["第 1 组备注"].value as? String, "膝盖稳定")
    }

    func testLatestNumericEditSurvivesImmediateTermination() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore"]
        app.launch()

        let start = app.buttons["today.startWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let weight = app.descendants(matching: .any)["workout.control.重量"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        tapAdjustment(on: weight, increment: true)
        app.terminate()

        app.launchArguments = ["-uiTesting"]
        app.launch()
        let resume = app.buttons["today.startWorkout"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()

        let restoredWeight = app.descendants(matching: .any)["workout.control.重量"].firstMatch
        XCTAssertTrue(restoredWeight.waitForExistence(timeout: 5))
        XCTAssertEqual(restoredWeight.value as? String, "22.5 千克")
    }

    func testDirectNumericInputSavesImmediatelyAndSurvivesRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore"]
        app.launch()

        let start = app.buttons["today.startWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let weight = app.descendants(matching: .any)["workout.control.重量"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()

        let field = app.textFields["workout.directInput.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        let clear = app.buttons["workout.directInput.clear"]
        XCTAssertTrue(clear.isHittable)
        clear.tap()
        field.typeText("999999999999999999999999")
        XCTAssertTrue(app.staticTexts["workout.directInput.error"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["workout.directInput.save"].isEnabled)
        clear.tap()
        field.typeText("37.5")

        let editorAttachment = XCTAttachment(screenshot: app.screenshot())
        editorAttachment.name = "Direct-numeric-input"
        editorAttachment.lifetime = .keepAlways
        add(editorAttachment)

        let save = app.buttons["workout.directInput.save"]
        XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(waitForValue("37.5 千克", on: weight, timeout: 3))

        app.terminate()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        let resume = app.buttons["today.startWorkout"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()

        let restoredWeight = app.descendants(matching: .any)["workout.control.重量"].firstMatch
        XCTAssertTrue(restoredWeight.waitForExistence(timeout: 5))
        XCTAssertEqual(restoredWeight.value as? String, "37.5 千克")
    }

    func testWorkoutDeepLinkOpensExactSessionWarmAndCold() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore", "-seedDeepLink"]
        app.launch()

        let url = URL(string: "fitcoach://workout/A1165A79-2B26-446E-AB9B-73D1495DB85E")!
        XCTAssertTrue(app.buttons["today.startWorkout"].waitForExistence(timeout: 5))
        app.open(url)
        XCTAssertTrue(app.staticTexts["系统回课深蹲"].waitForExistence(timeout: 5))

        let pause = app.buttons["workout.pause"]
        XCTAssertTrue(pause.isHittable)
        pause.tap()
        XCTAssertTrue(app.buttons["today.startWorkout"].waitForExistence(timeout: 3))

        app.terminate()
        app.launchArguments = ["-uiTesting", "-seedDeepLink"]
        app.open(url)
        XCTAssertTrue(app.staticTexts["系统回课深蹲"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["workout.completeCurrentSet"].isHittable)
    }

    func testTodayAndWorkoutPassSystemAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore"]
        app.launch()

        XCTAssertTrue(app.buttons["today.startWorkout"].waitForExistence(timeout: 5))
        try auditAccessibility(in: app)

        app.buttons["today.startWorkout"].tap()
        XCTAssertTrue(app.buttons["workout.completeCurrentSet"].waitForExistence(timeout: 10))
        try auditAccessibility(in: app)

        let weight = app.descendants(matching: .any)["workout.control.重量"].firstMatch
        weight.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
        let directInput = app.textFields["workout.directInput.field"]
        let clearInput = app.buttons["workout.directInput.clear"]
        let cancelInput = app.buttons["workout.directInput.cancel"]
        let saveInput = app.buttons["workout.directInput.save"]
        XCTAssertTrue(directInput.waitForExistence(timeout: 3))
        XCTAssertTrue(directInput.isHittable)
        XCTAssertTrue(clearInput.isHittable)
        XCTAssertTrue(cancelInput.isHittable)
        XCTAssertTrue(saveInput.isHittable)
        // A partial sheet intentionally leaves dimmed workout copy visible behind
        // its modal barrier. The system OCR audit reports that inaccessible
        // background copy without an XCUIElement, so audit every actionable type
        // here and verify the sheet controls explicitly above.
        try auditAccessibility(in: app, excluding: .elementDetection)
        cancelInput.tap()

        let completeCurrentSet = app.buttons["workout.completeCurrentSet"]
        if completeCurrentSet.waitForExistence(timeout: 2) {
            completeCurrentSet.tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["workout.restTimer"].waitForExistence(timeout: 2))
        try auditAccessibility(in: app)
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
        let completeSet = app.descendants(matching: .any)["workout.set.0.editor"]
        XCTAssertTrue(completeSet.waitForExistence(timeout: 5))
        XCTAssertTrue(completeSet.isHittable)
        let weight = app.descendants(matching: .any)["workout.control.重量"]
        let reps = app.descendants(matching: .any)["workout.control.次数"]
        let rpe = app.descendants(matching: .any)["workout.control.RPE"]
        XCTAssertTrue(weight.isHittable)
        XCTAssertTrue(reps.isHittable)
        XCTAssertTrue(rpe.isHittable)
        XCTAssertEqual(rpe.label, "记录 RPE")
        XCTAssertEqual(rpe.value as? String, "未记录")
        assertHorizontallyContained(rpe, in: app)
        XCTAssertLessThan(weight.frame.midY, reps.frame.midY)
        XCTAssertLessThan(reps.frame.midY, rpe.frame.midY)
        XCTAssertTrue(app.buttons["workout.completeCurrentSet"].isHittable)
        let header = app.buttons["workout.pause"]
        let currentSetTitle = app.descendants(matching: .any)["workout.currentSetTitle"]
        XCTAssertTrue(header.exists)
        XCTAssertTrue(currentSetTitle.exists)
        XCTAssertGreaterThanOrEqual(currentSetTitle.frame.minY, header.frame.maxY + 1)
        assertHorizontallyContained(app.descendants(matching: .any)["workout.elapsedTime"].firstMatch, in: app)
        assertHorizontallyContained(app.descendants(matching: .any)["workout.previousPerformance"].firstMatch, in: app)
        assertHorizontallyContained(app.buttons["workout.completeCurrentSet"], in: app)

        app.buttons["workout.completeCurrentSet"].tap()
        let restTimer = app.descendants(matching: .any)["workout.restTimer"]
        let skipRest = app.buttons["workout.skipRest"]
        XCTAssertTrue(restTimer.waitForExistence(timeout: 2))
        XCTAssertTrue(skipRest.isHittable)
        XCTAssertTrue(waitForLabelContaining("第 1 组完成", on: restTimer, timeout: 2))
        XCTAssertFalse(app.buttons["workout.completeCurrentSet"].exists)
        let nextSetTitle = app.descendants(matching: .any)["workout.currentSetTitle"]
        XCTAssertGreaterThanOrEqual(nextSetTitle.frame.minY, header.frame.maxY + 1)
        assertHorizontallyContained(restTimer, in: app)
        assertHorizontallyContained(skipRest, in: app)
        XCTAssertLessThan(restTimer.frame.union(skipRest.frame).height, app.windows.firstMatch.frame.height * 0.25)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Today-and-workout-AX5"
        attachment.lifetime = .keepAlways
        add(attachment)
        skipRest.tap()
    }

    func testClientTrendTemplatesAndProfilePassSystemAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore"]
        app.launch()

        let clientsTab = app.tabBars.buttons["学员"]
        XCTAssertTrue(clientsTab.waitForExistence(timeout: 5))
        clientsTab.tap()
        XCTAssertTrue(app.navigationBars["学员"].waitForExistence(timeout: 3))
        try auditAccessibility(in: app)

        let client = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "林悦")).firstMatch
        XCTAssertTrue(client.waitForExistence(timeout: 3))
        client.tap()
        let trend = app.buttons["client.measurementTrend"]
        XCTAssertTrue(trend.waitForExistence(timeout: 3))
        try auditAccessibility(in: app, ignoringOffscreenBottomContrast: true)

        trend.tap()
        XCTAssertTrue(app.buttons["measurement.add"].waitForExistence(timeout: 3))
        try auditAccessibility(in: app)
        app.buttons["完成"].tap()

        app.swipeUp()
        app.swipeUp()
        let historyTitle = app.staticTexts["训练记录"]
        XCTAssertTrue(historyTitle.waitForExistence(timeout: 3))
        try auditAccessibility(in: app, ignoringContrastAboveY: historyTitle.frame.minY)

        let templatesTab = app.tabBars.buttons["模板"]
        XCTAssertTrue(templatesTab.waitForExistence(timeout: 3))
        templatesTab.tap()
        XCTAssertTrue(app.navigationBars["模板"].waitForExistence(timeout: 3))
        try auditAccessibility(in: app)

        let profileTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 3))
        profileTab.tap()
        XCTAssertTrue(app.navigationBars["我的"].waitForExistence(timeout: 3))
        try auditAccessibility(in: app)

        let backup = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "备份与恢复")).firstMatch
        XCTAssertTrue(backup.waitForExistence(timeout: 3))
        backup.tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 3))
        try auditAccessibility(in: app)
    }

    private func waitForLabel(_ label: String, on element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func auditAccessibility(
        in app: XCUIApplication,
        excluding excludedTypes: XCUIAccessibilityAuditType = [],
        ignoringOffscreenBottomContrast: Bool = false,
        ignoringContrastAboveY: CGFloat? = nil
    ) throws {
        try app.performAccessibilityAudit(for: .all.subtracting(excludedTypes)) { issue in
            if ignoringOffscreenBottomContrast,
               issue.auditType == .contrast,
               let element = issue.element,
               element.frame.minY >= app.windows.firstMatch.frame.maxY - 150 {
                print("AX_AUDIT_IGNORED_OFFSCREEN | \(element.frame) | \(element.label)")
                return true
            }
            if let ignoringContrastAboveY,
               issue.auditType == .contrast,
               let element = issue.element,
               element.frame.maxY <= ignoringContrastAboveY {
                print("AX_AUDIT_IGNORED_OFFSCREEN | \(element.frame) | \(element.label)")
                return true
            }
            print(
                "AX_AUDIT | \(issue.auditType.rawValue) | \(issue.compactDescription) | "
                + "\(issue.detailedDescription) | element=\(String(describing: issue.element))"
            )
            return false
        }
    }

    private func waitForLabelContaining(_ text: String, on element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", text),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForValue(_ value: String, on element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForValueContaining(_ text: String, on element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS %@", text),
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
