import XCTest
@testable import Wasted

// The dedup that stops a DeviceActivity replay burst from inflating the day —
// the bug that showed 12h (combined) and 48h (per-app sum) at 7pm when the real
// total was 53 minutes.
final class ThresholdSanityTests: XCTestCase {

    func test_normalMinuteStep_accepted() {
        // The combined series advances a minute at a time.
        XCTAssertTrue(ThresholdSanity.accept(newTotalSeconds: 54 * 60, storedSeconds: 53 * 60))
    }

    func test_perAppFifteenMinuteStep_accepted() {
        XCTAssertTrue(ThresholdSanity.accept(newTotalSeconds: 45 * 60, storedSeconds: 30 * 60))
    }

    func test_replayLowerThanStored_rejected() {
        // Classic replay: a threshold already passed. (Monotonic guard.)
        XCTAssertFalse(ThresholdSanity.accept(newTotalSeconds: 20 * 60, storedSeconds: 53 * 60))
    }

    func test_theActualBug_crossDayCumulativeJump_rejected() {
        // From the device log: stored 53m, a replayed event claims 205m (+152m)
        // in a single step. Impossible from 1-minute thresholds.
        XCTAssertFalse(ThresholdSanity.accept(newTotalSeconds: 205 * 60, storedSeconds: 53 * 60))
        // And because the first big jump is rejected, stored stays 53m, so every
        // later burst event is an even bigger jump — all rejected.
        XCTAssertFalse(ThresholdSanity.accept(newTotalSeconds: 720 * 60, storedSeconds: 53 * 60))
    }

    func test_rebuildAfterHeal_acceptsPlausibleCatchUp() {
        // After a heal resets to 0, the next real threshold (well under an hour)
        // must be accepted so the day rebuilds.
        XCTAssertTrue(ThresholdSanity.accept(newTotalSeconds: 54 * 60, storedSeconds: 0))
    }
}

final class HealImpossibleTotalTests: XCTestCase {

    private func store() -> (UsageStore, String) {
        let suite = "HealTests-\(UUID().uuidString)"
        return (UsageStore(defaults: UserDefaults(suiteName: suite)!), suite)
    }

    // 2pm — 14h have NOT elapsed, so a 48h total is impossible and must be wiped.
    private let twoPM = Calendar.current.startOfDay(for: Date()).addingTimeInterval(14 * 3600)

    func test_impossibleTotal_isReset() {
        let (s, suite) = store()
        defer { UserDefaults().removePersistentDomain(forName: suite) }

        var usage = DailyUsage()
        usage.add(seconds: 48 * 3600, for: "0")   // 48h — impossible
        s.save(usage)
        s.setCombinedSecondsToday(12 * 3600)

        XCTAssertTrue(s.healImpossibleTotal(now: twoPM))
        XCTAssertEqual(s.totalSecondsAllApps(), 0)
        XCTAssertEqual(s.combinedSecondsToday(), 0)
    }

    // A real, heavy-but-possible total (3h at 2pm) must be left alone — the heal
    // can never eat legitimate usage.
    func test_plausibleTotal_isUntouched() {
        let (s, suite) = store()
        defer { UserDefaults().removePersistentDomain(forName: suite) }

        var usage = DailyUsage()
        usage.add(seconds: 3 * 3600, for: "0")
        s.save(usage)

        XCTAssertFalse(s.healImpossibleTotal(now: twoPM))
        XCTAssertEqual(s.totalSecondsAllApps(), 3 * 3600)
    }
}
