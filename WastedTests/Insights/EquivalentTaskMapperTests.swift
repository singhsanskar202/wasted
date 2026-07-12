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

    // THE ORIGINAL BUG: the table snapped DOWN to a fixed threshold, so 1h 23m
    // rendered the 1h row — "a book chapter (25 pages)" — silently discarding 23
    // minutes AND understating the reading rate. This app must never understate.
    func test_theReportedCase_83Minutes() {
        XCTAssertEqual(line(83), "that's a football match.")
    }

    // Every comparison must be something a stranger ANYWHERE already knows the
    // length of. These all failed that: a commute is 20 minutes for one person
    // and 90 for another; "a coffee" is 15 minutes or two hours; a flight is an
    // hour or eleven. Not durations — just vibes.
    func test_noComparisonDependsOnWhoTheUserIs() {
        let notUniversal = ["commute", "coffee", "flight", "your walk", "lunch break"]
        for minutes in stride(from: 10, through: 16 * 60, by: 3) {
            let text = line(minutes).lowercased()
            for phrase in notUniversal {
                XCTAssertFalse(text.contains(phrase), "assumed the user's life at \(minutes)m: \(text)")
            }
        }
    }

    // Nobody can picture 69 pages, or a 13 km run. A comparison is a NAMED thing
    // with a known length, never a computed quantity of one.
    func test_noComparisonIsAScaledQuantity() {
        for minutes in stride(from: 10, to: 150, by: 3) {
            let text = line(minutes).lowercased()
            XCTAssertFalse(text.contains("pages"), "a page count is not picturable: \(text)")
            XCTAssertFalse(text.contains(" km run"), "a scaled distance is not picturable: \(text)")
        }
    }

    // The bucket has to be tight enough that the thing named really is about as
    // long as the number beside it. The old buckets were an hour wide, which is
    // exactly how 83 minutes got described as a 60-minute activity.
    func test_eachComparisonIsRoughlyTheRightLength() {
        XCTAssertEqual(line(15), "that's a 15-minute meditation.")
        XCTAssertEqual(line(22), "that's an episode of a sitcom.")   // ~22 min
        XCTAssertEqual(line(31), "that's a 5K run.")                 // ~30 min
        XCTAssertEqual(line(45), "that's a full-body workout.")      // ~45 min
        XCTAssertEqual(line(60), "that's an episode of a drama.")    // ~1h
        XCTAssertEqual(line(90), "that's a football match.")         // 90 min, everywhere
        XCTAssertEqual(line(120), "that's a feature film.")          // ~2h
    }

    // Past the point where no single familiar thing is long enough, stop
    // comparing — "2.5 films" means nothing — and name what it actually costs.
    func test_pastTwoAndAHalfHours_stopsComparingAndCompounds() {
        let text = line(150)
        XCTAssertTrue(text.contains("days a year"), text)
        XCTAssertTrue(text.contains("you don't get them back"), text)
        XCTAssertFalse(text.contains("that's a"), text)
    }

    // 4h/day is 60.8 days a year — the number the Hook opens the whole app with
    // ("that's 60 days a year. gone."). The first line a user ever reads and the
    // line they see daily must agree.
    func test_theReckoningAgreesWithTheHook() {
        XCTAssertTrue(line(240).hasPrefix("61 days a year"), line(240))
        XCTAssertTrue(line(360).hasPrefix("91 days a year"), line(360))
        XCTAssertTrue(line(480).hasPrefix("122 days a year"), line(480))
    }

    func test_everyValueAcrossAFullDayProducesALine() {
        for minutes in stride(from: 10, through: 16 * 60, by: 7) {
            let equivalent = EquivalentTaskMapper.equivalent(for: minutes * 60)
            XCTAssertNotNil(equivalent, "no line at \(minutes)m")
            XCTAssertFalse(equivalent!.line.isEmpty)
        }
    }
}
