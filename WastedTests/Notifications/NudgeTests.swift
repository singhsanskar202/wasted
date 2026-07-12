import XCTest
@testable import Wasted

final class NudgeTests: XCTestCase {

    private let today = "2026-07-06"
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    // MARK: - NudgeGate

    func test_shouldNudge_rejectsNon15MinuteMultiples() {
        XCTAssertFalse(NudgeGate.shouldNudge(minutes: 5, last: nil, today: today, now: now))
        XCTAssertFalse(NudgeGate.shouldNudge(minutes: 20, last: nil, today: today, now: now))
        XCTAssertFalse(NudgeGate.shouldNudge(minutes: 0, last: nil, today: today, now: now))
    }

    func test_shouldNudge_firesEveryQuarterHour() {
        XCTAssertTrue(NudgeGate.shouldNudge(minutes: 15, last: nil, today: today, now: now))
        XCTAssertTrue(NudgeGate.shouldNudge(minutes: 45, last: nil, today: today, now: now))
        XCTAssertTrue(NudgeGate.shouldNudge(minutes: 60, last: nil, today: today, now: now))
    }

    func test_shouldNudge_staleRecordFromYesterdayIsIgnored() {
        let last = NudgeRecord(date: "2026-07-05", minutes: 240, firedAt: now.addingTimeInterval(-30_000))
        XCTAssertTrue(NudgeGate.shouldNudge(minutes: 30, last: last, today: today, now: now))
    }

    func test_shouldNudge_rejectsAlreadyNudgedOrLowerThreshold() {
        let last = NudgeRecord(date: today, minutes: 60, firedAt: now.addingTimeInterval(-3600))
        XCTAssertFalse(NudgeGate.shouldNudge(minutes: 60, last: last, today: today, now: now))
        XCTAssertFalse(NudgeGate.shouldNudge(minutes: 30, last: last, today: today, now: now))
    }

    func test_shouldNudge_higherThresholdAfterGapFires() {
        let last = NudgeRecord(date: today, minutes: 30, firedAt: now.addingTimeInterval(-1800))
        XCTAssertTrue(NudgeGate.shouldNudge(minutes: 60, last: last, today: today, now: now))
    }

    func test_shouldNudge_burstWithinGapIsSuppressed() {
        // 30-min and 60-min thresholds delivered seconds apart
        let last = NudgeRecord(date: today, minutes: 30, firedAt: now.addingTimeInterval(-5))
        XCTAssertFalse(NudgeGate.shouldNudge(minutes: 60, last: last, today: today, now: now))
    }

    // MARK: - NudgeCopy

    private var allLines: [NudgeCopy.Line] { NudgeCopy.opening + NudgeCopy.settling + NudgeCopy.deep }

    func test_title_formatsMinutesAndHours() {
        XCTAssertEqual(NudgeCopy.title(minutes: 15), "15m")
        XCTAssertEqual(NudgeCopy.title(minutes: 90), "1h 30m")
        XCTAssertEqual(NudgeCopy.title(minutes: 120), "2h")
    }

    func test_everyLine_isLowercaseAndDoesNotShout() {
        for line in allLines {
            XCTAssertFalse(line.text.contains("!"), "nudge copy must not shout: \(line.text)")
            XCTAssertEqual(line.text, line.text.lowercased(), "nudge copy is lowercase: \(line.text)")
        }
    }

    // IDs are what the day's used-line set stores — a collision across tiers
    // would silently retire someone else's line.
    func test_lineIDs_areUniqueAcrossTiers() {
        XCTAssertEqual(Set(allLines.map(\.id)).count, allLines.count)
    }

    func test_tier_escalatesWithTime() {
        XCTAssertEqual(NudgeCopy.Tier(minutes: 15), .opening)
        XCTAssertEqual(NudgeCopy.Tier(minutes: 59), .opening)
        XCTAssertEqual(NudgeCopy.Tier(minutes: 60), .settling)
        XCTAssertEqual(NudgeCopy.Tier(minutes: 119), .settling)
        XCTAssertEqual(NudgeCopy.Tier(minutes: 120), .deep)
        XCTAssertEqual(NudgeCopy.Tier(minutes: 300), .deep)
    }

    func test_next_neverRepeatsALineWhileAnUnusedOneExists() {
        // Deterministic pick (first of the pool) so this asserts the filtering,
        // not the shuffle.
        let first: ([NudgeCopy.Line]) -> NudgeCopy.Line? = { $0.first }
        var used: Set<Int> = []

        for _ in 0..<NudgeCopy.opening.count {
            let line = NudgeCopy.next(minutes: 15, used: used, pick: first)
            XCTAssertFalse(used.contains(line.id), "repeated line \(line.id) while unused ones remained")
            used.insert(line.id)
        }
        XCTAssertEqual(used.count, NudgeCopy.opening.count)
    }

    func test_next_reusesTheTierRatherThanFallSilentWhenExhausted() {
        let exhausted = Set(NudgeCopy.opening.map(\.id))
        let line = NudgeCopy.next(minutes: 15, used: exhausted)
        // Still an opening line — never reaches for copy written for hour four.
        XCTAssertTrue(NudgeCopy.opening.contains(line))
    }

    func test_next_picksFromTheTierThatMatchesTheHour() {
        XCTAssertTrue(NudgeCopy.opening.contains(NudgeCopy.next(minutes: 30, used: [])))
        XCTAssertTrue(NudgeCopy.settling.contains(NudgeCopy.next(minutes: 90, used: [])))
        XCTAssertTrue(NudgeCopy.deep.contains(NudgeCopy.next(minutes: 180, used: [])))
    }

    func test_usedNudgeLines_areDayScoped() {
        let suiteName = "NudgeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UsageStore(defaults: defaults)

        XCTAssertTrue(store.usedNudgeLines().isEmpty)
        store.markNudgeLine(3)
        store.markNudgeLine(11)
        XCTAssertEqual(store.usedNudgeLines(), [3, 11])

        // Yesterday's spent lines must not silence today's.
        defaults.set("2020-01-01", forKey: AppGroupKeys.nudgeLinesDateKey)
        XCTAssertTrue(store.usedNudgeLines().isEmpty)
    }

    // MARK: - UsageStore round-trip

    func test_usageStore_nudgeRecordRoundTrip() {
        let suiteName = "NudgeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UsageStore(defaults: defaults)

        XCTAssertNil(store.lastNudge(for: "0"))

        store.recordNudge(minutes: 30, for: "0")
        let record = store.lastNudge(for: "0")
        XCTAssertEqual(record?.minutes, 30)
        XCTAssertEqual(record?.date, DailyUsage.todayString())
        XCTAssertNil(store.lastNudge(for: "1"))

        store.recordNudge(minutes: 60, for: "0")
        XCTAssertEqual(store.lastNudge(for: "0")?.minutes, 60)
    }
}
