import XCTest
@testable import Wasted

final class NudgeTests: XCTestCase {

    private let today = "2026-07-06"
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    // MARK: - NudgeGate

    func test_shouldNudge_rejectsNon30MinuteMultiples() {
        XCTAssertFalse(NudgeGate.shouldNudge(minutes: 5, last: nil, today: today, now: now))
        XCTAssertFalse(NudgeGate.shouldNudge(minutes: 45, last: nil, today: today, now: now))
        XCTAssertFalse(NudgeGate.shouldNudge(minutes: 0, last: nil, today: today, now: now))
    }

    func test_shouldNudge_firstNudgeOfDayFires() {
        XCTAssertTrue(NudgeGate.shouldNudge(minutes: 30, last: nil, today: today, now: now))
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

    func test_title_formatsMinutesAndHours() {
        XCTAssertEqual(NudgeCopy.title(appName: "Instagram", minutes: 30), "30m on Instagram")
        XCTAssertEqual(NudgeCopy.title(appName: "YouTube", minutes: 90), "1h 30m on YouTube")
        XCTAssertEqual(NudgeCopy.title(appName: "X", minutes: 120), "2h 0m on X")
    }

    func test_bodies_haveVariantsWithNoExclamationPoints() {
        XCTAssertGreaterThanOrEqual(NudgeCopy.bodies.count, 4)
        for body in NudgeCopy.bodies {
            XCTAssertFalse(body.contains("!"), "nudge copy must not shout: \(body)")
        }
    }

    func test_body_indexWraps() {
        let count = NudgeCopy.bodies.count
        XCTAssertEqual(NudgeCopy.body(at: count), NudgeCopy.bodies[0])
        XCTAssertEqual(NudgeCopy.body(at: count + 2), NudgeCopy.bodies[2])
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
