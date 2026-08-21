import ActivityKit
import Foundation

struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let endsAt: Date
    }

    /// Stable routing metadata only. No student name or health information is
    /// exposed to the system surface.
    let sessionID: String
}
