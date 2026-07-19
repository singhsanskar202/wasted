import XCTest
@testable import Wasted

// The freemium gate and the storage it rests on. The daily mirror is free
// forever; ProGate only decides who sees the long receipt.
final class ProGateTests: XCTestCase {

    // The beta override may make everyone Pro, but it must never make a PAYING
    // state read as locked — and once the paywall ships, the gate must be
    // exactly the entitlement.
    func test_unlockedIsAlwaysPro() {
        XCTAssertTrue(ProGate.isPro(unlocked: true))
    }

    func test_betaOverride_isLoud() {
        // If this fails, the paywall went live: delete this assertion and flip
        // the one below on. It exists so flipping the flag for launch is a
        // conscious act that breaks a test, not a silent diff.
        XCTAssertFalse(ProGate.paywallEnabled, "paywall is ON — ship mode. Update this test.")
        // Ship mode contract (enable with the flag):
        // XCTAssertFalse(ProGate.isPro(unlocked: false))
    }

    func test_usageStore_firstLaunchRoundTrip() {
        let suiteName = "ProGateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UsageStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_780_000_000)

        XCTAssertNil(store.firstLaunchDate())
        store.stampFirstLaunchIfNeeded(now: now)
        XCTAssertEqual(store.firstLaunchDate(), now)

        // Second stamp must not overwrite the original.
        store.stampFirstLaunchIfNeeded(now: now.addingTimeInterval(86400))
        XCTAssertEqual(store.firstLaunchDate(), now)
    }

    func test_usageStore_unlockedRoundTrip() {
        let suiteName = "ProGateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UsageStore(defaults: defaults)

        XCTAssertFalse(store.isUnlocked())
        store.setUnlocked(true)
        XCTAssertTrue(store.isUnlocked())
        store.setUnlocked(false)
        XCTAssertFalse(store.isUnlocked())
    }

    // The archive is the product being sold — losing it is losing the thing
    // Pro paid for.
    func test_archive_isUncapped_andSeedsFromTheRollingWeek() {
        let suiteName = "ProGateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UsageStore(defaults: defaults)

        // Ten archived days: the rolling window must trim to 7, the archive
        // must keep all ten.
        for dayIndex in 1...10 {
            var usage = DailyUsage(date: String(format: "2026-06-%02d", dayIndex))
            usage.add(seconds: 600 * dayIndex, for: "0")
            store.archiveToHistory(usage)
        }
        XCTAssertEqual(store.loadHistory().count, 7)
        XCTAssertEqual(store.loadArchive().count, 10)
        XCTAssertEqual(store.loadArchive().first?.date, "2026-06-01")

        // Re-archiving a date replaces it, never doubles it.
        var corrected = DailyUsage(date: "2026-06-10")
        corrected.add(seconds: 42, for: "0")
        store.archiveToHistory(corrected)
        XCTAssertEqual(store.loadArchive().count, 10)
        XCTAssertEqual(store.loadArchive().last?.totalSeconds(for: "0"), 42)
    }

    func test_fullHistory_endsWithTodayLiveRecord() {
        let suiteName = "ProGateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UsageStore(defaults: defaults)

        var yesterday = DailyUsage(date: "2000-01-01")
        yesterday.add(seconds: 3600, for: "0")
        store.archiveToHistory(yesterday)

        let full = store.loadFullHistory()
        // Last element is today's live record (possibly empty), so the long
        // receipt always includes the day in progress.
        XCTAssertEqual(full.last?.date, DailyUsage.todayString())
        XCTAssertTrue(full.contains { $0.date == "2000-01-01" })
    }
}
