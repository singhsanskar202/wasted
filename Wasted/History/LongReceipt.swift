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
    /// `now` exists so month labels ("july" vs "july 2025") are testable.
    static func build(days: [DailyUsage], now: Date = Date()) -> LongReceipt? {
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
                .map { MonthEntry(id: $0.key, label: Self.monthLabel($0.key, now: now), seconds: $0.value.seconds, daysCounted: $0.value.days) }
        )
    }

    // MARK: - Labels
    //
    // All lowercase — the mirror's register. And RELATABLE: "jul 18" makes the
    // user do calendar arithmetic to find their own life in it. Sanskar's
    // rule, stated plainly: everything on screen must be in the user's terms.
    // A date is named the way the user would name it — "yesterday",
    // "thursday" — and only falls back to the calendar when memory would.

    /// "july" this year, "july 2025" once the year matters.
    static func monthLabel(_ id: String, now: Date = Date()) -> String {
        guard let date = parse(id + "-01") else { return id }
        let calendar = Calendar.current
        let f = DateFormatter()
        f.dateFormat = calendar.component(.year, from: date) == calendar.component(.year, from: now)
            ? "MMMM" : "MMMM yyyy"
        return f.string(from: date).lowercased()
    }

    /// "today" → "yesterday" → "thursday" (this week) → "12 days ago" (this
    /// month) → "in june" (this year) → "june 2025". The tiers mirror how
    /// memory actually degrades: weekday while the week is still vivid, a
    /// distance while the month is, a month name after that.
    static func relatableDay(_ dateString: String, now: Date = Date()) -> String {
        guard let date = parse(dateString) else { return dateString }
        let calendar = Calendar.current
        let daysAgo = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0

        if daysAgo <= 0 { return "today" }
        if daysAgo == 1 { return "yesterday" }
        if daysAgo <= 6 {
            let f = DateFormatter()
            f.dateFormat = "EEEE"
            return f.string(from: date).lowercased()
        }
        if daysAgo <= 30 { return "\(daysAgo) days ago" }
        let f = DateFormatter()
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            f.dateFormat = "MMMM"
            return "in \(f.string(from: date).lowercased())"
        }
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date).lowercased()
    }

    /// The hero's caption: the span as lived time, not a start date. "since
    /// jul 12" asks the user to subtract; "in the last 8 days" already did.
    static func spanCaption(days: Int) -> String {
        if days <= 1 { return "so far today" }
        if days <= 31 { return "in the last \(days) days" }
        let months = max(2, Int((Double(days) / 30.4).rounded()))
        return "in about \(months) months"
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
