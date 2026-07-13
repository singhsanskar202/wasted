import Foundation

extension UserDefaults {
    // The shared App Group suite, or a survivable substitute.
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

final class UsageStore {
    let defaults: UserDefaults

    init(defaults: UserDefaults = .wastedShared) {
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

    // MARK: - The island's lifeline

    /// Publish the authoritative total for the Live Activity to READ at render
    /// time. The extension cannot push to ActivityKit — it has never once managed
    /// it — so the island's view pulls this instead of waiting to be handed a
    /// number by an app that isn't running.
    func publishLiveTotal() {
        defaults.set(totalSecondsAllApps(), forKey: AppGroupKeys.liveTotalKey)
        defaults.set(DailyUsage.todayString(), forKey: AppGroupKeys.liveTotalDateKey)
    }

    /// The published total, or nil if it belongs to a day that is over.
    func liveTotalToday() -> Int? {
        guard defaults.string(forKey: AppGroupKeys.liveTotalDateKey) == DailyUsage.todayString() else {
            return nil
        }
        return defaults.integer(forKey: AppGroupKeys.liveTotalKey)
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

    // Usage that crossed a threshold happened in the RUN-UP to the event — not
    // at the instant iOS got around to telling us about it.
    //
    // This used to stamp every delivered second into
    // `Calendar.component(.hour, from: Date())` — the hour of DELIVERY. With the
    // extension's measured 5–8 minute delivery lag, usage from 11:55 to 12:07
    // arriving at 12:09 landed entirely in hour 12 and none in hour 11. The
    // heatmap and the danger zones — the whole point of which is "WHEN do you
    // lose time" — were being told the wrong hour.
    //
    // So walk the seconds backwards from the event and split them across the
    // hours they actually spanned. The headline total was never affected by this;
    // only the hourly attribution was.
    func addHourlySeconds(_ value: Int, endingAt end: Date = Date()) {
        guard value > 0 else { return }
        var usage = loadTodayUsage()
        for (hour, seconds) in Self.hourlySplit(seconds: value, endingAt: end) {
            usage.addHourly(seconds, hour: hour)
        }
        save(usage)
    }

    /// Splits `seconds` of usage ending at `end` across the clock hours it covers.
    /// Pure and calendar-injectable so the boundary cases are actually testable.
    static func hourlySplit(
        seconds: Int,
        endingAt end: Date,
        calendar: Calendar = .current
    ) -> [Int: Int] {
        guard seconds > 0 else { return [:] }

        // Never attribute across midnight: yesterday's hours belong to yesterday's
        // record, which has already been archived.
        let dayStart = calendar.startOfDay(for: end)
        let windowStart = max(end.addingTimeInterval(-Double(seconds)), dayStart)

        var split: [Int: Int] = [:]
        var cursor = windowStart
        while cursor < end {
            guard let hour = calendar.dateInterval(of: .hour, for: cursor) else { break }
            let sliceEnd = min(hour.end, end)
            let slice = Int(sliceEnd.timeIntervalSince(cursor).rounded())
            guard slice > 0 else { break }
            split[calendar.component(.hour, from: cursor), default: 0] += slice
            cursor = sliceEnd
        }

        // If the window was clipped at midnight, pin the remainder to hour 0 so
        // the heatmap still sums to the day's real total rather than quietly
        // losing minutes.
        let attributed = split.values.reduce(0, +)
        if attributed < seconds {
            split[0, default: 0] += seconds - attributed
        }
        return split
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

    // Copy lines already sent today. Day-scoped like combinedSeconds: a stale
    // set would silence today's best lines because yesterday used them.
    func usedNudgeLines() -> Set<Int> {
        guard defaults.string(forKey: AppGroupKeys.nudgeLinesDateKey) == DailyUsage.todayString() else {
            return []
        }
        return Set(defaults.array(forKey: AppGroupKeys.nudgeLinesKey) as? [Int] ?? [])
    }

    func markNudgeLine(_ id: Int) {
        let used = usedNudgeLines().union([id])
        defaults.set(Array(used), forKey: AppGroupKeys.nudgeLinesKey)
        defaults.set(DailyUsage.todayString(), forKey: AppGroupKeys.nudgeLinesDateKey)
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
