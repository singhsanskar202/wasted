import XCTest
@testable import Wasted

// The personal lines: the mirror quoting the user's own sentence back. The
// laws are the same as the rest of the copy bank — never advise (quoting is
// not advising), never repeat while an unused line exists, and read correctly
// with ANY phrase the user typed (the colon construction's whole job).
final class PersonalNudgeTests: XCTestCase {

    func test_personalLines_quoteTheUserVerbatim_withStablePositionalIDs() {
        let lines = NudgeCopy.personalLines(["play the ukulele", "read"])
        XCTAssertEqual(lines.map(\.text), ["you said: play the ukulele.", "you said: read."])
        XCTAssertEqual(lines.map(\.id), [100, 101])
    }

    func test_atMostThreeIntentions_becomeLines() {
        XCTAssertEqual(NudgeCopy.personalLines(["a", "b", "c", "d"]).count, 3)
    }

    func test_personalLines_joinTheRotation() {
        // Deterministic pick: always the highest id, so the personal line is
        // chosen the moment it's in the unused pool.
        let line = NudgeCopy.next(
            minutes: 15,
            used: [],
            intentions: ["play the ukulele"],
            pick: { pool in pool.max { $0.id < $1.id } }
        )
        XCTAssertEqual(line.text, "you said: play the ukulele.")
    }

    func test_personalLines_respectTheNoRepeatLaw() {
        let first = NudgeCopy.next(
            minutes: 15,
            used: [],
            intentions: ["read"],
            pick: { pool in pool.max { $0.id < $1.id } }
        )
        XCTAssertEqual(first.id, 100)
        // Once spent, the same pick strategy must fall back to fresh copy.
        let second = NudgeCopy.next(
            minutes: 15,
            used: [first.id],
            intentions: ["read"],
            pick: { pool in pool.max { $0.id < $1.id } }
        )
        XCTAssertNotEqual(second.id, first.id)
    }

    func test_noIntentions_leavesTheBankUntouched() {
        let pool = NudgeCopy.Tier(minutes: 15).lines
        let line = NudgeCopy.next(minutes: 15, used: [], intentions: [])
        XCTAssertTrue(pool.contains(line))
    }

    // The stored form is the mirror's register: trimmed, lowercase, no
    // trailing period (the template supplies its own).
    func test_canonicalIntention_normalises() {
        XCTAssertEqual(NudgeCopy.canonicalIntention("  Play the Ukulele. "), "play the ukulele")
        XCTAssertNil(NudgeCopy.canonicalIntention("   "))
        XCTAssertNil(NudgeCopy.canonicalIntention("..."))
    }

    func test_intentions_roundTripThroughTheStore() {
        let suiteName = "PersonalNudgeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UsageStore(defaults: defaults)

        XCTAssertEqual(store.intentions(), [])
        store.setIntentions(["play the ukulele", "read"])
        XCTAssertEqual(store.intentions(), ["play the ukulele", "read"])
        store.setIntentions([])
        XCTAssertEqual(store.intentions(), [])
    }
}
