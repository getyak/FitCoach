import Foundation

@MainActor
final class RestTimerCoordinator {
    static let shared = RestTimerCoordinator()

    typealias ActivityUpsert = (UUID, Date) async -> Void
    typealias ActivityEnd = (UUID) async -> Void
    typealias NotificationSchedule = (UUID, String, Date, UUID) async -> Bool
    typealias NotificationCancel = (UUID, UUID) -> Void
    typealias NotificationCancelImmediately = (UUID) -> Void
    typealias SessionNotificationsCancel = (UUID) async -> Void

    struct StartOperation: Equatable {
        fileprivate let sessionID: UUID
        fileprivate let exerciseName: String
        fileprivate let endDate: Date
        fileprivate let token: UUID
    }

    struct StopOperation: Equatable {
        fileprivate let sessionID: UUID
        fileprivate let token: UUID
    }

    private let upsertActivity: ActivityUpsert
    private let endActivity: ActivityEnd
    private let scheduleNotification: NotificationSchedule
    private let cancelNotification: NotificationCancel
    private let cancelNotificationImmediately: NotificationCancelImmediately
    private let cancelSessionNotifications: SessionNotificationsCancel
    private var operationTokens: [UUID: UUID] = [:]

    init(
        upsertActivity: @escaping ActivityUpsert = { sessionID, endDate in
            await RestActivityService.upsert(for: sessionID, endDate: endDate)
        },
        endActivity: @escaping ActivityEnd = { sessionID in
            await RestActivityService.end(for: sessionID)
        },
        scheduleNotification: @escaping NotificationSchedule = { sessionID, exerciseName, endDate, operationID in
            await RestNotificationService.schedule(
                for: sessionID,
                exerciseName: exerciseName,
                endDate: endDate,
                operationID: operationID
            )
        },
        cancelNotification: @escaping NotificationCancel = { sessionID, operationID in
            RestNotificationService.cancel(for: sessionID, operationID: operationID)
        },
        cancelNotificationImmediately: @escaping NotificationCancelImmediately = { sessionID in
            RestNotificationService.cancelImmediately(for: sessionID)
        },
        cancelSessionNotifications: @escaping SessionNotificationsCancel = { sessionID in
            await RestNotificationService.cancel(for: sessionID)
        }
    ) {
        self.upsertActivity = upsertActivity
        self.endActivity = endActivity
        self.scheduleNotification = scheduleNotification
        self.cancelNotification = cancelNotification
        self.cancelNotificationImmediately = cancelNotificationImmediately
        self.cancelSessionNotifications = cancelSessionNotifications
    }

    @discardableResult
    func start(sessionID: UUID, exerciseName: String, endDate: Date) async -> Bool {
        let operation = prepareStart(
            sessionID: sessionID,
            exerciseName: exerciseName,
            endDate: endDate
        )
        return await performStart(operation)
    }

    func prepareStart(sessionID: UUID, exerciseName: String, endDate: Date) -> StartOperation {
        let token = beginOperation(for: sessionID)
        cancelNotificationImmediately(sessionID)
        return StartOperation(
            sessionID: sessionID,
            exerciseName: exerciseName,
            endDate: endDate,
            token: token
        )
    }

    @discardableResult
    func performStart(_ operation: StartOperation) async -> Bool {
        guard operation.endDate > Date() else {
            let stopOperation = prepareStop(sessionID: operation.sessionID)
            await performStop(stopOperation)
            return true
        }

        defer { finishOperation(operation.token, for: operation.sessionID) }
        guard isCurrent(operation.token, for: operation.sessionID) else { return true }
        await cancelSessionNotifications(operation.sessionID)
        guard isCurrent(operation.token, for: operation.sessionID) else { return true }

        await upsertActivity(operation.sessionID, operation.endDate)
        guard isCurrent(operation.token, for: operation.sessionID) else { return true }

        let scheduled = await scheduleNotification(
            operation.sessionID,
            operation.exerciseName,
            operation.endDate,
            operation.token
        )
        guard isCurrent(operation.token, for: operation.sessionID) else {
            cancelNotification(operation.sessionID, operation.token)
            return true
        }
        return scheduled
    }

    func stop(sessionID: UUID) async {
        let operation = prepareStop(sessionID: sessionID)
        await performStop(operation)
    }

    func prepareStop(sessionID: UUID) -> StopOperation {
        let token = beginOperation(for: sessionID)
        cancelNotificationImmediately(sessionID)
        return StopOperation(sessionID: sessionID, token: token)
    }

    func performStop(_ operation: StopOperation) async {
        defer { finishOperation(operation.token, for: operation.sessionID) }
        guard isCurrent(operation.token, for: operation.sessionID) else { return }
        await cancelSessionNotifications(operation.sessionID)
        guard isCurrent(operation.token, for: operation.sessionID) else { return }
        await endActivity(operation.sessionID)
    }

    func reconcile(sessionID: UUID, exerciseName: String, restEndsAt: Date?) async {
        guard let restEndsAt, restEndsAt > Date() else {
            await stop(sessionID: sessionID)
            return
        }
        _ = await start(sessionID: sessionID, exerciseName: exerciseName, endDate: restEndsAt)
    }

    private func beginOperation(for sessionID: UUID) -> UUID {
        let token = UUID()
        operationTokens[sessionID] = token
        return token
    }

    private func isCurrent(_ token: UUID, for sessionID: UUID) -> Bool {
        operationTokens[sessionID] == token
    }

    private func finishOperation(_ token: UUID, for sessionID: UUID) {
        guard isCurrent(token, for: sessionID) else { return }
        operationTokens.removeValue(forKey: sessionID)
    }
}
