import XCTest
@testable import Wasted

final class TrialClockTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    func test_unlocked_winsRegardlessOfFirstLaunch() {
        XCTAssertEqual(TrialClock.state(firstLaunch: nil, unlocked: true, now: now), .unlocked)
        let old = now.addingTimeInterval(-30 * 86400)
        XCTAssertEqual(TrialClock.state(firstLaunch: old, unlocked: true, now: now), .unlocked)
    }

    func test_nilFirstLaunch_isFullTrial() {
        XCTAssertEqual(TrialClock.state(firstLaunch: nil, unlocked: false, now: now), .trial(daysLeft: 7))
    }

    func test_day0_isFullTrial() {
        XCTAssertEqual(TrialClock.state(firstLaunch: now, unlocked: false, now: now), .trial(daysLeft: 7))
    }

    func test_day6point9_hasOneDayLeft() {
        let firstLaunch = now.addingTimeInterval(-6.9 * 86400)
        XCTAssertEqual(TrialClock.state(firstLaunch: firstLaunch, unlocked: false, now: now), .trial(daysLeft: 1))
    }

    func test_day7point0_isExpired() {
        let firstLaunch = now.addingTimeInterval(-7 * 86400)
        XCTAssertEqual(TrialClock.state(firstLaunch: firstLaunch, unlocked: false, now: now), .expired)
    }

    func test_wellPastTrial_isExpired() {
        let firstLaunch = now.addingTimeInterval(-30 * 86400)
        XCTAssertEqual(TrialClock.state(firstLaunch: firstLaunch, unlocked: false, now: now), .expired)
    }

    func test_usageStore_firstLaunchRoundTrip() {
        let suiteName = "TrialClockTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UsageStore(defaults: defaults)

        XCTAssertNil(store.firstLaunchDate())
        store.stampFirstLaunchIfNeeded(now: now)
        XCTAssertEqual(store.firstLaunchDate(), now)

        // Second stamp must not overwrite the original.
        store.stampFirstLaunchIfNeeded(now: now.addingTimeInterval(86400))
        XCTAssertEqual(store.firstLaunchDate(), now)
    }

    func test_usageStore_unlockedRoundTrip() {
        let suiteName = "TrialClockTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UsageStore(defaults: defaults)

        XCTAssertFalse(store.isUnlocked())
        store.setUnlocked(true)
        XCTAssertTrue(store.isUnlocked())
        store.setUnlocked(false)
        XCTAssertFalse(store.isUnlocked())
    }
}
