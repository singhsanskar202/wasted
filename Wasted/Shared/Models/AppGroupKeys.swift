import Foundation

enum AppGroupKeys {
    static let appGroupID = "group.com.sanskar.Wasted"
    static let dailyUsageKey = "daily_usage"
    static let trackedSelectionKey = "tracked_selection"
    static let activeAppBundleIdKey = "active_app_bundle_id"
    static let activeSessionStartKey = "active_session_start"
    static let hourlyUsageKeyPrefix = "hourly_usage_"
    static let displayNamesKey = "display_names"
    static let daysTrackedKey = "days_tracked"
    static let historyKey = "usage_history"

    static func hourlyUsageKey(for date: String) -> String {
        "\(hourlyUsageKeyPrefix)\(date)"
    }

    static func appIconKey(for appName: String) -> String {
        "app_icon_\(appName)"
    }

    static func formattedTime(from accumulatedStart: Date) -> (text: String, isAtLeast1Hour: Bool) {
        let seconds = max(0, Int(Date().timeIntervalSince(accumulatedStart)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return ("\(h)h \(m)m", true) }
        return ("\(m)m", false)
    }
}
