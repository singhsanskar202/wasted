import ActivityKit
import Foundation

// One activity persists all day and is updated in place — Activity.request()
// only works from the main app. The DeviceActivityMonitor extension cannot
// reach the activity AT ALL (Activity.activities is always empty in that
// process — platform rule, not a bug), so the island can only be re-anchored
// by the main app (foreground / BG refresh). Between anchors the display
// self-advances via a system-rendered timer, minutes only.
struct TimeTrackerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        // accumulatedStart = now - totalSeconds at the moment of the update,
        // so a Text(timerInterval:) anchored here reads as the running total.
        let accumulatedStart: Date
        // Confirmed total at the last update — the exact static value shown
        // once the activity goes stale.
        let totalSeconds: Int
        // How far past totalSeconds the display may self-advance before it
        // freezes (0 = fully static). Bounds the overcount when the user
        // stops using tracked apps, since no process can stop the timer.
        let capSeconds: Int
    }

    let day: String
}
