import Foundation

enum AppGroupKeys {
    static let appGroupID = "group.com.sanskar.Wasted"
    static let dailyUsageKey = "daily_usage"
    static let trackedSelectionKey = "tracked_selection"
    static let activeAppBundleIdKey = "active_app_bundle_id"
    static let activeSessionStartKey = "active_session_start"
    static let displayNamesKey = "display_names"
    // index -> ApplicationToken (JSON) — lets the widget extension render the
    // real app name via Label(token), the only API allowed to resolve it.
    static let appTokensKey = "app_tokens"
    static let daysTrackedKey = "days_tracked"
    static let historyKey = "usage_history"
    static let nudgeRecordsKey = "nudge_records"

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
