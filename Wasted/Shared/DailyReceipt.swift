import Foundation

// The end-of-day receipt: itemized time per tracked app, a total, and the
// share of the user's waking day (16h) it consumed.
struct DailyReceipt: Equatable {
    struct Item: Equatable {
        let name: String
        let seconds: Int
    }

    let dateString: String
    let items: [Item]          // sorted by seconds, largest first
    let totalSeconds: Int
    let percentOfAwakeDay: Int

    var summaryLine: String {
        "\(AppGroupKeys.formattedDuration(totalSeconds)) today — \(percentOfAwakeDay)% of your waking hours."
    }

    static func build(usage: DailyUsage, displayNames: [String: String]) -> DailyReceipt {
        var items: [Item] = []
        for (appIndex, seconds) in usage.seconds where seconds > 0 {
            let name = displayNames[appIndex] ?? "app \(appIndex)"
            items.append(Item(name: name, seconds: seconds))
        }
        items.sort { lhs, rhs in
            if lhs.seconds == rhs.seconds { return lhs.name < rhs.name }
            return lhs.seconds > rhs.seconds
        }

        let total = items.reduce(0) { $0 + $1.seconds }
        let awakeSeconds = AppGroupKeys.awakeDayHours * 3600
        let percent = Int((Double(total) / Double(awakeSeconds) * 100).rounded())

        return DailyReceipt(
            dateString: usage.date,
            items: items,
            totalSeconds: total,
            percentOfAwakeDay: percent
        )
    }
}
