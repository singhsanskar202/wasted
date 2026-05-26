import Foundation

struct DailyUsage: Codable, Equatable {
    let date: String
    var seconds: [String: Int]

    init(date: String = DailyUsage.todayString()) {
        self.date = date
        self.seconds = [:]
    }

    static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    mutating func add(seconds value: Int, for bundleId: String) {
        seconds[bundleId, default: 0] += value
    }

    func totalSeconds(for bundleId: String) -> Int {
        seconds[bundleId, default: 0]
    }
}
