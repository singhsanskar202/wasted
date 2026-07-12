import XCTest
@testable import Wasted

final class EquivalentTaskMapperTests: XCTestCase {

    private func line(_ minutes: Int) -> String {
        EquivalentTaskMapper.equivalent(for: minutes * 60)?.line ?? ""
    }

    func test_underTenMinutes_hasNoEquivalent() {
        XCTAssertNil(EquivalentTaskMapper.equivalent(for: 0))
        XCTAssertNil(EquivalentTaskMapper.equivalent(for: 9 * 60))
        XCTAssertNotNil(EquivalentTaskMapper.equivalent(for: 10 * 60))
    }

    // THE ORIGINAL BUG: a lookup table that snapped DOWN to a fixed threshold,
    // so 1h 23m rendered the 1h row ("a book chapter (25 pages)") and silently
    // discarded 23 minutes.
    //
    // THE DEEPER BUG: even fixed, "69 pages of a book" is unrelatable — nobody
    // can picture 69 pages — and it's the app suggesting a hobby, which the
    // product guide forbids ("never offers a solution — it just keeps count").
    // A comparison must be ONE WHOLE THING the reader can see at a glance.
    func test_theReportedCase_83Minutes_isOneThingYouCanPicture() {
        let text = line(83)
        XCTAssertEqual(text, "that's a football match.")
        XCTAssertFalse(text.contains("pages"), "a scaled count is not relatable: \(text)")
    }

    func test_noComparisonIsEverAScaledCount() {
        // If a comparison contains a number, it's a quantity — and a quantity is
        // the thing nobody can picture.
        for minutes in stride(from: 10, to: 240, by: 3) {
            let text = line(minutes)
            XCTAssertFalse(
                text.contains(where: \.isNumber),
                "comparison became a count at \(minutes)m: \(text)"
            )
        }
    }

    // Past the point where any single thing can hold the number, stop comparing
    // and state what it costs — the part you genuinely can't get back.
    func test_pastFourHours_stopsComparingAndCompounds() {
        let text = line(240)
        XCTAssertTrue(text.contains("days a year"), text)
        XCTAssertTrue(text.contains("you don't get them back"), text)
        // No film, no match, no hobby.
        XCTAssertFalse(text.contains("that's a"), text)
    }

    // 4h/day is 60.8 days a year — the exact number the app's own Hook opens
    // with ("that's 60 days a year. gone."). The first thing a user reads and
    // the line they see daily should agree.
    func test_theReckoningAgreesWithTheHook() {
        XCTAssertTrue(line(240).hasPrefix("61 days a year"), line(240))
        XCTAssertTrue(line(360).hasPrefix("91 days a year"), line(360))
        XCTAssertTrue(line(480).hasPrefix("122 days a year"), line(480))
    }

    func test_neverSuggestsAHobby() {
        // The old table's whole vocabulary. A mirror doesn't prescribe.
        let prescriptions = ["meditation", "run", "workout", "read", "pages", "guitar", "hike", "you could"]
        for minutes in stride(from: 10, through: 16 * 60, by: 5) {
            let text = line(minutes).lowercased()
            for word in prescriptions {
                XCTAssertFalse(text.contains(word), "prescribed '\(word)' at \(minutes)m: \(text)")
            }
        }
    }

    func test_everyValueAcrossAFullDayProducesALine() {
        for minutes in stride(from: 10, through: 16 * 60, by: 7) {
            let equivalent = EquivalentTaskMapper.equivalent(for: minutes * 60)
            XCTAssertNotNil(equivalent, "no line at \(minutes)m")
            XCTAssertFalse(equivalent!.line.isEmpty)
        }
    }
}
