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

    // Trial + purchase
    static let firstLaunchKey = "first_launch_at"
    static let lifetimeUnlockedKey = "lifetime_unlocked"
    static let lifetimeProductID = "com.sanskar.Wasted.lifetime"
    static let lastReceiptAutoShowKey = "last_receipt_auto_show"
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
