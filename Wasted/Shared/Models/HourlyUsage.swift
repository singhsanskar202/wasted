import Foundation

struct HourlyUsage: Codable, Equatable {
    let date: String
    var hours: [Int: Int]  // hour (0-23) → seconds

    init(date: String = DailyUsage.todayString()) {
        self.date = date
        self.hours = [:]
    }

    mutating func add(seconds: Int, toHour hour: Int) {
        hours[hour, default: 0] += seconds
    }

    var peakHour: Int? {
        hours.max(by: { $0.value < $1.value })?.key
    }

    var totalSeconds: Int {
        hours.values.reduce(0, +)
    }
}
