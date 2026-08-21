import ActivityKit
import Foundation

@MainActor
enum RestActivityService {
    static func upsert(for sessionID: UUID, endDate: Date) async {
        guard endDate > Date() else {
            await end(for: sessionID)
            return
        }

        let sessionKey = sessionID.uuidString
        let content = ActivityContent(
            state: RestActivityAttributes.ContentState(endsAt: endDate),
            staleDate: endDate
        )

        for activity in Activity<RestActivityAttributes>.activities {
            if activity.attributes.sessionID == sessionKey {
                await activity.update(content)
            } else {
                await end(activity)
            }
        }

        guard !Activity<RestActivityAttributes>.activities.contains(where: {
            $0.attributes.sessionID == sessionKey
        }) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        _ = try? Activity<RestActivityAttributes>.request(
            attributes: RestActivityAttributes(sessionID: sessionKey),
            content: content,
            pushType: nil
        )
    }

    static func end(for sessionID: UUID) async {
        let sessionKey = sessionID.uuidString
        for activity in Activity<RestActivityAttributes>.activities
        where activity.attributes.sessionID == sessionKey {
            await end(activity)
        }
    }

    static func endExpiredActivities(now: Date = Date()) async {
        for activity in Activity<RestActivityAttributes>.activities
        where activity.content.state.endsAt <= now {
            await end(activity)
        }
    }

    static func reconcile(sessionID: UUID, restEndsAt: Date?) async {
        guard let restEndsAt, restEndsAt > Date() else {
            await end(for: sessionID)
            return
        }
        await upsert(for: sessionID, endDate: restEndsAt)
    }

    private static func end(_ activity: Activity<RestActivityAttributes>) async {
        let finalContent = ActivityContent(
            state: RestActivityAttributes.ContentState(endsAt: Date()),
            staleDate: nil
        )
        await activity.end(finalContent, dismissalPolicy: .immediate)
    }
}
