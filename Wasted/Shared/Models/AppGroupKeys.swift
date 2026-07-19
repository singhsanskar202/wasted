import Foundation

enum AppGroupKeys {
    static let appGroupID = "group.com.sanskar.Wasted"
    static let dailyUsageKey = "daily_usage"
    static let trackedSelectionKey = "tracked_selection"
    static let activeAppBundleIdKey = "active_app_bundle_id"
    static let activeSessionStartKey = "active_session_start"
    static let displayNamesKey = "display_names"
    // index -> ApplicationToken (JSON). The app's own screens render the real
    // name/icon via Label(token) from these; the Live Activity can't (system
    // process), but foreground app views can.
    static let appTokensKey = "app_tokens"
    static let daysTrackedKey = "days_tracked"
    // Tracking health. A log line is not enough: if DeviceActivity rejects the
    // event registration, the day records NOTHING and the user would just see a
    // number that never moves and assume the app is broken — or worse, believe
    // it and think they used their phone less. Both states are surfaced on the
    // home screen.
    static let trackingFailedKey = "tracking_failed"        // nothing is being recorded
    static let trackingDegradedKey = "tracking_degraded"    // total works; no per-app nudges
    static let historyKey = "usage_history"
    static let nudgeRecordsKey = "nudge_records"
    // Which copy lines have already been sent today, so a nudge never repeats
    // itself while an unused line exists. Day-scoped by its companion key.
    static let nudgeLinesKey = "nudge_lines_used"
    static let nudgeLinesDateKey = "nudge_lines_date"

    // MARK: - Combined total series
    // There is no "app opened/closed" signal on iOS — the island can only be
    // corrected when a DeviceActivity threshold fires. Per-app thresholds get
    // sparse fast, so a second event series watches ALL tracked apps combined
    // ("total:N") and fires every minute of combined usage. That series is
    // what keeps the island and the home number fresh; per-app events are
    // only for nudges and the per-app breakdown.
    // The actual minute grids live in ThresholdPlan — the spacing is a tuning
    // decision with a cap to dodge, not a constant.
    static let totalEventPrefix = "total"
    static let combinedSecondsKey = "combined_seconds"
    static let combinedSecondsDateKey = "combined_seconds_date"

    // THE ISLAND'S LIFELINE.
    //
    // The Live Activity can only be *pushed* by the main app, and the main app is
    // not running while you scroll — device logs show it going to background two
    // seconds after launch, then ten minutes of usage arriving with nobody able to
    // report it. Every island write in the log came from the app; not one from the
    // extension, which is the only process that knows.
    //
    // So the island PULLS instead. The extension writes the authoritative total
    // here on every threshold, and the Live Activity view — which lives in an
    // extension holding the App Group entitlement — reads it at render time. Any
    // redraw the system performs (waking the phone, expanding the island) then
    // shows the truth instead of a frozen snapshot handed over minutes ago.
    static let liveTotalKey = "live_total_seconds"
    static let liveTotalDateKey = "live_total_date"

    // The island's death is invisible from every process that could mention it,
    // and mentionable from the one process that can't see it. These two keys
    // bridge that: the main app's background runs write the day the island went
    // dark, the monitor extension reads it and captions ONE nudge with the
    // fact, and a foreground revival clears both. See IslandStatus.
    static let islandDownDayKey = "island_down_day"
    static let islandDownAnnouncedDayKey = "island_down_announced_day"

    // MARK: - Day boundary
    //
    // Nothing we control runs at midnight. The monitor extension's
    // intervalDidEnd fires, but it cannot end the activity (ActivityKit is
    // unreachable from that process), and the main app may not run until
    // morning — which is exactly why the island was found still showing
    // yesterday's 3h at 6am.
    //
    // The one thing that DOES happen with no process running is the system's
    // staleDate re-render. So the island's staleDate is pinned to midnight, and
    // the view compares the day baked into the activity's attributes against the
    // day it's being rendered on. If they differ, the day is over and the card
    // reads 0m. That is the whole midnight reset — no background task, no luck.
    static func dayString(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // A small cushion past 00:00 so the re-render can never land on the last
    // instant of the old day and read the stale date as still current.
    static func nextMidnight(after date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
            ?? date.addingTimeInterval(24 * 3600)
        return midnight.addingTimeInterval(30)
    }

    // The receipt measures against waking hours, not the full 24.
    static let awakeDayHours = 16
    static let receiptHour = 21

    // Purchase. `lifetimeUnlockedKey` now means "Pro is unlocked by ANY
    // product" — the key string is unchanged so a beta lifetime purchase made
    // under the old name stays unlocked.
    static let firstLaunchKey = "first_launch_at"
    static let lifetimeUnlockedKey = "lifetime_unlocked"
    static let lifetimeProductID = "com.sanskar.Wasted.lifetime"
    static let monthlyProductID = "com.sanskar.Wasted.pro.monthly"
    static let yearlyProductID = "com.sanskar.Wasted.pro.yearly"
    // The uncapped day-by-day record behind the long receipt (Pro). Written
    // once at midnight, read only when the history screen opens — NEVER on the
    // home screen's five-second tick, which stays on the 7-day rolling window.
    static let archiveKey = "usage_archive"
    static let lastReceiptAutoShowKey = "last_receipt_auto_show"
    // The user's own finished sentence — "i keep meaning to: …" — stored as a
    // JSON [String]. The nudge rotation quotes these back mid-scroll ("you
    // said: play the ukulele."). Never advice: the app only repeats what the
    // user themselves wrote. On-device like everything else.
    static let intentionsKey = "intentions"
    static let dailyGuessKey = "daily_guess_seconds"
    static let realityCheckShownKey = "reality_check_shown"

    static func appIconKey(for appName: String) -> String {
        "app_icon_\(appName)"
    }

    // The ONE duration format, everywhere: "47m", "1h 23m", "2h".
    //
    // There used to be a second one, formattedClock, which rendered the island
    // and lock screen as "1:23". On a Lock Screen that sits directly beneath the
    // system clock reading 20:48, "1:23" does not read as a duration — it reads
    // as a time of day. A colon between two numbers means o'clock to everyone
    // who has ever looked at a phone, and no amount of context beats that.
    //
    // A bare "1h 0m" is also gone: nobody says "one hour zero minutes".
    static func formattedDuration(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }
}

extension UserDefaults {
    // The shared App Group suite, or a survivable substitute.
    //
    // Lives here, not in UsageStore: EventLog needs it and EventLog now runs in
    // LiveActivityExt too, which does not compile UsageStore. AppGroupKeys is the
    // one file every target shares.
    //
    // This used to be `UserDefaults(suiteName:)!` inline in UsageStore's default
    // argument. If the App Group entitlement isn't provisioned — a real state,
    // and exactly the one a signing hiccup produces — that suite is nil and the
    // force-unwrap CRASHES. And it crashes at `UsageStore()` init, which the main
    // app, the DeviceActivityMonitor extension, the widget, and the background
    // tasks all perform, so whichever process touches it first simply dies.
    //
    // A provisioning problem should degrade the app, not execute it. Falling back
    // to .standard means the app runs and stays usable; the cost is that nothing
    // is shared between processes, so the extension's usage never reaches the UI.
    // That is a bad day. It is not a crash loop, and the log says exactly which
    // one it is.
    static let wastedShared: UserDefaults = {
        if let shared = UserDefaults(suiteName: AppGroupKeys.appGroupID) {
            return shared
        }
        EventLog.error(
            .app,
            "App Group '\(AppGroupKeys.appGroupID)' UNREACHABLE — falling back to local defaults. "
            + "Usage will NOT be shared between the app, the extension and the widget. "
            + "Check the App Group entitlement and provisioning profile."
        )
        return .standard
    }()
}
