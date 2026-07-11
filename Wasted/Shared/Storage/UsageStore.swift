import Foundation

final class UsageStore {
    let defaults: UserDefaults

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

    // Headline total = whichever source is further ahead: the combined series
    // updates every minute but a "total:N" event can be delivered late, while
    // the per-app sum is coarse but independent. max() means neither lag can
    // make the number go backwards.
    func totalSecondsAllApps() -> Int {
        max(loadTodayUsage().seconds.values.reduce(0, +), combinedSecondsToday())
    }

    // MARK: - Combined total (all tracked apps)

    // Written only by the extension's "total:N" threshold events. Day-scoped
    // via a companion date key, so a stale value never leaks into a new day.
    func combinedSecondsToday() -> Int {
        guard defaults.string(forKey: AppGroupKeys.combinedSecondsDateKey) == DailyUsage.todayString() else {
            return 0
        }
        return defaults.integer(forKey: AppGroupKeys.combinedSecondsKey)
    }

    func setCombinedSecondsToday(_ seconds: Int) {
        defaults.set(seconds, forKey: AppGroupKeys.combinedSecondsKey)
        defaults.set(DailyUsage.todayString(), forKey: AppGroupKeys.combinedSecondsDateKey)
    }

    // MARK: - Hourly

    func loadTodayHourly() -> HourlyUsage {
        let usage = loadTodayUsage()
        var hourly = HourlyUsage(date: usage.date)
        for (hour, seconds) in usage.hourly.enumerated() where seconds > 0 {
            hourly.add(seconds: seconds, toHour: hour)
        }
        return hourly
    }

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

    // MARK: - Nudges

    func lastNudge(for appIndex: String) -> NudgeRecord? {
        loadNudgeRecords()[appIndex]
    }

    func recordNudge(minutes: Int, for appIndex: String, at date: Date = Date()) {
        var records = loadNudgeRecords()
        records[appIndex] = NudgeRecord(
            date: DailyUsage.todayString(),
            minutes: minutes,
            firedAt: date
        )
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: AppGroupKeys.nudgeRecordsKey)
    }

    private func loadNudgeRecords() -> [String: NudgeRecord] {
        guard
            let data = defaults.data(forKey: AppGroupKeys.nudgeRecordsKey),
            let records = try? JSONDecoder().decode([String: NudgeRecord].self, from: data)
        else { return [:] }
        return records
    }

    // MARK: - Trial + purchase

    func firstLaunchDate() -> Date? {
        let ti = defaults.double(forKey: AppGroupKeys.firstLaunchKey)
        guard ti > 0 else { return nil }
        return Date(timeIntervalSince1970: ti)
    }

    func stampFirstLaunchIfNeeded(now: Date = Date()) {
        guard firstLaunchDate() == nil else { return }
        defaults.set(now.timeIntervalSince1970, forKey: AppGroupKeys.firstLaunchKey)
    }

    func isUnlocked() -> Bool {
        defaults.bool(forKey: AppGroupKeys.lifetimeUnlockedKey)
    }

    func setUnlocked(_ unlocked: Bool) {
        defaults.set(unlocked, forKey: AppGroupKeys.lifetimeUnlockedKey)
    }

    // MARK: - Reality check

    func guessSeconds() -> Int? {
        let value = defaults.integer(forKey: AppGroupKeys.dailyGuessKey)
        return value > 0 ? value : nil
    }

    func isRealityCheckShown() -> Bool {
        defaults.bool(forKey: AppGroupKeys.realityCheckShownKey)
    }

    func setRealityCheckShown(_ shown: Bool) {
        defaults.set(shown, forKey: AppGroupKeys.realityCheckShownKey)
    }

    // MARK: - Receipt auto-show

    func lastReceiptAutoShowDate() -> String? {
        defaults.string(forKey: AppGroupKeys.lastReceiptAutoShowKey)
    }

    func markReceiptAutoShown(date: String = DailyUsage.todayString()) {
        defaults.set(date, forKey: AppGroupKeys.lastReceiptAutoShowKey)
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
