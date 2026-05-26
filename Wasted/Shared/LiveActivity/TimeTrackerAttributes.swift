import ActivityKit
import Foundation

struct TimeTrackerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        // accumulatedStart = Date() - totalSecondsToday
        // SwiftUI Text(accumulatedStart, style: .timer) ticks live and shows total time
        let appBundleId: String
        let appName: String
        let accumulatedStart: Date
        let isActive: Bool
    }

    let appBundleId: String
    let appName: String
}
