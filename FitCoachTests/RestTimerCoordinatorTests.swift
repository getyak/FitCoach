import XCTest
@testable import FitCoach

@MainActor
final class RestTimerCoordinatorTests: XCTestCase {
    func testStopPreventsPausedStartFromSchedulingAStaleNotification() async {
        let sessionID = UUID()
        var activityContinuation: CheckedContinuation<Void, Never>?
        var scheduledOperationIDs: [UUID] = []

        let coordinator = RestTimerCoordinator(
            upsertActivity: { _, _ in
                await withCheckedContinuation { continuation in
                    activityContinuation = continuation
                }
            },
            endActivity: { _ in },
            scheduleNotification: { _, _, _, operationID in
                scheduledOperationIDs.append(operationID)
                return true
            },
            cancelNotification: { _, _ in },
            cancelSessionNotifications: { _ in }
        )

        let startTask = Task { @MainActor in
            await coordinator.start(
                sessionID: sessionID,
                exerciseName: "深蹲",
                endDate: Date().addingTimeInterval(60)
            )
        }
        while activityContinuation == nil { await Task.yield() }

        await coordinator.stop(sessionID: sessionID)
        activityContinuation?.resume()
        _ = await startTask.value

        XCTAssertTrue(scheduledOperationIDs.isEmpty)
    }

    func testStopCancelsAStaleNotificationThatFinishesSchedulingLate() async {
        let sessionID = UUID()
        var scheduleContinuation: CheckedContinuation<Bool, Never>?
        var scheduledOperationID: UUID?
        var cancelledOperationIDs: [UUID] = []

        let coordinator = RestTimerCoordinator(
            upsertActivity: { _, _ in },
            endActivity: { _ in },
            scheduleNotification: { _, _, _, operationID in
                scheduledOperationID = operationID
                return await withCheckedContinuation { continuation in
                    scheduleContinuation = continuation
                }
            },
            cancelNotification: { _, operationID in
                cancelledOperationIDs.append(operationID)
            },
            cancelSessionNotifications: { _ in }
        )

        let startTask = Task { @MainActor in
            await coordinator.start(
                sessionID: sessionID,
                exerciseName: "硬拉",
                endDate: Date().addingTimeInterval(60)
            )
        }
        while scheduleContinuation == nil { await Task.yield() }

        await coordinator.stop(sessionID: sessionID)
        scheduleContinuation?.resume(returning: true)
        _ = await startTask.value

        XCTAssertEqual(cancelledOperationIDs, [scheduledOperationID].compactMap { $0 })
    }

    func testNewStartWinsWhenAnEarlierStopFinishesLate() async {
        let sessionID = UUID()
        var firstCancelContinuation: CheckedContinuation<Void, Never>?
        var cancelCallCount = 0
        var endedSessionIDs: [UUID] = []
        var scheduledSessionIDs: [UUID] = []

        let coordinator = RestTimerCoordinator(
            upsertActivity: { _, _ in },
            endActivity: { sessionID in endedSessionIDs.append(sessionID) },
            scheduleNotification: { sessionID, _, _, _ in
                scheduledSessionIDs.append(sessionID)
                return true
            },
            cancelNotification: { _, _ in },
            cancelSessionNotifications: { _ in
                cancelCallCount += 1
                if cancelCallCount == 1 {
                    await withCheckedContinuation { continuation in
                        firstCancelContinuation = continuation
                    }
                }
            }
        )

        let stopTask = Task { @MainActor in
            await coordinator.stop(sessionID: sessionID)
        }
        while firstCancelContinuation == nil { await Task.yield() }

        let startResult = await coordinator.start(
            sessionID: sessionID,
            exerciseName: "卧推",
            endDate: Date().addingTimeInterval(60)
        )
        firstCancelContinuation?.resume()
        await stopTask.value

        XCTAssertTrue(startResult)
        XCTAssertEqual(scheduledSessionIDs, [sessionID])
        XCTAssertTrue(endedSessionIDs.isEmpty)
    }

    func testPreparedStopInvalidatesStartBeforeItsTaskBegins() async {
        let sessionID = UUID()
        var scheduledSessionIDs: [UUID] = []
        var immediateCancellations: [UUID] = []
        var endedSessionIDs: [UUID] = []

        let coordinator = RestTimerCoordinator(
            upsertActivity: { _, _ in },
            endActivity: { endedSessionIDs.append($0) },
            scheduleNotification: { sessionID, _, _, _ in
                scheduledSessionIDs.append(sessionID)
                return true
            },
            cancelNotification: { _, _ in },
            cancelNotificationImmediately: { immediateCancellations.append($0) },
            cancelSessionNotifications: { _ in }
        )

        let staleStart = coordinator.prepareStart(
            sessionID: sessionID,
            exerciseName: "深蹲",
            endDate: Date().addingTimeInterval(60)
        )
        let stop = coordinator.prepareStop(sessionID: sessionID)

        let staleResult = await coordinator.performStart(staleStart)
        await coordinator.performStop(stop)

        XCTAssertTrue(staleResult)
        XCTAssertTrue(scheduledSessionIDs.isEmpty)
        XCTAssertEqual(endedSessionIDs, [sessionID])
        XCTAssertEqual(immediateCancellations, [sessionID, sessionID])
    }

    func testPreparedStartInvalidatesStopBeforeItsTaskBegins() async {
        let sessionID = UUID()
        var scheduledEndDates: [Date] = []
        var immediateCancellations: [UUID] = []
        var endedSessionIDs: [UUID] = []

        let coordinator = RestTimerCoordinator(
            upsertActivity: { _, _ in },
            endActivity: { endedSessionIDs.append($0) },
            scheduleNotification: { _, _, endDate, _ in
                scheduledEndDates.append(endDate)
                return true
            },
            cancelNotification: { _, _ in },
            cancelNotificationImmediately: { immediateCancellations.append($0) },
            cancelSessionNotifications: { _ in }
        )

        let staleStop = coordinator.prepareStop(sessionID: sessionID)
        let nextEndDate = Date().addingTimeInterval(90)
        let nextStart = coordinator.prepareStart(
            sessionID: sessionID,
            exerciseName: "卧推",
            endDate: nextEndDate
        )

        await coordinator.performStop(staleStop)
        let startResult = await coordinator.performStart(nextStart)

        XCTAssertTrue(startResult)
        XCTAssertTrue(endedSessionIDs.isEmpty)
        XCTAssertEqual(scheduledEndDates, [nextEndDate])
        XCTAssertEqual(immediateCancellations, [sessionID, sessionID])
    }
}
