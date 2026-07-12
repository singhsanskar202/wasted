import XCTest
@testable import Wasted

final class RealityCheckTests: XCTestCase {

    func test_missingGuess_returnsNil() {
        XCTAssertNil(RealityCheck.make(guessSeconds: 0, firstFullDaySeconds: 15120))
    }

    func test_zeroUsageDay_returnsNil() {
        XCTAssertNil(RealityCheck.make(guessSeconds: 7200, firstFullDaySeconds: 0))
    }

    // MARK: - Underestimated (the classic case)

    func test_exactCopy_guess2h_actual4h12m() {
        let check = RealityCheck.make(guessSeconds: 7200, firstFullDaySeconds: 15120)
        XCTAssertEqual(check?.guessLine, "you guessed 2h.")
        XCTAssertEqual(check?.realityLine, "reality: 4h 12m.")
        XCTAssertEqual(check?.deltaLine, "off by 110%.")
        XCTAssertEqual(check?.verdict, .underestimated(percent: 110))
        // Only an underestimate is bad NEWS — only it earns the red.
        XCTAssertEqual(check?.isAlarming, true)
    }

    func test_underOneHourGuess_formatsAsMinutes() {
        let check = RealityCheck.make(guessSeconds: 3600, firstFullDaySeconds: 1800)
        XCTAssertEqual(check?.guessLine, "you guessed 1h.")
        XCTAssertEqual(check?.realityLine, "reality: 30m.")
    }

    // MARK: - The moment must never congratulate

    // This is the whole point of the type. The old copy said "you actually
    // knew." whenever reality landed at or below the guess — so the app's most
    // important moment told roughly half its users their instinct was fine and
    // they didn't need a mirror. An accurate guess is WORSE, not better: you
    // knew what it cost and you spent it anyway.
    func test_accurateGuess_confrontsRatherThanCongratulates() {
        let check = RealityCheck.make(guessSeconds: 7200, firstFullDaySeconds: 7200)
        XCTAssertEqual(check?.verdict, .knew)
        XCTAssertEqual(check?.deltaLine, "you knew. and you did it anyway.")
        XCTAssertEqual(check?.isAlarming, false)
    }

    func test_slightlyUnderGuess_stillCountsAsKnowing() {
        // 1h50m against a 2h guess — inside the accuracy band, not an overshoot.
        let check = RealityCheck.make(guessSeconds: 7200, firstFullDaySeconds: 6600)
        XCTAssertEqual(check?.verdict, .knew)
    }

    func test_overestimatedGuess_confrontsRatherThanCongratulates() {
        // Guessed 4h, spent 2h. Still never a compliment.
        let check = RealityCheck.make(guessSeconds: 14400, firstFullDaySeconds: 7200)
        XCTAssertEqual(check?.verdict, .sawItComing)
        XCTAssertEqual(check?.deltaLine, "you saw it coming. you did it anyway.")
        XCTAssertEqual(check?.isAlarming, false)
    }

    // The regression guard: no verdict, at any ratio, may produce praise.
    func test_noVerdictEverPraisesTheUser() {
        let banned = ["actually knew", "well done", "nice", "good", "great", "progress", "keep it up"]
        let guess = 7200

        for actualMinutes in stride(from: 5, through: 600, by: 5) {
            guard let check = RealityCheck.make(guessSeconds: guess, firstFullDaySeconds: actualMinutes * 60) else {
                continue
            }
            let copy = (check.deltaLine + " " + check.closingLine).lowercased()
            for phrase in banned {
                XCTAssertFalse(copy.contains(phrase), "reality check praised the user at \(actualMinutes)m: \(copy)")
            }
        }
    }

    // The closer contradicted itself: it told a user who had guessed correctly
    // that "your sense of it was wrong."
    func test_closingLine_doesNotCallAnAccurateGuessWrong() {
        let knew = RealityCheck.make(guessSeconds: 7200, firstFullDaySeconds: 7200)
        XCTAssertFalse(knew!.closingLine.contains("sense of it was wrong"))

        let missed = RealityCheck.make(guessSeconds: 7200, firstFullDaySeconds: 15120)
        XCTAssertTrue(missed!.closingLine.contains("sense of it was wrong"))
    }
}
