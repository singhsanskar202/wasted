import XCTest
@testable import Wasted

final class QuoteBankTests: XCTestCase {

    private var allLines: [String] {
        QuoteBank.Temper.allCases.flatMap { QuoteBank.lines(for: $0) }
    }

    func test_everyTemperHasLines() {
        for temper in QuoteBank.Temper.allCases {
            XCTAssertGreaterThanOrEqual(QuoteBank.lines(for: temper).count, 4, "\(temper) is thin")
        }
    }

    func test_noLineIsEmpty() {
        for line in allLines {
            XCTAssertFalse(line.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // The mirror gets meaner as the number climbs, and THAT is the provocation.
    // The old bank picked at random by calendar day, so the same line greeted a
    // clean morning and a six-hour binge — a fortune cookie that knew nothing
    // about the person reading it.
    func test_temperEscalatesWithTheNumber() {
        XCTAssertEqual(QuoteBank.Temper(seconds: 0), .idle)
        XCTAssertEqual(QuoteBank.Temper(seconds: 59), .idle)
        XCTAssertEqual(QuoteBank.Temper(seconds: 60), .waiting)
        XCTAssertEqual(QuoteBank.Temper(seconds: 29 * 60), .waiting)
        XCTAssertEqual(QuoteBank.Temper(seconds: 30 * 60), .pointed)
        XCTAssertEqual(QuoteBank.Temper(seconds: 119 * 60), .pointed)
        XCTAssertEqual(QuoteBank.Temper(seconds: 120 * 60), .cruel)
        XCTAssertEqual(QuoteBank.Temper(seconds: 239 * 60), .cruel)
        XCTAssertEqual(QuoteBank.Temper(seconds: 240 * 60), .brutal)
        XCTAssertEqual(QuoteBank.Temper(seconds: 12 * 3600), .brutal)
    }

    // THE BUG: "nothing yet. give it an hour." fired anywhere under 30 minutes, so
    // the mirror said NOTHING YET directly above a number reading 20m. The app
    // contradicted itself on its own home screen, in the one voice that is
    // supposed to be unarguable.
    //
    // The rule: every line in a tier must be TRUE at every value inside that tier.
    // Only the zero tier may claim nothing has happened.
    func test_onlyTheZeroTierMayClaimNothingHappened() {
        let claimsNothing = ["nothing yet", "hasn't started", "the quiet part"]

        for temper in QuoteBank.Temper.allCases where temper != .idle {
            for line in QuoteBank.lines(for: temper) {
                for claim in claimsNothing {
                    XCTAssertFalse(
                        line.lowercased().contains(claim),
                        "\(temper) can fire with real usage on the screen, and this line denies it: \(line)"
                    )
                }
            }
        }
    }

    // The contradiction, caught end to end: at any non-zero total, the line the
    // user actually sees must never say nothing has happened.
    func test_theLineNeverDeniesTheNumberOnScreen() {
        for minutes in [1, 5, 19, 20, 29, 45, 90, 200, 400] {
            let line = QuoteBank.quote(forSeconds: minutes * 60).lowercased()
            XCTAssertFalse(line.contains("nothing yet"), "said 'nothing yet' at \(minutes)m: \(line)")
        }
        // And at true zero, it's allowed to.
        XCTAssertTrue(QuoteBank.idle.contains { $0.contains("nothing yet") })
    }

    // HomeView refreshes every five seconds. A quote that reshuffled on every tick
    // would be noise, not a voice.
    func test_quoteIsStableWithinADayAndTemper() {
        let now = Date()
        let first = QuoteBank.quote(forSeconds: 3600, on: now)
        for _ in 0..<20 {
            XCTAssertEqual(QuoteBank.quote(forSeconds: 3600, on: now), first)
        }
    }

    func test_quoteChangesWhenTheDayGetsWorse() {
        let now = Date()
        XCTAssertNotEqual(
            QuoteBank.quote(forSeconds: 10 * 60, on: now),
            QuoteBank.quote(forSeconds: 5 * 3600, on: now),
            "the mirror said the same thing at 10m and at 5h"
        )
    }

    // MARK: - The voice

    // "close this. go do the hard thing." / "put the phone down." The product
    // guide: the app "never blocks, never shames, never offers a solution — it
    // just keeps count." A mirror does not tell you what to do.
    func test_noLineOffersAdvice() {
        let imperatives = [
            "close this", "put the phone down", "go do", "be them",
            "use it well", "act like it", "stop treating",
        ]
        for line in allLines {
            for phrase in imperatives {
                XCTAssertFalse(line.lowercased().contains(phrase), "advice: \(line)")
            }
        }
    }

    // "every hour you scroll, someone else is building something." That's a
    // LinkedIn post, and it's the easiest line in the world to shrug off.
    func test_noLineIsAHustleCliche() {
        let linkedin = [
            "someone else is building", "successful people", "greatness",
            "your goals are waiting", "guard their attention",
        ]
        for line in allLines {
            for phrase in linkedin {
                XCTAssertFalse(line.lowercased().contains(phrase), "hustle cliché: \(line)")
            }
        }
    }

    // The old bank literally shipped "awareness is the first step. you're reading
    // this. good." The mirror never says good.
    func test_noLineCongratulatesTheUser() {
        for line in allLines {
            let lowered = line.lowercased()
            XCTAssertFalse(lowered.contains("good."), "congratulation: \(line)")
            XCTAssertFalse(lowered.contains("first step"), "congratulation: \(line)")
        }
    }

    func test_theVoiceIsLowercaseAndNeverShouts() {
        for line in allLines {
            XCTAssertFalse(line.contains("!"), "the mirror does not shout: \(line)")
            XCTAssertEqual(line, line.lowercased(), "the mirror speaks lowercase: \(line)")
        }
    }

    func test_noDuplicateLinesAcrossTempers() {
        XCTAssertEqual(Set(allLines).count, allLines.count)
    }
}
