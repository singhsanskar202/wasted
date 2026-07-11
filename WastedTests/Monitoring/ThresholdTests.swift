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

    // MARK: - Staleness window

    func test_staleSeconds_coversGapToNextThresholdPlusMargin() {
        // At 5 min the next total threshold is 6 min: 60s away + margin.
        XCTAssertEqual(AppGroupKeys.staleSeconds(afterTotalSeconds: 5 * 60), 60 + AppGroupKeys.reportingMarginSeconds)
        // In the 2-min band (past 2h): 120s gap + margin.
        XCTAssertEqual(AppGroupKeys.staleSeconds(afterTotalSeconds: 122 * 60), 120 + AppGroupKeys.reportingMarginSeconds)
        // In the 5-min band (past 4h): 300s gap + margin.
        XCTAssertEqual(AppGroupKeys.staleSeconds(afterTotalSeconds: 245 * 60), 300 + AppGroupKeys.reportingMarginSeconds)
    }

    func test_staleSeconds_fallsBackPastSeriesEnd() {
        XCTAssertEqual(AppGroupKeys.staleSeconds(afterTotalSeconds: 480 * 60), AppGroupKeys.fallbackStaleSeconds)
    }

    func test_staleSeconds_atZeroUsage_isOneGapPlusMargin() {
        XCTAssertEqual(AppGroupKeys.staleSeconds(afterTotalSeconds: 0), 60 + AppGroupKeys.reportingMarginSeconds)
    }
}
