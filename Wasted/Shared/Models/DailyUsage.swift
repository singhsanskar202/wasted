import Foundation

struct DailyUsage: Codable, Equatable {
    let date: String
    var seconds: [String: Int]
    var hourly: [Int]  // 24 slots: total seconds used per hour of the day

    init(date: String = DailyUsage.todayString()) {
        self.date = date
        self.seconds = [:]
        self.hourly = Array(repeating: 0, count: 24)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        seconds = try container.decode([String: Int].self, forKey: .seconds)
        // NORMALIZE to exactly 24. Everything that indexes hourly directly
        // (addHourly, InsightEngine's yesterday-peak lookup) assumes 24 slots;
        // buildZones/historicalPeak defend with `count == 24` but those callers
        // don't, so a stored array of any other length is a latent index crash.
        // Pad or truncate on the way in so the invariant holds everywhere.
        let stored = (try? container.decodeIfPresent([Int].self, forKey: .hourly)) ?? []
        hourly = Self.normalizedHourly(stored)
    }

    /// Exactly 24 slots, always — pad short arrays with zeros, truncate long ones.
    static func normalizedHourly(_ raw: [Int]) -> [Int] {
        guard raw.count != 24 else { return raw }
        var fixed = Array(repeating: 0, count: 24)
        for i in 0..<Swift.min(raw.count, 24) { fixed[i] = raw[i] }
        return fixed
    }

    mutating func add(seconds value: Int, for bundleId: String) {
        seconds[bundleId, default: 0] += value
    }

    mutating func addHourly(_ value: Int, hour: Int) {
        // `hour < hourly.count` as well as `< 24`: defends the direct index even
        // if a runtime value ever slips the 24-slot invariant.
        guard hour >= 0, hour < 24, hour < hourly.count else { return }
        hourly[hour] += value
    }

    func totalSeconds(for bundleId: String) -> Int {
        seconds[bundleId, default: 0]
    }

    static func todayString() -> String {
        dateString(from: Date())
    }

    static func dateString(from date: Date) -> String {
        // en_US_POSIX + Gregorian so "yyyy" is always the Gregorian year in ASCII
        // digits. Without it, a device set to a non-Gregorian calendar (Buddhist,
        // Persian, Japanese-era) or Eastern-Arabic numerals produces day keys that
        // don't match the rest of the app — or the push server's Gregorian `day` —
        // and the whole day/history model, keyed on these strings, silently breaks.
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
