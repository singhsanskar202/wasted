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
    static let historyKey = "usage_history"
    static let nudgeRecordsKey = "nudge_records"

    // MARK: - Combined total series
    // There is no "app opened/closed" signal on iOS — the island can only be
    // corrected when a DeviceActivity threshold fires. Per-app thresholds get
    // sparse fast, so a second event series watches ALL tracked apps combined
    // ("total:N") and fires every minute of combined usage. That series is
    // what keeps the island and the home number fresh; per-app events are
    // only for nudges and the per-app breakdown.
    static let totalEventPrefix = "total"
    static let combinedSecondsKey = "combined_seconds"
    static let combinedSecondsDateKey = "combined_seconds_date"

    // 1-min fidelity through 2h, 2-min to 4h, 5-min to 8h. The taper keeps the
    // whole registration (this + per-app events) under DeviceActivity's
    // undocumented event cap. 228 events.
    static let totalThresholdMinutes: [Int] =
        Array(1...120) +
        Array(stride(from: 122, through: 240, by: 2)) +
        Array(stride(from: 245, through: 480, by: 5))

    // Staleness window for the island's number: while the user is inside a
    // tracked app the next "total:N" event should land within one threshold
    // gap plus a reporting margin. No event by then means they left the
    // tracked apps — the (still exact) number dims to read as "not counting
    // right now".
    static let reportingMarginSeconds = 90
    static let fallbackStaleSeconds = 600

    static func staleSeconds(afterTotalSeconds total: Int) -> Int {
        let minutes = total / 60
        guard let next = totalThresholdMinutes.first(where: { $0 > minutes }) else {
            return fallbackStaleSeconds
        }
        return min(next * 60 - total + reportingMarginSeconds, fallbackStaleSeconds)
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

    static func formattedDuration(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    static func formattedTime(from accumulatedStart: Date) -> (text: String, isAtLeast1Hour: Bool) {
        let seconds = max(0, Int(Date().timeIntervalSince(accumulatedStart)))
        return (formattedDuration(seconds), seconds >= 3600)
    }
}
