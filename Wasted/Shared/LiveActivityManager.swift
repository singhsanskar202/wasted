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

    // TUNING KNOB. The island can't be updated from the background (the usage
    // extension can't reach the activity, and push is impossible for Screen
    // Time data), so it ticks optimistically from the last exact total set on
    // app foreground. This caps how long it keeps ticking before freezing —
    // during real tracked-app use the tick is exact (1s/1s), so this only
    // bounds how far it can overcount while the user is idle. Raise for a more
    // "alive" feel, lower to reduce idle overcount.
    static let optimisticTickCapSeconds = 600

    func startOrUpdate(totalSeconds: Int, isLive: Bool) async {
        let content = Self.makeContent(totalSeconds: totalSeconds, isLive: isLive)
        let activities = Activity<TimeTrackerAttributes>.activities
        if let existing = activities.first {
            for extra in activities.dropFirst() {
                await extra.end(nil, dismissalPolicy: .immediate)
            }
            await existing.update(content)
            Self.log("main updated id=\(existing.id) total=\(totalSeconds) isLive=\(isLive)")
        } else {
            let activity = try? Activity<TimeTrackerAttributes>.request(
                attributes: TimeTrackerAttributes(day: Self.dayString()),
                content: content,
                pushType: nil
            )
            Self.log("main created id=\(activity?.id ?? "nil") total=\(totalSeconds) isLive=\(isLive)")
        }
    }

    // Extension-safe: blocks until the update lands. The extension cannot
    // create an activity (request → unsupportedTarget), so this only updates
    // an existing one; if none exists yet the main app will create it on its
    // next foreground.
    func updateExistingAndWait(totalSeconds: Int) {
        let content = Self.makeContent(totalSeconds: totalSeconds, isLive: true)
        let completed = runBlocking(timeout: 12) {
            // A freshly-spawned extension process has not yet synced the app's
            // activity list from the system daemon, so .activities is empty for
            // the first moments. Poll until it appears (up to ~5s; the caller
            // runs this last, so a long wait can't starve other threshold work).
            let start = Date()
            var existing = Activity<TimeTrackerAttributes>.activities.first
            var tries = 0
            while existing == nil && tries < 10 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                existing = Activity<TimeTrackerAttributes>.activities.first
                tries += 1
            }
            let waitedMs = Int(Date().timeIntervalSince(start) * 1000)
            Self.log("ext update total=\(totalSeconds) activities=\(Activity<TimeTrackerAttributes>.activities.count) tries=\(tries) waited=\(waitedMs)ms enabled=\(ActivityAuthorizationInfo().areActivitiesEnabled)")
            guard let existing else {
                Self.log("ext update: NO activity after wait")
                return
            }
            await existing.update(content)
            Self.log("ext update: applied to id=\(existing.id)")
        }
        if !completed { Self.log("ext update: TIMED OUT") }
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

    private static func makeContent(totalSeconds: Int, isLive: Bool) -> ActivityContent<TimeTrackerAttributes.ContentState> {
        let capSeconds = optimisticTickCapSeconds
        let state = TimeTrackerAttributes.ContentState(
            // accumulatedStart = now - totalSeconds, so Text(timerInterval:)
            // shows totalSeconds and ticks up from there.
            accumulatedStart: Date(timeIntervalSinceNow: -Double(totalSeconds)),
            lastUpdatedTotalSeconds: totalSeconds,
            isLive: isLive,
            capSeconds: capSeconds
        )
        // A live activity goes stale (dims, stops ticking) shortly after the
        // tick cap, so leaving a tracked app reads as a frozen session within
        // ~a threshold gap. A static (main-app) display is already exact, so
        // it only dims after a long idle.
        return ActivityContent(
            state: state,
            staleDate: Date(timeIntervalSinceNow: isLive ? Double(capSeconds) + 30 : 3600)
        )
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

    private static func dayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
