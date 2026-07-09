import ActivityKit
import Foundation

// One activity persists all day and is updated in place as the user moves
// between tracked apps — Activity.request() only works from the main app,
// so the DeviceActivityMonitor extension must always land on an update path.
// The current app therefore lives in ContentState, not in the attributes.
struct TimeTrackerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        // accumulatedStart = Date() - totalSecondsToday
        // Text(accumulatedStart, style: .timer) ticks live and shows total time
        let appBundleId: String
        let appName: String
        let accumulatedStart: Date
        // Total confirmed by the last threshold event. Shown frozen once the
        // activity goes stale (no thresholds firing = user left tracked apps),
        // so the ticking timer never overstates idle time.
        let lastUpdatedTotalSeconds: Int
        // Only threshold events prove the user is actively inside a tracked
        // app, so only they may start the timer ticking (isLive = true). The
        // main app surfacing the current total shows it static and exact.
        let isLive: Bool
        // How long the timer may tick past the last confirmed total before
        // freezing: the current threshold band's gap + reporting margin.
        // There is no "user left the app" event — this bounds the overshoot.
        let capSeconds: Int
    }

    let day: String
}
