import Foundation

extension UsageStore {
    func loadTodayHourly() -> HourlyUsage {
        let today = DailyUsage.todayString()
        let key = AppGroupKeys.hourlyUsageKey(for: today)
        guard
            let data = defaults.data(forKey: key),
            let usage = try? JSONDecoder().decode(HourlyUsage.self, from: data),
            usage.date == today
        else {
            return HourlyUsage(date: today)
        }
        return usage
    }

    func addSeconds(_ seconds: Int, toHour hour: Int) {
        var usage = loadTodayHourly()
        usage.add(seconds: seconds, toHour: hour)
        saveHourly(usage)
    }

    private func saveHourly(_ usage: HourlyUsage) {
        guard let data = try? JSONEncoder().encode(usage) else { return }
        let key = AppGroupKeys.hourlyUsageKey(for: usage.date)
        defaults.set(data, forKey: key)
    }
}
