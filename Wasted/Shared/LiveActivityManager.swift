import ActivityKit
import Foundation

// Activity.request() can only succeed from the main app process — the
// DeviceActivityMonitor extension always gets .unsupportedTarget. The main
// app creates the single daily activity on foreground; after that, every
// caller (extension included) updates that same activity in place, even when
// the user switches tracked apps. Ending + recreating on app switch is what
// used to strand the extension on the request path and kill the Island.
final class LiveActivityManager {

    // isLive: true only from a threshold event (proof the user is actively in
    // a tracked app right now) — that's what lets the timer tick. The main
    // app passes false and the island shows the exact total, static.
    func startOrUpdate(bundleId: String, appName: String, totalSeconds: Int, isLive: Bool) {
        let capSeconds = Self.thresholdGapSeconds(afterMinutes: totalSeconds / 60) + 120
        // accumulatedStart = now - totalSeconds
        // Text(accumulatedStart, style: .timer) then shows totalSeconds + live elapsed
        let state = TimeTrackerAttributes.ContentState(
            appBundleId: bundleId,
            appName: appName,
            accumulatedStart: Date(timeIntervalSinceNow: -Double(totalSeconds)),
            lastUpdatedTotalSeconds: totalSeconds,
            isLive: isLive,
            capSeconds: capSeconds
        )
        // Stale (dimmed) shortly after the tick cap runs out; a static
        // display is already exact, so it only dims after a long gap.
        let content = ActivityContent(
            state: state,
            staleDate: Date(timeIntervalSinceNow: isLive ? Double(capSeconds) + 60 : 3600)
        )

        let activities = Activity<TimeTrackerAttributes>.activities
        if let existing = activities.first {
            // Defensive: only one activity should ever exist.
            for extra in activities.dropFirst() {
                Task { await extra.end(nil, dismissalPolicy: .immediate) }
            }
            Task { await existing.update(content) }
        } else {
            _ = try? Activity<TimeTrackerAttributes>.request(
                attributes: TimeTrackerAttributes(day: Self.dayString()),
                content: content,
                pushType: nil
            )
        }
    }

    func endAllActivities() {
        for activity in Activity<TimeTrackerAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    var hasActiveActivity: Bool {
        !Activity<TimeTrackerAttributes>.activities.isEmpty
    }

    // Mirrors the bands in ActivityScheduler.thresholdMinutes: how far away
    // the next threshold event can be at this point in the day.
    private static func thresholdGapSeconds(afterMinutes minutes: Int) -> Int {
        switch minutes {
        case ..<5: return 60
        case ..<120: return 300
        case ..<240: return 600
        default: return 900
        }
    }

    private static func dayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

}
