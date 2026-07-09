import XCTest
@testable import Wasted

final class RealityCheckTests: XCTestCase {

    func test_missingGuess_returnsNil() {
        XCTAssertNil(RealityCheck.make(guessSeconds: 0, firstFullDaySeconds: 15120))
    }

    func test_zeroUsageDay_returnsNil() {
        XCTAssertNil(RealityCheck.make(guessSeconds: 7200, firstFullDaySeconds: 0))
    }

    func test_exactCopy_guess2h_actual4h12m() {
        let check = RealityCheck.make(guessSeconds: 7200, firstFullDaySeconds: 15120)
        XCTAssertEqual(check?.guessLine, "you guessed 2h.")
        XCTAssertEqual(check?.realityLine, "reality: 4h 12m.")
        XCTAssertEqual(check?.deltaLine, "off by 110%.")
    }

    func test_actualBelowGuess_saysYouActuallyKnew() {
        let check = RealityCheck.make(guessSeconds: 14400, firstFullDaySeconds: 10800)
        XCTAssertEqual(check?.deltaLine, "you actually knew.")
    }

    func test_actualEqualsGuess_saysYouActuallyKnew() {
        let check = RealityCheck.make(guessSeconds: 7200, firstFullDaySeconds: 7200)
        XCTAssertEqual(check?.deltaLine, "you actually knew.")
    }

    func test_underOneHourGuess_formatsAsMinutes() {
        let check = RealityCheck.make(guessSeconds: 3600, firstFullDaySeconds: 1800)
        XCTAssertEqual(check?.guessLine, "you guessed 1h.")
        XCTAssertEqual(check?.realityLine, "reality: 30m.")
    }
}
