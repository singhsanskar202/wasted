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
    /// Total seconds spent inside the window across the whole history — what
    /// the habit bell divides by daysActive to say "about 41m a time".
    let windowSeconds: Int

    /// "9pm–11pm" — the window's real span. NOT timeRangeLabel, whose
    /// last-included-hour convention would print this window as "9pm–10pm".
    var label: String {
        "\(InsightEngine.hourLabel(startHour))–\(InsightEngine.hourLabel(endHour % 24))"
    }
}

struct InsightResult {
    enum Tone { case positive, neutral, warning }

    let zones: [DangerZone]
    let timelineSegments: [DangerZone.Level]  // 24 values for the color strip
    let verdictLine: String
    let tone: Tone
    let weekly: WeeklyInsight?                // nil until 7 days of history
    // Day-level top-app indices (UI resolves real names via Label(token)).
    // We only store per-hour totals, not per-app-per-hour, so apps can't be
    // attributed to individual zones — surface them once for the whole day.
    let topAppIndices: [String]
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
        let zones = buildZones(from: today.hourly)

        // Weekly insight (only when we have ≥7 history entries)
        let weekly = history.count >= 7 ? buildWeekly(history: history) : nil

        // Day-level top apps (per-zone attribution is impossible — see InsightResult)
        let topApps = topAppIndices(appSeconds: today.seconds, limit: 2)

        // Every rule returns the same zones/segments/weekly — only the verdict varies.
        func verdict(_ line: String, tone: InsightResult.Tone) -> InsightResult {
            InsightResult(
                zones: zones,
                timelineSegments: segments,
                verdictLine: line,
                tone: tone,
                weekly: weekly,
                topAppIndices: topApps
            )
        }

        // --- Rule engine (priority order, first match wins) ---
        //
        // VOICE: every line here is a fact, lowercase, and offers no advice. The
        // old copy coached — "Keep going.", "Course-correct now.", "Don't break
        // it.", "Kill the 9pm zone" — and congratulated ("Actual progress.").
        // That is a different product. The product guide is explicit: Wasted
        // "never blocks, never shames, never offers a solution — it just keeps
        // count." A mirror that cheers you on is no longer a mirror.

        // 1. Nothing used yet today
        if totalToday == 0 {
            return verdict("clean so far.", tone: .positive)
        }

        // 2. Big drop vs yesterday (>30%)
        if let yTotal = yesterday.map({ $0.hourly.reduce(0, +) }),
           yTotal > 0,
           Double(totalToday) < Double(yTotal) * (1 - trendThreshold * 2) {
            let pct = Int(round((1 - Double(totalToday) / Double(yTotal)) * 100))
            return verdict("\(pct)% less than yesterday.", tone: .positive)
        }

        // 3. A peak hour from yesterday is untouched today
        let yesterdayPeakHour = yesterday.flatMap { peakHour(in: $0.hourly) }
        if let ph = yesterdayPeakHour, today.hourly[ph] == 0 {
            return verdict("you skipped the \(hourLabel(ph)) habit today.", tone: .positive)
        }

        // 4. Under 1 hour total (< 3600s)
        if totalToday < 3600 {
            return verdict("under an hour today.", tone: .positive)
        }

        // 5. A single window dominates (>50% of total)
        let streak = longestCleanStreak(in: today.hourly)
        if let dominantZone = zones.filter({ $0.level == .danger || $0.level == .moderate })
            .max(by: { $0.seconds < $1.seconds }),
           totalToday > 0,
           Double(dominantZone.seconds) / Double(totalToday) > 0.5 {
            let label = timeRangeLabel(start: dominantZone.startHour, end: dominantZone.endHour)
            return verdict("\(label) is over half of today.", tone: .warning)
        }

        // 6. Several hours you couldn't put it down
        let dangerCount = zones.filter { $0.level == .danger }.count
        if dangerCount >= 3 {
            return verdict("\(dangerCount) hours you couldn't put it down.", tone: .warning)
        }

        // 7. Worse than yesterday (>15%)
        if let yTotal = yesterday.map({ $0.hourly.reduce(0, +) }),
           yTotal > 0,
           Double(totalToday) > Double(yTotal) * (1 + trendThreshold) {
            let pct = Int(round((Double(totalToday) / Double(yTotal) - 1) * 100))
            return verdict("\(pct)% more than yesterday.", tone: .warning)
        }

        // 8. Longest untouched run ≥ 4 hours (only if no warnings fired)
        if streak >= 4 {
            return verdict("\(streak)h untouched so far.", tone: .neutral)
        }

        // 9. Scattered usage, no single hour to blame
        if zones.filter({ $0.level != .clean }).count > 4 {
            return verdict("usage is scattered. no single hour to blame.", tone: .neutral)
        }

        // 10. Default: the biggest window
        if let top = zones.filter({ $0.level != .clean }).max(by: { $0.seconds < $1.seconds }) {
            let label = timeRangeLabel(start: top.startHour, end: top.endHour)
            return verdict("\(label) is your biggest cost today.", tone: .neutral)
        }

        // 11. Fallback
        return verdict("nothing to report yet.", tone: .positive)
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
            daysTotal: history.count,
            windowSeconds: bestTotal
        )
    }

    // MARK: - Weekly

    private static func buildWeekly(history: [DailyUsage]) -> WeeklyInsight {
        let days = Array(history.suffix(7))
        let totals = days.map { $0.hourly.reduce(0, +) }
        let labels = days.map { usage -> String in
            // Parse with en_US_POSIX + Gregorian so it matches how the key was
            // written; otherwise a non-Gregorian device fails to parse and every
            // weekday label collapses to "?".
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.calendar = Calendar(identifier: .gregorian)
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

        // Same rule as the daily verdicts: state it, don't coach it.
        let verdict: String
        switch trend {
        case .improving:
            let pct = Int(round((1 - Double(secondHalf) / Double(firstHalf)) * 100))
            verdict = "down \(pct)% since the start of the week."
        case .worsening:
            let pct = Int(round((Double(secondHalf) / Double(firstHalf) - 1) * 100))
            verdict = "up \(pct)% since the start of the week."
        case .flat:
            verdict = "flat week."
        }

        return WeeklyInsight(totalSeconds: totals, dateLabels: labels, trend: trend, verdictLine: verdict)
    }

    // MARK: - Zone building

    private static func buildZones(from hourly: [Int]) -> [DangerZone] {
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
                zones.append(DangerZone(
                    startHour: i, endHour: j,
                    level: level, seconds: secs
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

    private static func topAppIndices(appSeconds: [String: Int], limit: Int) -> [String] {
        appSeconds.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
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
