import ActivityKit
import Foundation

// Activity.request() can only succeed from the main app process — the
// DeviceActivityMonitor extension always gets .unsupportedTarget. The main
// app creates the single daily activity on foreground; after that, every
// caller (extension included) updates that same activity in place, even when
// the user switches tracked apps. Ending + recreating on app switch is what
// used to strand the extension on the request path and kill the Island.
//
// CRITICAL: the DeviceActivityMonitor extension is suspended the moment its
// callback returns, so `Task { await activity.update() }` fire-and-forget is
// dropped before it runs — that was the "stuck timer" bug. The *AndWait
// methods block the callback on a semaphore until ActivityKit's async work
// actually completes. The main app has a normal run loop and uses the plain
// async methods.
final class LiveActivityManager {

    func startOrUpdate(totalSeconds: Int) async {
        let content = Self.makeContent(totalSeconds: totalSeconds)
        let today = Self.dayString()
        let activities = Activity<TimeTrackerAttributes>.activities
        // Yesterday's activity outlives midnight: the day rollover runs in the
        // monitor extension, which cannot reach activities (platform rule), so
        // its endAllActivitiesAndWait is a no-op. Replace anything from a
        // previous day instead of updating it in place.
        if let existing = activities.first, existing.attributes.day == today {
            for extra in activities.dropFirst() {
                await extra.end(nil, dismissalPolicy: .immediate)
            }
            await existing.update(content)
            Self.log("main updated id=\(existing.id) total=\(totalSeconds)")
        } else {
            for stale in activities {
                await stale.end(nil, dismissalPolicy: .immediate)
            }
            let activity = try? Activity<TimeTrackerAttributes>.request(
                attributes: TimeTrackerAttributes(day: today),
                content: content,
                pushType: nil
            )
            Self.log("main created id=\(activity?.id ?? "nil") total=\(totalSeconds) replaced=\(activities.count)")
        }
    }

    // Extension-safe: blocks until the update lands, since the extension is
    // suspended the instant its callback returns and a fire-and-forget Task
    // would be dropped.
    //
    // KNOWN NON-FUNCTIONAL: Activity.activities is always empty inside the
    // DeviceActivityMonitor extension — ActivityKit attaches only to the main
    // app process (device logs, iOS 26: `activities=0 enabled=true` on every
    // threshold, while the island was visibly on screen). The old version
    // polled 3 × 500ms hoping the list would sync; it never did, and that wait
    // burned ~1.6s of the extension's short wall-clock budget on every single
    // threshold — i.e. every 1–2 minutes of usage. Now it's a single attempt
    // that no-ops instantly, so the nudge/receipt/widget work is never at risk,
    // and it starts working by itself if Apple ever lifts the restriction.
    func updateExistingAndWait(totalSeconds: Int) {
        guard let existing = Activity<TimeTrackerAttributes>.activities.first else { return }
        let content = Self.makeContent(totalSeconds: totalSeconds)
        runBlocking(timeout: 4) {
            await existing.update(content)
            Self.log("ext update: applied to id=\(existing.id) total=\(totalSeconds)")
        }
    }

    func endAllActivities() async {
        for activity in Activity<TimeTrackerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // Extension-safe blocking end (for intervalDidEnd at midnight).
    func endAllActivitiesAndWait() {
        runBlocking {
            for activity in Activity<TimeTrackerAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    var hasActiveActivity: Bool {
        !Activity<TimeTrackerAttributes>.activities.isEmpty
    }

    // MARK: - Private

    private static func makeContent(totalSeconds: Int) -> ActivityContent<TimeTrackerAttributes.ContentState> {
        let now = Date()
        let state = TimeTrackerAttributes.ContentState(totalSeconds: totalSeconds, confirmedAt: now)
        // staleDate is pinned to MIDNIGHT, not to a freshness window. It is the
        // only re-render we get without a running process, and the day rollover
        // is the one moment the number becomes not-just-old but flatly wrong.
        // Spending it on a mid-day dim would have left the island showing
        // yesterday's total all night — the bug this replaces.
        return ActivityContent(state: state, staleDate: AppGroupKeys.nextMidnight(after: now))
    }

    // Runs an async body to completion from a synchronous, soon-to-be-suspended
    // extension callback. DeviceActivityMonitor grants a few seconds of wall
    // time; ActivityKit updates resolve in well under that. Returns whether the
    // body finished before the timeout.
    @discardableResult
    private func runBlocking(timeout: TimeInterval = 10, _ body: @escaping () async -> Void) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await body()
            semaphore.signal()
        }
        return semaphore.wait(timeout: .now() + timeout) == .success
    }

    // TEMP diagnostic — keeps the last 12 events in the App Group so a device
    // pull can show whether extension updates actually reach ActivityKit.
    static func log(_ message: String) {
        guard let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID) else { return }
        let entry = "\(Date()): \(message)"
        let previous = (defaults.string(forKey: "debug_la") ?? "").components(separatedBy: "\n")
        defaults.set(([entry] + previous).prefix(12).joined(separator: "\n"), forKey: "debug_la")
    }

    private static func dayString() -> String { AppGroupKeys.dayString() }
}
