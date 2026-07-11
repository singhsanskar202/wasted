import ActivityKit
import Foundation

// One activity persists all day and is updated in place — Activity.request()
// only works from the main app. The DeviceActivityMonitor extension cannot
// reach the activity AT ALL (Activity.activities is always empty in that
// process — platform rule, not a bug, re-confirmed on device 2026-07-11), so
// the island can only be re-anchored by the main app (foreground / BG refresh).
//
// The island therefore shows a CONFIRMED total and nothing else. It used to
// self-advance a timer between anchors, which assumed the user was inside a
// tracked app the whole time. Device logs killed that assumption: real usage
// is bursty (166m → 168m took 27 minutes of wall clock), so a wall-clock timer
// inflates the number while the phone is down and still freezes during the long
// sessions the product exists to confront. A confirmed total is always a true
// lower bound — usage only goes up — so it can lag, but it can never lie.
struct TimeTrackerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        // Exact usage across all tracked apps at the moment of the last anchor.
        let totalSeconds: Int
        // When that total was confirmed. Drives the dim: past
        // AppGroupKeys.confirmedFreshSeconds the number is known to be behind.
        let confirmedAt: Date
    }

    let day: String
}
