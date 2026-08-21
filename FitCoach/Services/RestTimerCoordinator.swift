import Foundation

@MainActor
final class RestTimerCoordinator {
    static let shared = RestTimerCoordinator()

    typealias ActivityUpsert = (UUID, Date) async -> Void
    typealias ActivityEnd = (UUID) async -> Void
    typealias NotificationSchedule = (UUID, String, Date, UUID) async -> Bool
    typealias NotificationCancel = (UUID, UUID) -> Void
    typealias SessionNotificationsCancel = (UUID) async -> Void

    private let upsertActivity: ActivityUpsert
    private let endActivity: ActivityEnd
    private let scheduleNotification: NotificationSchedule
    private let cancelNotification: NotificationCancel
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
        cancelSessionNotifications: @escaping SessionNotificationsCancel = { sessionID in
            await RestNotificationService.cancel(for: sessionID)
        }
    ) {
        self.upsertActivity = upsertActivity
        self.endActivity = endActivity
        self.scheduleNotification = scheduleNotification
        self.cancelNotification = cancelNotification
        self.cancelSessionNotifications = cancelSessionNotifications
    }

    @discardableResult
    func start(sessionID: UUID, exerciseName: String, endDate: Date) async -> Bool {
        guard endDate > Date() else {
            await stop(sessionID: sessionID)
            return true
        }

        let operationID = beginOperation(for: sessionID)
        defer { finishOperation(operationID, for: sessionID) }
        await cancelSessionNotifications(sessionID)
        guard isCurrent(operationID, for: sessionID) else { return true }

        await upsertActivity(sessionID, endDate)
        guard isCurrent(operationID, for: sessionID) else { return true }

        let scheduled = await scheduleNotification(sessionID, exerciseName, endDate, operationID)
        guard isCurrent(operationID, for: sessionID) else {
            cancelNotification(sessionID, operationID)
            return true
        }
        return scheduled
    }

    func stop(sessionID: UUID) async {
        let operationID = beginOperation(for: sessionID)
        defer { finishOperation(operationID, for: sessionID) }
        await cancelSessionNotifications(sessionID)
        guard isCurrent(operationID, for: sessionID) else { return }
        await endActivity(sessionID)
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
