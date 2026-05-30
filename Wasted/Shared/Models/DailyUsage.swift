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
        hourly = (try? container.decodeIfPresent([Int].self, forKey: .hourly)) ?? Array(repeating: 0, count: 24)
    }

    mutating func add(seconds value: Int, for bundleId: String) {
        seconds[bundleId, default: 0] += value
    }

    mutating func addHourly(_ value: Int, hour: Int) {
        guard hour >= 0, hour < 24 else { return }
        hourly[hour] += value
    }

    func totalSeconds(for bundleId: String) -> Int {
        seconds[bundleId, default: 0]
    }

    static func todayString() -> String {
        dateString(from: Date())
    }

    static func dateString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
