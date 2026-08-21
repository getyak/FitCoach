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

    static func schedule(for sessionID: UUID, exerciseName: String, endDate: Date) async {
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }
        let seconds = endDate.timeIntervalSinceNow
        guard seconds > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = "休息结束"
        content.body = "可以继续 \(exerciseName) 的下一组。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier(for: sessionID),
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancel(for sessionID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier(for: sessionID)]
        )
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("rest:") }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func identifier(for sessionID: UUID) -> String {
        "rest:\(sessionID.uuidString)"
    }
}
