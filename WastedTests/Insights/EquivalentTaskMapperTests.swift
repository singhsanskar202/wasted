import XCTest
@testable import Wasted

final class EquivalentTaskMapperTests: XCTestCase {

    private func text(_ minutes: Int) -> String {
        EquivalentTaskMapper.equivalent(for: minutes * 60)?.description ?? ""
    }

    func test_underTenMinutes_hasNoEquivalent() {
        XCTAssertNil(EquivalentTaskMapper.equivalent(for: 0))
        XCTAssertNil(EquivalentTaskMapper.equivalent(for: 9 * 60))
        XCTAssertNotNil(EquivalentTaskMapper.equivalent(for: 10 * 60))
    }

    // THE BUG. The old table snapped DOWN to a fixed threshold, so 1h 23m showed
    // the 1h row — "a book chapter (25 pages)" — silently discarding 23 minutes.
    // And 25 pages an hour is roughly half what an average adult reads, so the
    // claim understated the cost twice over. Understating is the one direction
    // this app must never err in.
    func test_theReportedCase_83Minutes_isNoLongerTwentyFivePages() {
        let pages = text(83)
        XCTAssertTrue(pages.contains("pages"), "expected a page count, got: \(pages)")
        XCTAssertFalse(pages.contains("25 pages"), "still understating: \(pages)")
        // ~50 pages an hour → 83 minutes is around 69.
        XCTAssertTrue(pages.contains("68") || pages.contains("69") || pages.contains("70"), pages)
    }

    // The class of bug, not the instance: every extra minute must move the number.
    func test_quantityScalesWithTime_neverSnapsToABucket() {
        let oneHour = text(60)
        let twoHours = text(120)
        XCTAssertNotEqual(oneHour, twoHours, "an extra hour changed nothing — still bucketed")

        let pagesAtOneHour = Int(oneHour.prefix(while: \.isNumber)) ?? 0
        let pagesAtTwoHours = Int(twoHours.prefix(while: \.isNumber)) ?? 0
        XCTAssertGreaterThan(pagesAtTwoHours, pagesAtOneHour)
        // Roughly 50 pages an hour, not 25.
        XCTAssertGreaterThan(pagesAtOneHour, 40)
    }

    func test_meditationClaimIsExactlyTrue() {
        // The one equivalent whose quantity IS the elapsed time — so it had
        // better match it.
        XCTAssertEqual(text(15), "a 15-minute meditation")
        XCTAssertEqual(text(25), "a 25-minute meditation")
    }

    func test_runIsAPlausiblePace() {
        // A 5K at an easy jog is about half an hour. 35 minutes should be ~5 km,
        // not 30.
        XCTAssertEqual(text(33), "a 5 km run")
    }

    func test_everyEquivalentIsNonEmptyAcrossAFullDay() {
        for minutes in stride(from: 10, through: 16 * 60, by: 7) {
            let equivalent = EquivalentTaskMapper.equivalent(for: minutes * 60)
            XCTAssertNotNil(equivalent, "no equivalent at \(minutes)m")
            XCTAssertFalse(equivalent!.description.isEmpty)
            XCTAssertFalse(equivalent!.emoji.isEmpty)
        }
    }
}
