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
}
