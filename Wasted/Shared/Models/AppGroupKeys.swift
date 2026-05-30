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
}
