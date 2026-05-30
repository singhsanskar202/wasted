import XCTest
@testable import Wasted

final class AppGroupKeysTests: XCTestCase {

    func test_appIconKey_returnsExpectedKey() {
        XCTAssertEqual(AppGroupKeys.appIconKey(for: "Instagram"), "app_icon_Instagram")
        XCTAssertEqual(AppGroupKeys.appIconKey(for: "YouTube"), "app_icon_YouTube")
    }

    func test_formattedTime_underOneHour_showsMinutesOnly() {
        let start = Date(timeIntervalSinceNow: -42 * 60)
        let result = AppGroupKeys.formattedTime(from: start)
        XCTAssertEqual(result.text, "42m")
        XCTAssertFalse(result.isOver1Hour)
    }

    func test_formattedTime_exactlyOneHour_showsHoursAndMinutes() {
        let start = Date(timeIntervalSinceNow: -3600)
        let result = AppGroupKeys.formattedTime(from: start)
        XCTAssertEqual(result.text, "1h 0m")
        XCTAssertTrue(result.isOver1Hour)
    }

    func test_formattedTime_over1Hour_showsHoursAndMinutes() {
        let start = Date(timeIntervalSinceNow: -5040)
        let result = AppGroupKeys.formattedTime(from: start)
        XCTAssertEqual(result.text, "1h 24m")
        XCTAssertTrue(result.isOver1Hour)
    }

    func test_formattedTime_zeroSeconds_showsZeroMinutes() {
        let start = Date()
        let result = AppGroupKeys.formattedTime(from: start)
        XCTAssertEqual(result.text, "0m")
        XCTAssertFalse(result.isOver1Hour)
    }
}
