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
    // Every FOREGROUND pass where the activity has aged past this rotates it —
    // end + fresh request — so each open of the app restarts the 8h clock
    // instead of inheriting whatever was left of the morning's window. The old
    // policy rotated only at 7h, which meant an open at hour 6 bought nothing
    // and the island still died at hour 8. An hour is the balance point: often
    // enough that the island survives 8h past nearly every open, rare enough
    // that the end+request flicker isn't on every launch.
    static let foregroundRotateAfter: TimeInterval = 3600

    static func decide(
        existing: [ActivitySnapshot],
        today: String,
        now: Date = Date(),
        canCreate: Bool
    ) -> LiveActivityDecision {
        let usable = existing.first {
            $0.day == today            // not yesterday's
                && $0.isUpdatable      // not a corpse
        }
        guard let usable else { return .replace }
        // No age cutoff for updates: the old `< 7h` filter made BACKGROUND runs
        // treat a live 7h activity as unusable, so updates stopped a full hour
        // before iOS actually killed it. An activity is worth updating until
        // the moment it dies; only creation decides whether dying matters.
        if canCreate, now.timeIntervalSince(usable.startedAt) >= foregroundRotateAfter {
            return .replace
        }
        return .update(id: usable.id)
    }
}

// Every ActivityKit mutation in the main app funnels through here.
//
// Two callers now push to the island — the scene coming active, and HomeView's
// five-second poll while it's on screen — and at launch they fire at almost the
// same moment. Two concurrent `startOrUpdate`s can both look at an empty
// `Activity.activities`, both decide `.replace`, and both call `request()`,
// leaving TWO live activities racing on the Lock Screen. An actor serialises
// them, so the second one sees what the first one created.
actor LiveActivityCoordinator {
    static let shared = LiveActivityCoordinator()
    private let manager = LiveActivityManager()

    /// `canCreate` is FALSE from any background caller. See startOrUpdate.
    func sync(totalSeconds: Int, canCreate: Bool) async {
        await manager.startOrUpdate(totalSeconds: totalSeconds, canCreate: canCreate)
    }
}

final class LiveActivityManager {

    // A LIVE ACTIVITY CAN ONLY BE *STARTED* FROM THE FOREGROUND.
    //
    // Two days of device logs make this unambiguous: every single
    // `Activity.request()` failure came from a background run, and every
    // successful CREATE came from a foreground one. Background runs CAN update an
    // activity that already exists — they did so dozens of times — they just
    // cannot bring one into being. (Push-to-start is the documented exception,
    // and it needs a server, which this app will never have.)
    //
    // The old code didn't know that, and it was worse than merely failing: the
    // `.replace` path ENDS every existing activity and THEN requests a new one. A
    // background rotation (activity older than 7h) would therefore have killed a
    // perfectly good island and then failed to build its replacement — actively
    // destroying the thing it was trying to preserve.
    //
    // So background callers may only ever UPDATE. If there's nothing to update,
    // they do nothing and wait for the user to open the app.
    func startOrUpdate(totalSeconds: Int, canCreate: Bool) async {
        let content = Self.makeContent(totalSeconds: totalSeconds)
        let today = Self.dayString()
        let activities = Activity<TimeTrackerAttributes>.activities

        let decision = LiveActivityPolicy.decide(
            existing: activities.map(Self.snapshot),
            today: today,
            canCreate: canCreate
        )

        // Never end an activity we cannot replace. Reaching here from the
        // background means the island is DARK — dead or never started today —
        // and this process can't relight it. Record that for the monitor
        // extension, which is the only thing guaranteed to speak to the user
        // before they next open the app.
        if case .replace = decision, !canCreate {
            IslandStatus.markDown(today: today)
            EventLog.log(.island, "background: island DOWN, cannot create (foreground-only) — flagged for nudge, \(activities.count) activity(s) untouched")
            return
        }

        switch decision {
        case .update(let id):
            // End every other activity — a stale duplicate on the Lock Screen
            // reads as a bug, and only one of them is the real count.
            for other in activities where other.id != id {
                await other.end(nil, dismissalPolicy: .immediate)
            }
            guard let target = activities.first(where: { $0.id == id }) else { return }
            await target.update(content)
            IslandStatus.markAlive()
            EventLog.log(.island, "updated id=\(id) total=\(totalSeconds)s")

        case .replace:
            // WHY we replaced is the whole diagnosis. "The island vanished" took
            // hours to explain; a line saying `state=ended age=9h` would have
            // said it instantly.
            let why = activities.isEmpty
                ? "no activity exists"
                : activities.map {
                    let ageMinutes = Int(Date().timeIntervalSince($0.attributes.startedAt) / 60)
                    return "id=\($0.id) day=\($0.attributes.day) state=\($0.activityState) age=\(ageMinutes)m"
                }.joined(separator: " | ")
            EventLog.log(.island, "REPLACING — \(why)")

            for dead in activities {
                await dead.end(nil, dismissalPolicy: .immediate)
            }
            let activity = try? Activity<TimeTrackerAttributes>.request(
                attributes: TimeTrackerAttributes(day: today, startedAt: Date()),
                content: content,
                pushType: nil
            )
            if let activity {
                IslandStatus.markAlive()
                EventLog.log(.island, "CREATED id=\(activity.id) total=\(totalSeconds)s")
            } else {
                // request() throws if the user disabled Live Activities, or if
                // iOS is rate-limiting. Deliberately NOT marked down: the first
                // is a choice the nudge shouldn't nag about, the second is
                // transient.
                EventLog.error(.island, "Activity.request() FAILED — no island. enabled=\(ActivityAuthorizationInfo().areActivitiesEnabled)")
            }
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
            EventLog.log(.island, "ext update landed (Apple lifted the restriction!) id=\(existing.id)")
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

    private static func dayString() -> String { AppGroupKeys.dayString() }
}

// THE DEAD ISLAND'S ONLY VOICE.
//
// Only the main app can revive a dead island, and it may not run for hours. The
// monitor extension, meanwhile, fires on every threshold — it just can't touch
// ActivityKit. This is the handoff between them: the app's background runs
// record that the island is dark, and the extension states that fact ONCE,
// inside a nudge the user was getting anyway. The tap that opens the app is the
// tap that relights the island — no extra notification ever spends the user's
// attention on our plumbing.
//
// Day-scoped on both sides: a flag from yesterday must not caption today's
// nudges, and midnight resets the island's view on its own (staleDate).
enum IslandStatus {
    /// Background run found nothing updatable — the island is dark and this
    /// process can't fix it.
    static func markDown(today: String, defaults: UserDefaults = .wastedShared) {
        defaults.set(today, forKey: AppGroupKeys.islandDownDayKey)
    }

    /// Any successful create or update. Clears the announcement too, so a
    /// SECOND death on the same day earns its own single mention.
    static func markAlive(defaults: UserDefaults = .wastedShared) {
        defaults.removeObject(forKey: AppGroupKeys.islandDownDayKey)
        defaults.removeObject(forKey: AppGroupKeys.islandDownAnnouncedDayKey)
    }

    /// True exactly once per death: a repeated line stops being read, and a
    /// line that stops being read stops working (same law as the nudge bank).
    static func takeAnnouncement(today: String, defaults: UserDefaults = .wastedShared) -> Bool {
        guard defaults.string(forKey: AppGroupKeys.islandDownDayKey) == today,
              defaults.string(forKey: AppGroupKeys.islandDownAnnouncedDayKey) != today
        else { return false }
        defaults.set(today, forKey: AppGroupKeys.islandDownAnnouncedDayKey)
        return true
    }
}
