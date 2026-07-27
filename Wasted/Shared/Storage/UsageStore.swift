import Foundation

// THE DEDUP THAT STOPS A REPLAY FROM INFLATING THE DAY.
//
// Every DeviceActivity event registers with `includesPastActivity: true` so a
// mid-day re-registration keeps counting the whole day instead of restarting
// from zero. The cost: on re-registration DeviceActivity REPLAYS thresholds,
// and it can replay a CROSS-DAY CUMULATIVE total that is hundreds of minutes
// above today's reality. The old dedup only rejected replays LOWER than the
// stored value (`new > stored`), so these high replays sailed through and
// ratcheted the total to 12h (device logs: a single event jumping +241m).
//
// A real threshold advances a minute at a time (the combined series is
// 1-minute-spaced; even a batch after a gap arrives as separate +1m events).
// So a single event that jumps more than an hour is not real usage — it is a
// replay artifact. Accept only monotonic, physically-plausible steps.
enum ThresholdSanity {
    // Generous: real steps are 1m (combined) or 15m (per-app); replays jump by
    // hundreds. An hour sits far above every legitimate step and far below
    // every observed replay.
    static let maxJumpSeconds = 60 * 60

    static func accept(newTotalSeconds: Int, storedSeconds: Int) -> Bool {
        newTotalSeconds > storedSeconds
            && (newTotalSeconds - storedSeconds) <= maxJumpSeconds
    }
}

final class UsageStore {
    let defaults: UserDefaults

    init(defaults: UserDefaults = .wastedShared) {
        self.defaults = defaults
    }

    // MARK: - Today

    func loadTodayUsage() -> DailyUsage {
        let today = DailyUsage.todayString()
        guard let usage = loadStoredDay(), usage.date == today else {
            return DailyUsage(date: today)
        }
        return usage
    }

    /// The stored day record AS-IS, whatever date it carries.
    ///
    /// `intervalDidEnd` fires at ~00:00:02, when `todayString()` is already the
    /// NEW day — so loadTodayUsage() there returns an empty record and archived
    /// `total=0s`, wiping the day that just ended. (Device log, 2026-07-15: it
    /// archived "2026-07-15 total=0s" and yesterday's 1h55m vanished, which then
    /// made the 8am morning report skip because loadYesterday() found nothing.)
    /// Archiving must read the record that's actually there, not ask for "today".
    func loadStoredDay() -> DailyUsage? {
        guard
            let data = defaults.data(forKey: AppGroupKeys.dailyUsageKey),
            let usage = try? JSONDecoder().decode(DailyUsage.self, from: data)
        else { return nil }
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
        totalSeconds(in: loadTodayUsage())
    }

    /// Same total, from an ALREADY-LOADED day. HomeView refreshes every five
    /// seconds, and every one of these helpers used to re-decode the day's JSON
    /// off disk — on the main thread, mid-scroll. Taking the snapshot as a
    /// parameter is what lets a refresh do one read instead of eight.
    func totalSeconds(in usage: DailyUsage) -> Int {
        max(usage.seconds.values.reduce(0, +), combinedSecondsToday())
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

    // SELF-HEAL AGAINST A CORRUPTED TOTAL.
    //
    // Today's usage can never exceed the wall-clock time elapsed since local
    // midnight — you cannot use the phone for more minutes than have passed. A
    // DeviceActivity replay burst (a cross-day cumulative total replayed on
    // re-registration) once slammed the count to 12h at 7pm; the per-app sum
    // read 48h. Both are impossible. When that's detected, wipe today and let
    // real thresholds rebuild it — a number that resets and re-climbs is far
    // better than one that lies. This CANNOT misfire on legitimate data: real
    // usage is always ≤ elapsed time.
    @discardableResult
    func healImpossibleTotal(now: Date = Date()) -> Bool {
        let elapsed = Int(now.timeIntervalSince(Calendar.current.startOfDay(for: now)))
        guard elapsed > 0 else { return false }
        let perApp = totalSecondsAllApps()
        let combined = combinedSecondsToday()
        guard perApp > elapsed || combined > elapsed else { return false }

        EventLog.error(.monitor, "IMPOSSIBLE total healed — perApp=\(perApp / 60)m combined=\(combined / 60)m > elapsed=\(elapsed / 60)m; today reset (DeviceActivity replay corruption)")
        var usage = loadTodayUsage()
        usage.seconds = [:]
        usage.hourly = Array(repeating: 0, count: 24)
        save(usage)
        setCombinedSecondsToday(0)
        publishLiveTotal()
        return true
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
        hourly(in: loadTodayUsage())
    }

    /// Same, from an already-loaded day — see `totalSeconds(in:)`.
    func hourly(in usage: DailyUsage) -> HourlyUsage {
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

    // Two records on purpose. The rolling 7-day window feeds the home screen,
    // which re-reads it on a five-second tick — it must stay small. The archive
    // is uncapped (a year is ~365 tiny entries) and feeds the long receipt; it
    // is written here, once a day at midnight, and read only when that screen
    // opens.
    func archiveToHistory(_ usage: DailyUsage) {
        var history = loadHistory()
        history.removeAll { $0.date == usage.date }
        history.append(usage)
        if history.count > 7 {
            history = Array(history.sorted { $0.date < $1.date }.suffix(7))
        }
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: AppGroupKeys.historyKey)
        appendToArchive(usage)
    }

    func appendToArchive(_ usage: DailyUsage) {
        var archive = loadArchive()
        // First write on a build that predates the archive: seed it from the
        // rolling window, so an upgrading tester's week isn't lost.
        if archive.isEmpty { archive = loadHistory() }
        archive.removeAll { $0.date == usage.date }
        archive.append(usage)
        archive.sort { $0.date < $1.date }
        guard let data = try? JSONEncoder().encode(archive) else { return }
        defaults.set(data, forKey: AppGroupKeys.archiveKey)
    }

    func loadArchive() -> [DailyUsage] {
        guard
            let data = defaults.data(forKey: AppGroupKeys.archiveKey),
            let archive = try? JSONDecoder().decode([DailyUsage].self, from: data)
        else { return [] }
        return archive
    }

    /// Everything ever recorded, today included — the long receipt's input.
    /// Order matters: LongReceipt collapses duplicate dates last-one-wins, so
    /// the rolling window supersedes the archive and today's live record
    /// supersedes both.
    func loadFullHistory() -> [DailyUsage] {
        // Today comes from ONE source — the live record, appended last. The
        // archive can still hold a partial today from a mid-day stop (see
        // loadHistory); strip today from the past portion so it isn't counted
        // twice, then append the live record as the single source of truth.
        let today = DailyUsage.todayString()
        return (loadArchive() + loadHistory()).filter { $0.date != today } + [loadTodayUsage()]
    }

    func loadHistory() -> [DailyUsage] {
        guard
            let data = defaults.data(forKey: AppGroupKeys.historyKey),
            let history = try? JSONDecoder().decode([DailyUsage].self, from: data)
        else { return [] }
        // History is DEFINED as the days before today (see archiveToHistory).
        // But intervalDidEnd — the only writer — fires on EVERY stopMonitoring,
        // not just at midnight: a mid-day re-registration (schema refresh,
        // selection edit, reviving a dead monitor) archives a partial "today"
        // into this list. HomeView builds its week as history.suffix(6) + [today],
        // so a stray today here would be counted twice. Enforce the contract on
        // read: today never belongs in history — the live record is its home.
        let today = DailyUsage.todayString()
        return history.filter { $0.date != today }.sorted { $0.date < $1.date }
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

    // The user's own "i keep meaning to: …" sentences — the personal nudge
    // lines' source. Order preserved: it's the order they said them in.
    func intentions() -> [String] {
        guard
            let data = defaults.data(forKey: AppGroupKeys.intentionsKey),
            let list = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return list
    }

    func setIntentions(_ list: [String]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        defaults.set(data, forKey: AppGroupKeys.intentionsKey)
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
