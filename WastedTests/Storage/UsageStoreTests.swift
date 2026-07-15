import XCTest
@testable import Wasted

final class UsageStoreTests: XCTestCase {
    var sut: UsageStore!
    var testSuiteName: String!

    override func setUp() {
        super.setUp()
        testSuiteName = "test.wasted.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: testSuiteName)!
        sut = UsageStore(defaults: defaults)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: testSuiteName)
        sut = nil
        super.tearDown()
    }

    // THE MIDNIGHT ARCHIVE BUG (device log, 2026-07-15).
    //
    // intervalDidEnd fires at ~00:00:02, when todayString() is the NEW day. It
    // archived via loadTodayUsage(), which returns EMPTY once the date rolls — so
    // it saved "total=0s" and erased the day that just ended, which then made the
    // 8am morning report skip ("nothing to report"). Archiving must read the
    // record on disk, not ask for "today".
    func test_loadStoredDay_returnsYesterdaysRecord_evenAfterMidnight() {
        var yesterday = DailyUsage(date: "2026-07-14")
        yesterday.add(seconds: 6900, for: "0")   // 1h55m — the real vanished total
        sut.save(yesterday)

        // loadTodayUsage() correctly refuses it (wrong day) …
        XCTAssertTrue(sut.loadTodayUsage().seconds.isEmpty)
        // … but loadStoredDay() hands back exactly what intervalDidEnd must archive.
        let stored = sut.loadStoredDay()
        XCTAssertEqual(stored?.date, "2026-07-14")
        XCTAssertEqual(stored?.seconds.values.reduce(0, +), 6900)
    }

    func test_loadStoredDay_isNilWhenNothingStored() {
        XCTAssertNil(sut.loadStoredDay())
    }

    func test_loadToday_returnsEmptyUsage_whenNothingStored() {
        let usage = sut.loadTodayUsage()
        XCTAssertEqual(usage.date, DailyUsage.todayString())
        XCTAssertTrue(usage.seconds.isEmpty)
    }

    func test_saveAndLoad_roundtrip() {
        var usage = DailyUsage(date: DailyUsage.todayString())
        usage.add(seconds: 1800, for: "com.instagram.instagrammobile")
        sut.save(usage)

        let loaded = sut.loadTodayUsage()
        XCTAssertEqual(loaded.totalSeconds(for: "com.instagram.instagrammobile"), 1800)
    }

    func test_addSeconds_accumulatesAcrossCalls() {
        sut.addSeconds(600, for: "com.instagram.instagrammobile")
        sut.addSeconds(300, for: "com.instagram.instagrammobile")

        XCTAssertEqual(sut.loadTodayUsage().totalSeconds(for: "com.instagram.instagrammobile"), 900)
    }

    func test_loadToday_returnsNewUsage_whenStoredDateIsStale() {
        var stale = DailyUsage(date: "2020-01-01")
        stale.add(seconds: 9999, for: "com.instagram.instagrammobile")
        sut.save(stale)

        let usage = sut.loadTodayUsage()
        XCTAssertEqual(usage.date, DailyUsage.todayString())
        XCTAssertEqual(usage.totalSeconds(for: "com.instagram.instagrammobile"), 0)
    }

    func test_setAndGet_activeApp() throws {
        sut.setActiveApp(bundleId: "com.instagram.instagrammobile", sessionStart: Date(timeIntervalSince1970: 1000))
        XCTAssertEqual(sut.activeAppBundleId(), "com.instagram.instagrammobile")
        let start = try XCTUnwrap(sut.activeSessionStart())
        XCTAssertEqual(start.timeIntervalSince1970, 1000.0, accuracy: 1.0)
    }

    func test_clearActiveApp() {
        sut.setActiveApp(bundleId: "com.instagram.instagrammobile", sessionStart: Date())
        sut.clearActiveApp()
        XCTAssertNil(sut.activeAppBundleId())
        XCTAssertNil(sut.activeSessionStart())
    }

    // MARK: - Combined total

    func test_combinedSeconds_roundtrip() {
        sut.setCombinedSecondsToday(1500)
        XCTAssertEqual(sut.combinedSecondsToday(), 1500)
    }

    func test_combinedSeconds_zeroWhenDateIsStale() {
        sut.setCombinedSecondsToday(1500)
        sut.defaults.set("2020-01-01", forKey: AppGroupKeys.combinedSecondsDateKey)
        XCTAssertEqual(sut.combinedSecondsToday(), 0)
    }

    func test_totalSecondsAllApps_takesLeadingSource() {
        sut.addSeconds(600, for: "0")
        sut.setCombinedSecondsToday(900)
        XCTAssertEqual(sut.totalSecondsAllApps(), 900)

        sut.addSeconds(600, for: "0")   // per-app sum now 1200, ahead of combined
        XCTAssertEqual(sut.totalSecondsAllApps(), 1200)
    }
}
