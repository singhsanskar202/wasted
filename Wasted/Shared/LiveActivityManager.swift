import ActivityKit
import Foundation

// WHY THE ISLAND KEPT VANISHING.
//
// iOS hard-caps a Live Activity at EIGHT HOURS from the moment it is created.
// The system then ends it, leaves it on the Lock Screen for up to four more
// hours, and removes it. Updating the activity does NOT extend that window —
// there is no API that does. The old design ("one activity, created in the
// morning, lives all day, kept fresh by updates") was never possible, and the
// comment in WastedApp asserting that an update "resets that clock" was simply
// wrong.
//
// Worse, an ended activity STAYS in Activity.activities for those last four
// hours, with its `day` still matching today. The old code checked the day but
// never the activityState, so it took the update branch and called update() on a
// corpse — a no-op — and never called request(). That is why the island didn't
// merely disappear: it never came back, not even when the app was reopened.
//
// The fix is ROTATION. We cannot extend an activity past eight hours, but we can
// end one and request a fresh one, which starts a clean eight-hour window. Any
// run of the main app (foreground or BG refresh) that finds an activity too old
// or no longer updatable replaces it. For an app the user actually opens, that
// keeps the island alive indefinitely.
//
// Activity.request() only succeeds in the main app process — the
// DeviceActivityMonitor extension always gets .unsupportedTarget, and cannot
// even see Activity.activities. So the main app is the only thing that can do
// any of this.

// The decision, extracted from ActivityKit so it can actually be tested —
// Activity values cannot be constructed in a unit test.
struct ActivitySnapshot: Equatable {
    let id: String
    let day: String
    /// `.active` or `.stale`. An `.ended`/`.dismissed` activity still appears in
    /// Activity.activities but silently swallows every update.
    let isUpdatable: Bool
    let startedAt: Date
}

enum LiveActivityDecision: Equatable {
    case update(id: String)
    case replace
}

enum LiveActivityPolicy {
    // Rotate an hour before iOS's 8h guillotine. The margin matters: the app may
    // not run again for a while, and an activity replaced at 7h59m would be dead
    // before it was ever seen.
    static let rotateAfter: TimeInterval = 7 * 3600

    static func decide(
        existing: [ActivitySnapshot],
        today: String,
        now: Date = Date()
    ) -> LiveActivityDecision {
        let usable = existing.first {
            $0.day == today                                        // not yesterday's
                && $0.isUpdatable                                  // not a corpse
                && now.timeIntervalSince($0.startedAt) < rotateAfter  // not about to be culled
        }
        guard let usable else { return .replace }
        return .update(id: usable.id)
    }
}

final class LiveActivityManager {

    func startOrUpdate(totalSeconds: Int) async {
        let content = Self.makeContent(totalSeconds: totalSeconds)
        let today = Self.dayString()
        let activities = Activity<TimeTrackerAttributes>.activities

        let decision = LiveActivityPolicy.decide(
            existing: activities.map(Self.snapshot),
            today: today
        )

        switch decision {
        case .update(let id):
            // End every other activity — a stale duplicate on the Lock Screen
            // reads as a bug, and only one of them is the real count.
            for other in activities where other.id != id {
                await other.end(nil, dismissalPolicy: .immediate)
            }
            guard let target = activities.first(where: { $0.id == id }) else { return }
            await target.update(content)
            Self.log("main updated id=\(id) total=\(totalSeconds)")

        case .replace:
            for dead in activities {
                await dead.end(nil, dismissalPolicy: .immediate)
            }
            let activity = try? Activity<TimeTrackerAttributes>.request(
                attributes: TimeTrackerAttributes(day: today, startedAt: Date()),
                content: content,
                pushType: nil
            )
            Self.log("main created id=\(activity?.id ?? "nil") total=\(totalSeconds) replaced=\(activities.count)")
        }
    }

    private static func snapshot(_ activity: Activity<TimeTrackerAttributes>) -> ActivitySnapshot {
        ActivitySnapshot(
            id: activity.id,
            day: activity.attributes.day,
            isUpdatable: activity.activityState == .active || activity.activityState == .stale,
            startedAt: activity.attributes.startedAt
        )
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
