import Foundation

final class UsageStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: AppGroupKeys.appGroupID)!) {
        self.defaults = defaults
    }

    // MARK: - Daily Usage

    func loadTodayUsage() -> DailyUsage {
        let today = DailyUsage.todayString()
        guard
            let data = defaults.data(forKey: AppGroupKeys.dailyUsageKey),
            let usage = try? JSONDecoder().decode(DailyUsage.self, from: data),
            usage.date == today
        else {
            return DailyUsage(date: today)
        }
        return usage
    }

    func save(_ usage: DailyUsage) {
        guard let data = try? JSONEncoder().encode(usage) else { return }
        defaults.set(data, forKey: AppGroupKeys.dailyUsageKey)
    }

    func addSeconds(_ value: Int, for bundleId: String) {
        var usage = loadTodayUsage()
        usage.add(seconds: value, for: bundleId)
        save(usage)
    }

    // MARK: - Active Session

    func setActiveApp(bundleId: String, sessionStart: Date) {
        defaults.set(bundleId, forKey: AppGroupKeys.activeAppBundleIdKey)
        defaults.set(sessionStart.timeIntervalSince1970, forKey: AppGroupKeys.activeSessionStartKey)
    }

    func clearActiveApp() {
        defaults.removeObject(forKey: AppGroupKeys.activeAppBundleIdKey)
        defaults.removeObject(forKey: AppGroupKeys.activeSessionStartKey)
    }

    func activeAppBundleId() -> String? {
        defaults.string(forKey: AppGroupKeys.activeAppBundleIdKey)
    }

    func activeSessionStart() -> Date? {
        let ti = defaults.double(forKey: AppGroupKeys.activeSessionStartKey)
        guard ti > 0 else { return nil }
        return Date(timeIntervalSince1970: ti)
    }

    func totalSecondsAllApps() -> Int {
        loadTodayUsage().seconds.values.reduce(0, +)
    }
}
