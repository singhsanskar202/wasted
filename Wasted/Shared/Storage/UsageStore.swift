import Foundation

final class UsageStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: AppGroupKeys.appGroupID)!) {
        self.defaults = defaults
    }

    // MARK: - Today

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

    func totalSecondsAllApps() -> Int {
        loadTodayUsage().seconds.values.reduce(0, +)
    }

    // MARK: - Hourly (DailyUsage.hourly[] slot)

    func addHourlySeconds(_ value: Int) {
        let hour = Calendar.current.component(.hour, from: Date())
        var usage = loadTodayUsage()
        usage.addHourly(value, hour: hour)
        save(usage)
    }

    // MARK: - History (last 7 days, excluding today)

    func archiveToHistory(_ usage: DailyUsage) {
        var history = loadHistory()
        history.removeAll { $0.date == usage.date }
        history.append(usage)
        if history.count > 7 {
            history = Array(history.sorted { $0.date < $1.date }.suffix(7))
        }
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: AppGroupKeys.historyKey)
    }

    func loadHistory() -> [DailyUsage] {
        guard
            let data = defaults.data(forKey: AppGroupKeys.historyKey),
            let history = try? JSONDecoder().decode([DailyUsage].self, from: data)
        else { return [] }
        return history.sorted { $0.date < $1.date }
    }

    func loadYesterday() -> DailyUsage? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())
            .map { DailyUsage.dateString(from: $0) } ?? ""
        return loadHistory().first { $0.date == yesterday }
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
}
