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

    // How long the island's number reads as current. Only the main app can
    // refresh it (the monitor extension can't reach ActivityKit), so the total
    // is always exact-but-possibly-behind. Past this, the view dims — it is
    // saying "this is a real number, and it is old", never "this is wrong".
    static let confirmedFreshSeconds = 900

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

    // The island's format. Bare minutes under an hour ("47m"), h:mm past it
    // ("2:50") — raw minutes past the hour ("170m") makes the reader do the
    // division, and the compact island slot has no room for "2h 50m".
    static func formattedClock(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        guard minutes >= 60 else { return "\(minutes)m" }
        return "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
    }
}
