import XCTest
@testable import Wasted

final class LongReceiptTests: XCTestCase {

    private func day(_ date: String, seconds: Int) -> DailyUsage {
        var usage = DailyUsage(date: date)
        usage.add(seconds: seconds, for: "0")
        return usage
    }

    func test_nothingOnFile_buildsNothing() {
        XCTAssertNil(LongReceipt.build(days: []))
        // Days that exist but hold zero usage are not a ledger yet either.
        XCTAssertNil(LongReceipt.build(days: [day("2026-07-01", seconds: 0)]))
    }

    func test_totalsAverageAndWorst() {
        let receipt = LongReceipt.build(days: [
            day("2026-07-01", seconds: 3600),
            day("2026-07-02", seconds: 7200),
            day("2026-07-03", seconds: 1800),
        ])!
        XCTAssertEqual(receipt.allTimeSeconds, 12600)
        XCTAssertEqual(receipt.daysCounted, 3)
        XCTAssertEqual(receipt.averageDaySeconds, 4200)
        XCTAssertEqual(receipt.worstDaySeconds, 7200)
        XCTAssertEqual(receipt.worstDayDate, "2026-07-02")
        XCTAssertEqual(receipt.sinceDate, "2026-07-01")
    }

    // Today's live record supersedes any archived copy of the same date — a
    // duplicate must never double the day.
    func test_duplicateDates_collapse_lastOneWins() {
        let receipt = LongReceipt.build(days: [
            day("2026-07-01", seconds: 600),
            day("2026-07-01", seconds: 3600),
        ])!
        XCTAssertEqual(receipt.allTimeSeconds, 3600)
        XCTAssertEqual(receipt.daysCounted, 1)
    }

    // An untouched day still divides the total. An average that skips quiet
    // days flatters, and the mirror doesn't flatter.
    func test_zeroDays_countTowardTheAverage() {
        let receipt = LongReceipt.build(days: [
            day("2026-07-01", seconds: 7200),
            day("2026-07-02", seconds: 0),
        ])!
        XCTAssertEqual(receipt.daysCounted, 2)
        XCTAssertEqual(receipt.averageDaySeconds, 3600)
    }

    func test_monthsGroup_andReadNewestFirst() {
        let receipt = LongReceipt.build(days: [
            day("2026-06-29", seconds: 3600),
            day("2026-06-30", seconds: 3600),
            day("2026-07-01", seconds: 1800),
        ])!
        XCTAssertEqual(receipt.months.map(\.id), ["2026-07", "2026-06"])
        XCTAssertEqual(receipt.months[0].seconds, 1800)
        XCTAssertEqual(receipt.months[1].seconds, 7200)
        XCTAssertEqual(receipt.months[1].daysCounted, 2)
        XCTAssertEqual(receipt.months[1].label, "june 2026")
    }

    // A projection built on two days is a guess wearing a number.
    func test_projectionNeedsAWeekOfData() {
        let sixDays = (1...6).map { day(String(format: "2026-07-%02d", $0), seconds: 3600) }
        XCTAssertNil(LongReceipt.build(days: sixDays)!.projectedYearSeconds)

        let sevenDays = (1...7).map { day(String(format: "2026-07-%02d", $0), seconds: 3600) }
        XCTAssertEqual(LongReceipt.build(days: sevenDays)!.projectedYearSeconds, 3600 * 365)
    }

    // The copy rule: true at every value it can appear at. "0 days a year" is
    // a lie at low rates; the line switches units instead.
    func test_projectionLine_neverSaysZeroDays() {
        XCTAssertEqual(
            LongReceipt.projectionLine(projectedYearSeconds: 46 * 86400),
            "at this rate: 46 days a year."
        )
        XCTAssertEqual(
            LongReceipt.projectionLine(projectedYearSeconds: 90000),   // ~25h
            "at this rate: 25 hours a year."
        )
    }

    // A "trend" with nothing to compare against is a guess wearing a number —
    // same law as the projection.
    func test_trendNeedsFourteenDays() {
        let thirteen = (1...13).map { day(String(format: "2026-07-%02d", $0), seconds: 3600) }
        let short = LongReceipt.build(days: thirteen)!
        XCTAssertNil(short.lastSevenSeconds)
        XCTAssertNil(short.previousSevenSeconds)

        let fourteen = (1...14).map { day(String(format: "2026-07-%02d", $0), seconds: $0 <= 7 ? 3600 : 1800) }
        let full = LongReceipt.build(days: fourteen)!
        XCTAssertEqual(full.previousSevenSeconds, 7 * 3600)
        XCTAssertEqual(full.lastSevenSeconds, 7 * 1800)
    }

    // Facts in both directions, no cheer — and near-equal weeks are "flat",
    // not a fabricated ±2%.
    func test_trendLine_statesBothDirectionsAndFlat() {
        XCTAssertEqual(LongReceipt.trendLine(lastSeven: 5700, previousSeven: 5000), "up 14% on the week before.")
        XCTAssertEqual(LongReceipt.trendLine(lastSeven: 4000, previousSeven: 5000), "down 20% on the week before.")
        XCTAssertEqual(LongReceipt.trendLine(lastSeven: 5100, previousSeven: 5000), "flat, week on week.")
        XCTAssertEqual(LongReceipt.trendLine(lastSeven: 3600, previousSeven: 0), "all of it in the last 7 days.")
    }

    func test_formattedSpan_switchesToDaysPastTwoDays() {
        XCTAssertEqual(LongReceipt.formattedSpan(47 * 3600), "47h")
        XCTAssertEqual(LongReceipt.formattedSpan(50 * 3600), "2d 2h")
        XCTAssertEqual(LongReceipt.formattedSpan(13 * 86400), "13d")
        XCTAssertEqual(LongReceipt.formattedSpan(90 * 60), "1h 30m")
    }
}
