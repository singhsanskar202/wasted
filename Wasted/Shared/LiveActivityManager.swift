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

    // TUNING KNOB. How long the island's minute display keeps self-advancing
    // after the main app anchored it. Longer = stays alive through longer
    // sessions without opening Wasted; shorter = less visible overcount when
    // the user leaves tracked apps and the timer keeps running. Once it runs
    // out, the display freezes, dims, and snaps back to the exact total.
    static let optimisticTickCapSeconds = 900

    func startOrUpdate(totalSeconds: Int, capSeconds: Int) async {
        let content = Self.makeContent(totalSeconds: totalSeconds, capSeconds: capSeconds)
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

    // Extension-safe: blocks until the update lands. The extension cannot
    // create an activity (request → unsupportedTarget), so this only updates
    // an existing one; if none exists yet the main app will create it on its
    // next foreground.
    // KNOWN NON-FUNCTIONAL today: Activity.activities is always empty inside
    // the DeviceActivityMonitor extension — ActivityKit only attaches to the
    // main app process (verified on device, iOS 26; matches Apple forums).
    // Kept because it costs ~1.5s, logs proof either way, and starts working
    // by itself if Apple ever lifts the restriction.
    func updateExistingAndWait(totalSeconds: Int, capSeconds: Int) {
        let content = Self.makeContent(totalSeconds: totalSeconds, capSeconds: capSeconds)
        let completed = runBlocking(timeout: 6) {
            let start = Date()
            var existing = Activity<TimeTrackerAttributes>.activities.first
            var tries = 0
            while existing == nil && tries < 3 {
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

    private static func makeContent(totalSeconds: Int, capSeconds: Int) -> ActivityContent<TimeTrackerAttributes.ContentState> {
        let state = TimeTrackerAttributes.ContentState(
            // accumulatedStart = now - totalSeconds, so the timer text reads
            // as the running total.
            accumulatedStart: Date(timeIntervalSinceNow: -Double(totalSeconds)),
            totalSeconds: totalSeconds,
            capSeconds: capSeconds
        )
        // Dim shortly after the self-advancing window runs out — the view
        // swaps to the exact static total at the same moment.
        return ActivityContent(
            state: state,
            staleDate: Date(timeIntervalSinceNow: Double(max(capSeconds, 60)) + 60)
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
