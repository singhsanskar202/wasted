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
        XCTAssertEqual(AppGroupKeys.formattedDuration(3600), "1h 0m")
        XCTAssertEqual(AppGroupKeys.formattedDuration(5040), "1h 24m")
        XCTAssertEqual(AppGroupKeys.formattedDuration(-30), "0m")
    }

    func test_awakeDayConstant_is16Hours() {
        XCTAssertEqual(AppGroupKeys.awakeDayHours, 16)
    }
}
