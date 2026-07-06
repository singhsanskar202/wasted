import XCTest
@testable import Wasted

final class HistoricalPeakTests: XCTestCase {

    private func day(_ date: String, hours: [Int: Int]) -> DailyUsage {
        var u = DailyUsage(date: date)
        for (hour, seconds) in hours { u.addHourly(seconds, hour: hour) }
        return u
    }

    func test_returnsNilUnderThreeDaysOfHistory() {
        let history = [
            day("2026-07-04", hours: [21: 3600]),
            day("2026-07-05", hours: [21: 3600]),
        ]
        XCTAssertNil(InsightEngine.historicalPeak(history: history))
    }

    func test_returnsNilWhenHistoryHasNoUsage() {
        let history = (1...4).map { day("2026-07-0\($0)", hours: [:]) }
        XCTAssertNil(InsightEngine.historicalPeak(history: history))
    }

    func test_findsConsistentEveningWindow() {
        // Heavy 21:00–23:00 usage on most days
        let history = [
            day("2026-07-01", hours: [21: 3600, 22: 1800]),
            day("2026-07-02", hours: [21: 1800, 22: 3600, 9: 600]),
            day("2026-07-03", hours: [10: 900]),
            day("2026-07-04", hours: [21: 2700, 22: 2700]),
        ]
        let peak = InsightEngine.historicalPeak(history: history)
        XCTAssertEqual(peak?.startHour, 21)
        XCTAssertEqual(peak?.endHour, 23)
        XCTAssertEqual(peak?.daysActive, 3)
        XCTAssertEqual(peak?.daysTotal, 4)
    }

    func test_windowSpansTwoAdjacentHours() {
        // 8:00 has the single biggest hour, but 14:00+15:00 together are bigger
        let history = [
            day("2026-07-01", hours: [8: 3000, 14: 2000, 15: 2000]),
            day("2026-07-02", hours: [8: 3000, 14: 2000, 15: 2000]),
            day("2026-07-03", hours: [14: 500, 15: 500]),
        ]
        let peak = InsightEngine.historicalPeak(history: history)
        XCTAssertEqual(peak?.startHour, 14)
        XCTAssertEqual(peak?.endHour, 16)
        XCTAssertEqual(peak?.daysActive, 3)
    }

    func test_daysActive_countsOnlyDaysWithUsageInWindow() {
        let history = [
            day("2026-07-01", hours: [20: 7200]),
            day("2026-07-02", hours: [3: 60]),
            day("2026-07-03", hours: [20: 7200]),
        ]
        let peak = InsightEngine.historicalPeak(history: history)
        XCTAssertEqual(peak?.daysActive, 2)
        XCTAssertEqual(peak?.daysTotal, 3)
    }
}
