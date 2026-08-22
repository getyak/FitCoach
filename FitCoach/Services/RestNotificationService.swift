import Foundation
import UserNotifications

enum RestNotificationService {
    static let enabledKey = "restNotificationsEnabled"

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    static func schedule(
        for sessionID: UUID,
        exerciseName: String,
        endDate: Date,
        operationID: UUID
    ) async -> Bool {
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return true }
        let seconds = endDate.timeIntervalSinceNow
        guard seconds > 1 else { return true }

        let content = UNMutableNotificationContent()
        content.title = "休息结束"
        content.body = "可以继续 \(exerciseName) 的下一组。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier(for: sessionID),
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    static func cancel(for sessionID: UUID, operationID: UUID) {
        cancelImmediately(for: sessionID)
    }

    static func cancelImmediately(for sessionID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier(for: sessionID)])
    }

    static func cancel(for sessionID: UUID) async {
        let center = UNUserNotificationCenter.current()
        let prefix = identifierPrefix(for: sessionID)
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("rest:") }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func identifierPrefix(for sessionID: UUID) -> String {
        "rest:\(sessionID.uuidString):"
    }

    private static func identifier(for sessionID: UUID) -> String {
        "\(identifierPrefix(for: sessionID))current"
    }
}
