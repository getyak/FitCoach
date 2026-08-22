// ActivityKit's async handles are safe to update from this serial actor, but
// the iOS 26 SDK has not fully annotated those handles as Sendable for Swift 6.
@preconcurrency import ActivityKit
import Foundation

actor RestActivityService {
    static let shared = RestActivityService()

    private var generations: [UUID: Int] = [:]

    func upsert(for sessionID: UUID, endDate: Date) async {
        guard endDate > Date() else {
            await end(for: sessionID)
            return
        }

        let generation = beginOperation(for: sessionID)
        defer { finishOperation(generation, for: sessionID) }

        let sessionKey = sessionID.uuidString
        let content = ActivityContent(
            state: RestActivityAttributes.ContentState(endsAt: endDate),
            staleDate: endDate
        )

        for activity in Activity<RestActivityAttributes>.activities {
            if activity.attributes.sessionID == sessionKey {
                await activity.update(content)
            } else {
                if let otherSessionID = UUID(uuidString: activity.attributes.sessionID) {
                    _ = beginOperation(for: otherSessionID)
                }
                await end(activity)
            }
            guard isCurrent(generation, for: sessionID) else { return }
        }

        guard isCurrent(generation, for: sessionID) else { return }
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

    func end(for sessionID: UUID) async {
        let generation = beginOperation(for: sessionID)
        defer { finishOperation(generation, for: sessionID) }
        let sessionKey = sessionID.uuidString
        for activity in Activity<RestActivityAttributes>.activities
        where activity.attributes.sessionID == sessionKey {
            guard isCurrent(generation, for: sessionID) else { return }
            await end(activity)
            guard isCurrent(generation, for: sessionID) else { return }
        }
    }

    func endExpiredActivities(now: Date = Date()) async {
        for activity in Activity<RestActivityAttributes>.activities
        where activity.content.state.endsAt <= now {
            if let sessionID = UUID(uuidString: activity.attributes.sessionID) {
                let generation = beginOperation(for: sessionID)
                guard isCurrent(generation, for: sessionID) else { continue }
                await end(activity)
                finishOperation(generation, for: sessionID)
            } else {
                await end(activity)
            }
        }
    }

    func reconcile(sessionID: UUID, restEndsAt: Date?) async {
        guard let restEndsAt, restEndsAt > Date() else {
            await end(for: sessionID)
            return
        }
        await upsert(for: sessionID, endDate: restEndsAt)
    }

    private func end(_ activity: Activity<RestActivityAttributes>) async {
        let finalContent = ActivityContent(
            state: RestActivityAttributes.ContentState(endsAt: Date()),
            staleDate: nil
        )
        await activity.end(finalContent, dismissalPolicy: .immediate)
    }

    private func beginOperation(for sessionID: UUID) -> Int {
        let generation = (generations[sessionID] ?? 0) + 1
        generations[sessionID] = generation
        return generation
    }

    private func isCurrent(_ generation: Int, for sessionID: UUID) -> Bool {
        generations[sessionID] == generation
    }

    private func finishOperation(_ generation: Int, for sessionID: UUID) {
        guard isCurrent(generation, for: sessionID) else { return }
        generations.removeValue(forKey: sessionID)
    }
}
