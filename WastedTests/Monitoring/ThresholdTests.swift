import XCTest
@testable import Wasted

final class ThresholdTests: XCTestCase {

    func test_thresholdMinutes_isStrictlyAscending() {
        let thresholds = ActivityScheduler.thresholdMinutes
        for i in 1..<thresholds.count {
            XCTAssertGreaterThan(thresholds[i], thresholds[i - 1])
        }
    }

    func test_thresholdMinutes_everyNudgeMultipleIsPresent() {
        let thresholds = Set(ActivityScheduler.thresholdMinutes)
        for minutes in stride(from: 30, through: 480, by: 30) {
            XCTAssertTrue(thresholds.contains(minutes), "missing 30-min multiple: \(minutes)")
        }
    }

    func test_thresholdMinutes_count() {
        // 1...5 by 1 (5) + 10...120 by 5 (23) + 130...240 by 10 (12) + 255...480 by 15 (16)
        XCTAssertEqual(ActivityScheduler.thresholdMinutes.count, 56)
    }

    func test_thresholdMinutes_bounds() {
        XCTAssertEqual(ActivityScheduler.thresholdMinutes.first, 1)
        XCTAssertEqual(ActivityScheduler.thresholdMinutes.last, 480)
    }

    // MARK: - Combined total series

    func test_totalThresholds_isStrictlyAscending() {
        let thresholds = AppGroupKeys.totalThresholdMinutes
        for i in 1..<thresholds.count {
            XCTAssertGreaterThan(thresholds[i], thresholds[i - 1])
        }
    }

    func test_totalThresholds_minuteFidelityForFirstTwoHours() {
        let thresholds = AppGroupKeys.totalThresholdMinutes
        XCTAssertEqual(Array(thresholds.prefix(120)), Array(1...120))
    }

    func test_totalThresholds_boundsAndBudget() {
        let thresholds = AppGroupKeys.totalThresholdMinutes
        XCTAssertEqual(thresholds.first, 1)
        XCTAssertEqual(thresholds.last, 480)
        // 1...120 (120) + 122...240 by 2 (60) + 245...480 by 5 (48).
        // Keep the whole registration well under DeviceActivity's
        // undocumented event cap even with several tracked apps.
        XCTAssertEqual(thresholds.count, 228)
    }

    // MARK: - Island clock format

    func test_formattedClock_underAnHour_isBareMinutes() {
        XCTAssertEqual(AppGroupKeys.formattedClock(0), "0m")
        XCTAssertEqual(AppGroupKeys.formattedClock(47 * 60), "47m")
        XCTAssertEqual(AppGroupKeys.formattedClock(59 * 60 + 59), "59m")
    }

    func test_formattedClock_pastAnHour_isHoursAndPaddedMinutes() {
        XCTAssertEqual(AppGroupKeys.formattedClock(3600), "1:00")
        // The number that started all this: 170 minutes must read 2:50, not 170m.
        XCTAssertEqual(AppGroupKeys.formattedClock(170 * 60), "2:50")
        // Single-digit minutes must stay zero-padded, or "2:5" reads as 2.5 hours.
        XCTAssertEqual(AppGroupKeys.formattedClock(125 * 60), "2:05")
    }

    func test_formattedClock_floorsPartialMinutes_neverOverstates() {
        // The island's promise is a true lower bound — round down, never up.
        XCTAssertEqual(AppGroupKeys.formattedClock(119), "1m")
    }
}
