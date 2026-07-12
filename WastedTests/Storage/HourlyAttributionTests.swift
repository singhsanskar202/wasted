import XCTest
@testable import Wasted

// P1 from the audit: the heatmap was told the wrong hour.
//
// addHourlySeconds used to stamp every delivered second into the hour of
// DELIVERY — `Calendar.component(.hour, from: Date())`. With the extension's
// measured 5–8 minute delivery lag, usage from 11:55 to 12:07 arriving at 12:09
// landed entirely in hour 12 and none in hour 11. Danger zones exist to answer
// "WHEN do you lose time", and they were being answered with the wrong hour.
final class HourlyAttributionTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            timeZone: TimeZone(identifier: "UTC"),
            year: 2026, month: 7, day: 12,
            hour: hour, minute: minute, second: second
        ))!
    }

    private func split(_ seconds: Int, endingAt end: Date) -> [Int: Int] {
        UsageStore.hourlySplit(seconds: seconds, endingAt: end, calendar: calendar)
    }

    func test_usageInsideOneHour_staysInThatHour() {
        let result = split(5 * 60, endingAt: date(14, 30))
        XCTAssertEqual(result, [14: 300])
    }

    // THE REPORTED CASE. 12 minutes of usage delivered at 12:09 spans 11:57→12:09,
    // so 3 minutes belong to hour 11 and 9 to hour 12. The old code put all 12
    // into hour 12.
    func test_usageSpanningAnHourBoundary_isSplitAcrossBothHours() {
        let result = split(12 * 60, endingAt: date(12, 9))
        XCTAssertEqual(result[11], 3 * 60, "hour 11 lost its usage to delivery lag")
        XCTAssertEqual(result[12], 9 * 60)
        XCTAssertEqual(result.values.reduce(0, +), 12 * 60, "seconds went missing")
    }

    func test_usageSpanningSeveralHours_isSplitAcrossAllOfThem() {
        // 100 minutes ending 13:20 → 13:20 back to 11:40.
        let result = split(100 * 60, endingAt: date(13, 20))
        XCTAssertEqual(result[11], 20 * 60)   // 11:40–12:00
        XCTAssertEqual(result[12], 60 * 60)   // the whole hour
        XCTAssertEqual(result[13], 20 * 60)   // 13:00–13:20
        XCTAssertEqual(result.values.reduce(0, +), 100 * 60)
    }

    func test_exactlyOnAnHourBoundary_doesNotLeakIntoTheNextHour() {
        let result = split(30 * 60, endingAt: date(15, 0))
        XCTAssertEqual(result, [14: 30 * 60], "usage ending at 15:00 happened in hour 14")
        XCTAssertNil(result[15])
    }

    // Yesterday's hours belong to yesterday's record, which is already archived —
    // so a window that would reach back past midnight is clipped. But the seconds
    // must not vanish: the heatmap has to keep summing to the day's real total.
    func test_windowClippedAtMidnight_keepsTheSecondsInHourZero() {
        let result = split(60 * 60, endingAt: date(0, 20))
        XCTAssertEqual(result.values.reduce(0, +), 60 * 60, "minutes were lost at midnight")
        XCTAssertEqual(result[0], 60 * 60)
        XCTAssertNil(result[23], "must not write into yesterday's hour")
    }

    func test_zeroOrNegative_isANoOp() {
        XCTAssertTrue(split(0, endingAt: date(10, 0)).isEmpty)
        XCTAssertTrue(split(-60, endingAt: date(10, 0)).isEmpty)
    }

    // The total was never affected by this bug — only the attribution. Guard that
    // the fix didn't change the sum.
    func test_theSumIsAlwaysTheSecondsGivenIn() {
        for minutes in stride(from: 1, through: 240, by: 7) {
            for hour in [0, 1, 9, 12, 23] {
                let result = split(minutes * 60, endingAt: date(hour, 37))
                XCTAssertEqual(
                    result.values.reduce(0, +), minutes * 60,
                    "sum drifted at \(minutes)m ending hour \(hour)"
                )
            }
        }
    }
}
