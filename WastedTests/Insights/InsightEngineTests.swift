import XCTest
@testable import Wasted

final class InsightEngineTests: XCTestCase {

    // MARK: - Helpers

    private func makeUsage(date: String = "2026-05-30", hourly: [Int]) -> DailyUsage {
        var u = DailyUsage(date: date)
        for (i, v) in hourly.enumerated() {
            u.addHourly(v, hour: i)
        }
        return u
    }

    private func emptyHourly() -> [Int] { Array(repeating: 0, count: 24) }

    // MARK: - Rule 1: nothing used today

    func test_rule1_nothingToday_isPositive() {
        let today = makeUsage(hourly: emptyHourly())
        let result = InsightEngine.analyze(today: today, yesterday: nil, history: [], displayNames: [:])
        XCTAssertEqual(result.tone, .positive)
        XCTAssertTrue(result.verdictLine.lowercased().contains("clean"))
    }

    // MARK: - Rule 2: big drop vs yesterday

    func test_rule2_bigDrop_isPositive() {
        var yHourly = emptyHourly()
        yHourly[20] = 7200   // 2h yesterday evening
        let yesterday = makeUsage(date: "2026-05-29", hourly: yHourly)

        var tHourly = emptyHourly()
        tHourly[20] = 600    // only 10m today — >30% drop
        let today = makeUsage(hourly: tHourly)

        let result = InsightEngine.analyze(today: today, yesterday: yesterday, history: [], displayNames: [:])
        XCTAssertEqual(result.tone, .positive)
        XCTAssertTrue(result.verdictLine.contains("%"))
    }

    // MARK: - Rule 3: yesterday peak is clean today

    func test_rule3_yesterdayPeakNowClean_isPositive() {
        var yHourly = emptyHourly()
        yHourly[21] = 5400   // 1.5h at 9pm yesterday
        let yesterday = makeUsage(date: "2026-05-29", hourly: yHourly)

        var tHourly = emptyHourly()
        tHourly[9] = 900     // used elsewhere today, but NOT at 9pm
        let today = makeUsage(hourly: tHourly)

        let result = InsightEngine.analyze(today: today, yesterday: yesterday, history: [], displayNames: [:])
        XCTAssertEqual(result.tone, .positive)
    }

    // MARK: - Rule 4: under 1 hour total

    func test_rule4_underOneHour_isPositive() {
        var hourly = emptyHourly()
        hourly[10] = 1800    // 30m
        hourly[14] = 1200    // 20m — total 50m < 1h
        let today = makeUsage(hourly: hourly)

        let result = InsightEngine.analyze(today: today, yesterday: nil, history: [], displayNames: [:])
        XCTAssertEqual(result.tone, .positive)
        XCTAssertTrue(result.verdictLine.lowercased().contains("hour"))
    }

    // MARK: - Rule 5: long clean streak

    func test_rule8_longCleanStreak_isNeutral() {
        var hourly = emptyHourly()
        // Small scattered usage — no dominant zone, no big drop vs yesterday, no 3 danger zones
        // But a long clean gap between usages triggers streak rule
        hourly[8]  = 600   // 10m — low, not a zone that dominates
        hourly[22] = 600   // 10m — leaves a 13h clean streak in the middle
        let today = makeUsage(hourly: hourly)

        let result = InsightEngine.analyze(today: today, yesterday: nil, history: [], displayNames: [:])
        // Should hit rule 8 (streak) because neither zone dominates (50% threshold)
        // and total 1200s < 3600s so actually hits rule 4. Use 2x 2400s instead.
        var hourly2 = emptyHourly()
        hourly2[8]  = 2400  // moderate
        hourly2[22] = 2400  // moderate — neither > 50% of 4800 total
        let today2 = makeUsage(hourly: hourly2)
        let result2 = InsightEngine.analyze(today: today2, yesterday: nil, history: [], displayNames: [:])
        XCTAssertEqual(result2.tone, .neutral)
        XCTAssertTrue(result2.verdictLine.lowercased().contains("streak") || result2.verdictLine.contains("h"))
    }

    // MARK: - Rule 6: single zone dominates

    func test_rule6_singleZoneDominates_isWarning() {
        var hourly = emptyHourly()
        // 4h in one block (hours 20-23) out of 4h30 total
        hourly[20] = 3600
        hourly[21] = 3600
        hourly[22] = 1800
        hourly[10] = 1200   // 20m scattered elsewhere
        let today = makeUsage(hourly: hourly)

        let result = InsightEngine.analyze(today: today, yesterday: nil, history: [], displayNames: [:])
        XCTAssertEqual(result.tone, .warning)
        XCTAssertTrue(result.verdictLine.lowercased().contains("half") || result.verdictLine.lowercased().contains("zone"))
    }

    // MARK: - Rule 7: multiple danger zones

    func test_rule7_multipleDangerZones_isWarning() {
        var hourly = emptyHourly()
        hourly[8]  = 4000
        hourly[12] = 4000
        hourly[20] = 4000
        hourly[22] = 4000
        let today = makeUsage(hourly: hourly)

        let result = InsightEngine.analyze(today: today, yesterday: nil, history: [], displayNames: [:])
        XCTAssertEqual(result.tone, .warning)
    }

    // MARK: - Rule 8: slightly worse than yesterday

    func test_rule7_slightlyWorseYesterday_isWarning() {
        // yesterday: 3600s total spread across 4 hours (no single zone dominates)
        var yHourly = emptyHourly()
        yHourly[8]  = 900
        yHourly[12] = 900
        yHourly[16] = 900
        yHourly[20] = 900
        let yesterday = makeUsage(date: "2026-05-29", hourly: yHourly)

        // today: ~4500s spread same way — 25% worse, no single zone > 50%
        var tHourly = emptyHourly()
        tHourly[8]  = 1125
        tHourly[12] = 1125
        tHourly[16] = 1125
        tHourly[20] = 1125
        let today = makeUsage(hourly: tHourly)

        let result = InsightEngine.analyze(today: today, yesterday: yesterday, history: [], displayNames: [:])
        XCTAssertEqual(result.tone, .warning)
        XCTAssertTrue(result.verdictLine.contains("%"))
    }

    // MARK: - Timeline segments

    func test_timelineSegments_count_is24() {
        let today = makeUsage(hourly: emptyHourly())
        let result = InsightEngine.analyze(today: today, yesterday: nil, history: [], displayNames: [:])
        XCTAssertEqual(result.timelineSegments.count, 24)
    }

    func test_timelineSegments_classification() {
        var hourly = emptyHourly()
        hourly[0]  = 0     // clean
        hourly[1]  = 400   // low
        hourly[2]  = 2000  // moderate
        hourly[3]  = 4000  // danger
        let today = makeUsage(hourly: hourly)
        let result = InsightEngine.analyze(today: today, yesterday: nil, history: [], displayNames: [:])

        XCTAssertEqual(result.timelineSegments[0], .clean)
        XCTAssertEqual(result.timelineSegments[1], .low)
        XCTAssertEqual(result.timelineSegments[2], .moderate)
        XCTAssertEqual(result.timelineSegments[3], .danger)
    }

    // MARK: - Weekly insight

    func test_weekly_isNil_with6DaysHistory() {
        let today = makeUsage(hourly: emptyHourly())
        let history = (0..<6).map { makeUsage(date: "2026-05-\(String(format: "%02d", $0 + 20))", hourly: emptyHourly()) }
        let result = InsightEngine.analyze(today: today, yesterday: nil, history: history, displayNames: [:])
        XCTAssertNil(result.weekly)
    }

    func test_weekly_isPresent_with7DaysHistory() {
        let today = makeUsage(hourly: emptyHourly())
        let history = (0..<7).map { makeUsage(date: "2026-05-\(String(format: "%02d", $0 + 20))", hourly: emptyHourly()) }
        let result = InsightEngine.analyze(today: today, yesterday: nil, history: history, displayNames: [:])
        XCTAssertNotNil(result.weekly)
        XCTAssertEqual(result.weekly?.totalSeconds.count, 7)
    }

    func test_weekly_improving_trend() {
        var hourlyHigh = emptyHourly(); hourlyHigh[20] = 7200  // 2h
        var hourlyLow  = emptyHourly(); hourlyLow[20]  = 1800  // 30m

        // first 3 days heavy, last 3 days light → improving
        let history = [
            makeUsage(date: "2026-05-20", hourly: hourlyHigh),
            makeUsage(date: "2026-05-21", hourly: hourlyHigh),
            makeUsage(date: "2026-05-22", hourly: hourlyHigh),
            makeUsage(date: "2026-05-23", hourly: emptyHourly()),
            makeUsage(date: "2026-05-24", hourly: hourlyLow),
            makeUsage(date: "2026-05-25", hourly: hourlyLow),
            makeUsage(date: "2026-05-26", hourly: hourlyLow),
        ]
        let today = makeUsage(hourly: emptyHourly())
        let result = InsightEngine.analyze(today: today, yesterday: nil, history: history, displayNames: [:])
        XCTAssertEqual(result.weekly?.trend, .improving)
    }

    func test_weekly_worsening_trend() {
        var hourlyLow  = emptyHourly(); hourlyLow[20]  = 1800
        var hourlyHigh = emptyHourly(); hourlyHigh[20] = 7200

        let history = [
            makeUsage(date: "2026-05-20", hourly: hourlyLow),
            makeUsage(date: "2026-05-21", hourly: hourlyLow),
            makeUsage(date: "2026-05-22", hourly: hourlyLow),
            makeUsage(date: "2026-05-23", hourly: emptyHourly()),
            makeUsage(date: "2026-05-24", hourly: hourlyHigh),
            makeUsage(date: "2026-05-25", hourly: hourlyHigh),
            makeUsage(date: "2026-05-26", hourly: hourlyHigh),
        ]
        let today = makeUsage(hourly: emptyHourly())
        let result = InsightEngine.analyze(today: today, yesterday: nil, history: history, displayNames: [:])
        XCTAssertEqual(result.weekly?.trend, .worsening)
    }

    // MARK: - Hour label formatting

    func test_hourLabel_midnight() {
        XCTAssertEqual(InsightEngine.hourLabel(0), "12am")
    }

    func test_hourLabel_noon() {
        XCTAssertEqual(InsightEngine.hourLabel(12), "12pm")
    }

    func test_hourLabel_9pm() {
        XCTAssertEqual(InsightEngine.hourLabel(21), "9pm")
    }
}
