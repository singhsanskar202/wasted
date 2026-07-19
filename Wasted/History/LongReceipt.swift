import Foundation

// THE LONG RECEIPT — what the mirror remembers. The daily mirror answers "what
// did today cost?"; this answers the only bigger question there is: "is this a
// bad evening, or a bad life?" All-time total, the average day, the worst day,
// month by month. It is the app's one Pro surface: the past is the product.
//
// Same laws as everything else here. No advice, no congratulation, and nothing
// invented: every number below is arithmetic on days iOS actually recorded.
struct LongReceipt: Equatable {

    struct MonthEntry: Equatable, Identifiable {
        let id: String        // "2026-07" — sortable, stable
        let label: String     // "july 2026"
        let seconds: Int
        let daysCounted: Int
    }

    let allTimeSeconds: Int
    let daysCounted: Int
    /// Earliest recorded day, "yyyy-MM-dd".
    let sinceDate: String
    let averageDaySeconds: Int
    let worstDaySeconds: Int
    let worstDayDate: String
    /// avg/day × 365. nil until a week of data exists: a projection built on
    /// two days is a guess wearing a number, and the mirror doesn't guess.
    let projectedYearSeconds: Int?
    /// The trajectory: the last 7 recorded days against the 7 before them.
    /// nil until 14 days exist — a "trend" with nothing to compare against is
    /// the same guess the projection rule already bans.
    let lastSevenSeconds: Int?
    let previousSevenSeconds: Int?
    /// Newest month first — the receipt reads backwards from now.
    let months: [MonthEntry]

    static let minDaysForProjection = 7
    static let minDaysForTrend = 14

    /// `days` is every recorded day INCLUDING today (duplicates by date are
    /// collapsed, last one wins — today's live record supersedes any archived
    /// copy). Returns nil when there is literally nothing on file: an empty
    /// long receipt is stated by the view, not faked with zeros.
    static func build(days: [DailyUsage]) -> LongReceipt? {
        // Collapse duplicates, drop empty days from "worst" but not from the
        // average — a day you didn't touch the phone still divides the total,
        // otherwise the average quietly flatters.
        var byDate: [String: Int] = [:]
        for day in days where !day.date.isEmpty {
            byDate[day.date] = day.seconds.values.reduce(0, +)
        }
        guard !byDate.isEmpty, byDate.values.contains(where: { $0 > 0 }) else { return nil }

        let ordered = byDate.sorted { $0.key < $1.key }
        let total = ordered.reduce(0) { $0 + $1.value }
        let count = ordered.count
        let worst = ordered.max { $0.value < $1.value }!

        var monthSeconds: [String: (seconds: Int, days: Int)] = [:]
        for (date, seconds) in ordered {
            let month = String(date.prefix(7))    // "2026-07"
            let entry = monthSeconds[month] ?? (0, 0)
            monthSeconds[month] = (entry.seconds + seconds, entry.days + 1)
        }

        let average = total / count
        let hasTrend = count >= minDaysForTrend
        let lastSeven = ordered.suffix(7).reduce(0) { $0 + $1.value }
        let previousSeven = ordered.dropLast(7).suffix(7).reduce(0) { $0 + $1.value }

        return LongReceipt(
            allTimeSeconds: total,
            daysCounted: count,
            sinceDate: ordered.first!.key,
            averageDaySeconds: average,
            worstDaySeconds: worst.value,
            worstDayDate: worst.key,
            projectedYearSeconds: count >= minDaysForProjection ? average * 365 : nil,
            lastSevenSeconds: hasTrend ? lastSeven : nil,
            previousSevenSeconds: hasTrend ? previousSeven : nil,
            months: monthSeconds
                .sorted { $0.key > $1.key }
                .map { MonthEntry(id: $0.key, label: Self.monthLabel($0.key), seconds: $0.value.seconds, daysCounted: $0.value.days) }
        )
    }

    // MARK: - Labels
    //
    // All lowercase — the mirror's register. Fixed to the user's calendar but a
    // stable format: month names are the one date piece a stranger anywhere
    // already knows the length of.

    static func monthLabel(_ id: String) -> String {
        guard let date = parse(id + "-01") else { return id }
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date).lowercased()
    }

    static func dayLabel(_ dateString: String) -> String {
        guard let date = parse(dateString) else { return dateString }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date).lowercased()
    }

    /// "13d 4h" under the same typographic law as the daily number: the biggest
    /// honest unit leads, junk precision is dropped. Under two days it defers
    /// to the ONE daily duration format.
    static func formattedSpan(_ seconds: Int) -> String {
        let total = max(0, seconds)
        guard total >= 48 * 3600 else { return AppGroupKeys.formattedDuration(total) }
        let days = total / 86400
        let hours = (total % 86400) / 3600
        return hours == 0 ? "\(days)d" : "\(days)d \(hours)h"
    }

    /// The week-on-week statement. Facts in both directions, no colour and no
    /// cheer — a mirror that celebrates a down week is congratulating, which
    /// this product never does. Under 5% the honest word is "flat".
    static func trendLine(lastSeven: Int, previousSeven: Int) -> String {
        guard previousSeven > 0 else {
            return lastSeven > 0 ? "all of it in the last 7 days." : "a quiet fortnight."
        }
        let ratio = Double(lastSeven) / Double(previousSeven)
        if abs(ratio - 1) < 0.05 { return "flat, week on week." }
        let pct = Int((abs(ratio - 1) * 100).rounded())
        return ratio > 1 ? "up \(pct)% on the week before." : "down \(pct)% on the week before."
    }

    /// The closing line. Projections under a year of the 365-day rate are days;
    /// the copy must be true at every value it can appear at, so a rate that
    /// projects under two days states hours instead of "0 days".
    static func projectionLine(projectedYearSeconds: Int) -> String {
        let days = projectedYearSeconds / 86400
        if days >= 2 { return "at this rate: \(days) days a year." }
        let hours = max(1, projectedYearSeconds / 3600)
        return "at this rate: \(hours) hours a year."
    }

    private static func parse(_ dateString: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: dateString)
    }
}
