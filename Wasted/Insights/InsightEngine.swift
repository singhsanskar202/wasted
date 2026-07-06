import Foundation

// MARK: - Public types

struct DangerZone: Identifiable, Equatable {
    enum Level: Equatable {
        case clean, low, moderate, danger
    }
    let id = UUID()
    let startHour: Int     // 0–23
    let endHour: Int       // exclusive, e.g. startHour=21 endHour=23 → "9pm–11pm"
    let level: Level
    let seconds: Int
    let appNames: [String] // top apps in this window
}

struct WeeklyInsight: Equatable {
    let totalSeconds: [Int]       // 7 values, index 0 = oldest
    let dateLabels: [String]      // e.g. ["Mon", "Tue", …]
    let trend: Trend
    let verdictLine: String

    enum Trend: Equatable {
        case improving, worsening, flat
    }
}

struct HistoricalPeak: Equatable {
    let startHour: Int   // start of the costliest 2-hour window
    let endHour: Int     // exclusive
    let daysActive: Int  // history days with usage inside the window
    let daysTotal: Int
}

struct InsightResult {
    enum Tone { case positive, neutral, warning }

    let zones: [DangerZone]
    let timelineSegments: [DangerZone.Level]  // 24 values for the color strip
    let verdictLine: String
    let tone: Tone
    let weekly: WeeklyInsight?                // nil until 7 days of history
}

// MARK: - Engine

enum InsightEngine {

    // Thresholds (seconds per hour) for zone classification
    private static let lowThreshold      = 300   // 5 min
    private static let moderateThreshold = 1800  // 30 min
    private static let dangerThreshold   = 3600  // 1h

    // Minimum % difference to call a trend "improving" or "worsening"
    private static let trendThreshold    = 0.15

    static func analyze(
        today: DailyUsage,
        yesterday: DailyUsage?,
        history: [DailyUsage],       // up to 7 completed days, newest last
        displayNames: [String: String]
    ) -> InsightResult {

        let totalToday = today.hourly.reduce(0, +)

        // Build 24 zone levels
        let segments = today.hourly.map { zoneLevel(seconds: $0) }

        // Merge consecutive same-level segments into DangerZone blocks
        let zones = buildZones(from: today.hourly, displayNames: displayNames, appSeconds: today.seconds)

        // Weekly insight (only when we have ≥7 history entries)
        let weekly = history.count >= 7 ? buildWeekly(history: history) : nil

        // --- Rule engine (priority order, first match wins) ---

        // 1. Nothing used yet today
        if totalToday == 0 {
            return InsightResult(
                zones: zones,
                timelineSegments: segments,
                verdictLine: "Clean so far. Come back tonight.",
                tone: .positive,
                weekly: weekly
            )
        }

        // 2. Positive: huge drop vs yesterday (>30%)
        if let yTotal = yesterday.map({ $0.hourly.reduce(0, +) }),
           yTotal > 0,
           Double(totalToday) < Double(yTotal) * (1 - trendThreshold * 2) {
            let pct = Int(round((1 - Double(totalToday) / Double(yTotal)) * 100))
            return InsightResult(
                zones: zones,
                timelineSegments: segments,
                verdictLine: "\(pct)% less than yesterday. Actual progress.",
                tone: .positive,
                weekly: weekly
            )
        }

        // 3. Positive: a peak zone from yesterday is now clean
        let yesterdayPeakHour = yesterday.flatMap { peakHour(in: $0.hourly) }
        if let ph = yesterdayPeakHour, today.hourly[ph] == 0 {
            return InsightResult(
                zones: zones,
                timelineSegments: segments,
                verdictLine: "You skipped the \(hourLabel(ph)) habit today.",
                tone: .positive,
                weekly: weekly
            )
        }

        // 4. Positive: under 1 hour total (< 3600s)
        if totalToday < 3600 {
            return InsightResult(
                zones: zones,
                timelineSegments: segments,
                verdictLine: "Under an hour total. That's rare.",
                tone: .positive,
                weekly: weekly
            )
        }

        // 5. Warning: single zone dominates (>50% of total)
        let streak = longestCleanStreak(in: today.hourly)
        if let dominantZone = zones.filter({ $0.level == .danger || $0.level == .moderate })
            .max(by: { $0.seconds < $1.seconds }),
           totalToday > 0,
           Double(dominantZone.seconds) / Double(totalToday) > 0.5 {
            let label = timeRangeLabel(start: dominantZone.startHour, end: dominantZone.endHour)
            return InsightResult(
                zones: zones,
                timelineSegments: segments,
                verdictLine: "Kill the \(label) zone and you cut today's waste in half.",
                tone: .warning,
                weekly: weekly
            )
        }

        // 6. Warning: multiple danger zones
        let dangerCount = zones.filter { $0.level == .danger }.count
        if dangerCount >= 3 {
            return InsightResult(
                zones: zones,
                timelineSegments: segments,
                verdictLine: "\(dangerCount) danger zones. No clean run longer than \(streak)h.",
                tone: .warning,
                weekly: weekly
            )
        }

        // 7. Warning: slightly worse than yesterday (>15%)
        if let yTotal = yesterday.map({ $0.hourly.reduce(0, +) }),
           yTotal > 0,
           Double(totalToday) > Double(yTotal) * (1 + trendThreshold) {
            let pct = Int(round((Double(totalToday) / Double(yTotal) - 1) * 100))
            return InsightResult(
                zones: zones,
                timelineSegments: segments,
                verdictLine: "\(pct)% more than yesterday. Trend's going the wrong way.",
                tone: .warning,
                weekly: weekly
            )
        }

        // 8. Positive: longest clean streak ≥ 4 hours (only if no warnings fired)
        if streak >= 4 {
            return InsightResult(
                zones: zones,
                timelineSegments: segments,
                verdictLine: "\(streak)h clean streak so far. Don't break it.",
                tone: .neutral,
                weekly: weekly
            )
        }

        // 9. Neutral: scattered usage, no single actionable zone
        if zones.filter({ $0.level != .clean }).count > 4 {
            return InsightResult(
                zones: zones,
                timelineSegments: segments,
                verdictLine: "Usage is scattered. No single zone to cut — reduce across the board.",
                tone: .neutral,
                weekly: weekly
            )
        }

        // 10. Default: show the biggest zone
        if let top = zones.filter({ $0.level != .clean }).max(by: { $0.seconds < $1.seconds }) {
            let label = timeRangeLabel(start: top.startHour, end: top.endHour)
            return InsightResult(
                zones: zones,
                timelineSegments: segments,
                verdictLine: "\(label) is your biggest cost today.",
                tone: .neutral,
                weekly: weekly
            )
        }

        // 11. Fallback
        return InsightResult(
            zones: zones,
            timelineSegments: segments,
            verdictLine: "Looking fine today.",
            tone: .positive,
            weekly: weekly
        )
    }

    // MARK: - Historical peak

    // The 2-hour window of the day that has cost the most time across the
    // stored history — "when do I consistently waste the most time."
    static func historicalPeak(history: [DailyUsage]) -> HistoricalPeak? {
        guard history.count >= 3 else { return nil }

        var sums = [Int](repeating: 0, count: 24)
        for day in history where day.hourly.count == 24 {
            for hour in 0..<24 { sums[hour] += day.hourly[hour] }
        }
        guard sums.contains(where: { $0 > 0 }) else { return nil }

        var bestStart = 0
        var bestTotal = -1
        for start in 0..<23 {
            let total = sums[start] + sums[start + 1]
            if total > bestTotal {
                bestTotal = total
                bestStart = start
            }
        }

        let daysActive = history.filter {
            $0.hourly.count == 24 && $0.hourly[bestStart] + $0.hourly[bestStart + 1] > 0
        }.count

        return HistoricalPeak(
            startHour: bestStart,
            endHour: bestStart + 2,
            daysActive: daysActive,
            daysTotal: history.count
        )
    }

    // MARK: - Weekly

    private static func buildWeekly(history: [DailyUsage]) -> WeeklyInsight {
        let days = Array(history.suffix(7))
        let totals = days.map { $0.hourly.reduce(0, +) }
        let labels = days.map { usage -> String in
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            guard let date = f.date(from: usage.date) else { return "?" }
            let d = DateFormatter()
            d.dateFormat = "EEE"
            return d.string(from: date)
        }

        // Trend: compare first half vs second half average
        let firstHalf  = totals.prefix(3).reduce(0, +) / 3
        let secondHalf = totals.suffix(3).reduce(0, +) / 3
        let trend: WeeklyInsight.Trend
        if secondHalf == 0 || firstHalf == 0 {
            trend = .flat
        } else {
            let ratio = Double(secondHalf) / Double(firstHalf)
            if ratio < (1 - trendThreshold)      { trend = .improving }
            else if ratio > (1 + trendThreshold) { trend = .worsening }
            else                                  { trend = .flat }
        }

        let verdict: String
        switch trend {
        case .improving:
            let pct = Int(round((1 - Double(secondHalf) / Double(firstHalf)) * 100))
            verdict = "Down \(pct)% vs. earlier this week. Keep going."
        case .worsening:
            let pct = Int(round((Double(secondHalf) / Double(firstHalf) - 1) * 100))
            verdict = "Up \(pct)% vs. earlier this week. Course-correct now."
        case .flat:
            verdict = "Flat week. Pick one zone to cut next week."
        }

        return WeeklyInsight(totalSeconds: totals, dateLabels: labels, trend: trend, verdictLine: verdict)
    }

    // MARK: - Zone building

    private static func buildZones(
        from hourly: [Int],
        displayNames: [String: String],
        appSeconds: [String: Int]
    ) -> [DangerZone] {
        guard hourly.count == 24 else { return [] }

        var zones: [DangerZone] = []
        var i = 0
        while i < 24 {
            let level = zoneLevel(seconds: hourly[i])
            // Merge consecutive hours at the same level
            var j = i + 1
            while j < 24 && zoneLevel(seconds: hourly[j]) == level {
                j += 1
            }
            let secs = hourly[i..<j].reduce(0, +)
            if level != .clean || secs > 0 {
                // Top apps for this window: proportional by their total day usage
                let topApps = topAppNames(in: displayNames, appSeconds: appSeconds, limit: 2)
                zones.append(DangerZone(
                    startHour: i, endHour: j,
                    level: level, seconds: secs,
                    appNames: topApps
                ))
            }
            i = j
        }
        return zones
    }

    private static func zoneLevel(seconds: Int) -> DangerZone.Level {
        switch seconds {
        case 0..<lowThreshold:      return .clean
        case lowThreshold..<moderateThreshold: return .low
        case moderateThreshold..<dangerThreshold: return .moderate
        default:                    return .danger
        }
    }

    // MARK: - Helpers

    private static func topAppNames(in names: [String: String], appSeconds: [String: Int], limit: Int) -> [String] {
        appSeconds.sorted { $0.value > $1.value }
            .prefix(limit)
            .compactMap { names[$0.key] }
    }

    private static func peakHour(in hourly: [Int]) -> Int? {
        guard !hourly.isEmpty else { return nil }
        let maxVal = hourly.max() ?? 0
        guard maxVal > 0 else { return nil }
        return hourly.firstIndex(of: maxVal)
    }

    private static func longestCleanStreak(in hourly: [Int]) -> Int {
        var best = 0
        var current = 0
        for h in hourly {
            if h == 0 { current += 1; best = max(best, current) }
            else { current = 0 }
        }
        return best
    }

    static func timeRangeLabel(start: Int, end: Int) -> String {
        "\(hourLabel(start))–\(hourLabel(end - 1))"
    }

    static func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h)\(hour < 12 ? "am" : "pm")"
    }
}
