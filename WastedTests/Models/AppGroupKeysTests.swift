import XCTest
@testable import Wasted

final class AppGroupKeysTests: XCTestCase {

    func test_appIconKey_returnsExpectedKey() {
        XCTAssertEqual(AppGroupKeys.appIconKey(for: "Instagram"), "app_icon_Instagram")
        XCTAssertEqual(AppGroupKeys.appIconKey(for: "YouTube"), "app_icon_YouTube")
    }

    func test_formattedDuration_formatsAcrossRanges() {
        XCTAssertEqual(AppGroupKeys.formattedDuration(0), "0m")
        XCTAssertEqual(AppGroupKeys.formattedDuration(42 * 60), "42m")
        XCTAssertEqual(AppGroupKeys.formattedDuration(5040), "1h 24m")
        XCTAssertEqual(AppGroupKeys.formattedDuration(-30), "0m")
    }

    // Nobody says "one hour zero minutes".
    func test_formattedDuration_dropsZeroMinutes() {
        XCTAssertEqual(AppGroupKeys.formattedDuration(3600), "1h")
        XCTAssertEqual(AppGroupKeys.formattedDuration(2 * 3600), "2h")
    }

    // The island and lock screen used to render this as "1:23". That card sits
    // inches below the Lock Screen's own clock, so a colon between two numbers
    // reads as a time of day — 1:23 looked like twenty-three past one.
    func test_formattedDuration_neverUsesAClockColon() {
        for seconds in stride(from: 0, through: 12 * 3600, by: 137) {
            XCTAssertFalse(
                AppGroupKeys.formattedDuration(seconds).contains(":"),
                "a colon reads as o'clock: \(AppGroupKeys.formattedDuration(seconds))"
            )
        }
    }

    func test_awakeDayConstant_is16Hours() {
        XCTAssertEqual(AppGroupKeys.awakeDayHours, 16)
    }
}
