import XCTest
@testable import Wasted

final class LiveActivityPolicyTests: XCTestCase {

    private let today = "2026-07-12"
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func snapshot(
        id: String = "a",
        day: String? = nil,
        isUpdatable: Bool = true,
        ageHours: Double = 0
    ) -> ActivitySnapshot {
        ActivitySnapshot(
            id: id,
            day: day ?? today,
            isUpdatable: isUpdatable,
            startedAt: now.addingTimeInterval(-ageHours * 3600)
        )
    }

    private func decide(_ existing: [ActivitySnapshot], canCreate: Bool) -> LiveActivityDecision {
        LiveActivityPolicy.decide(existing: existing, today: today, now: now, canCreate: canCreate)
    }

    func test_noActivity_createsOne() {
        XCTAssertEqual(decide([], canCreate: true), .replace)
    }

    func test_freshActivityForToday_isUpdatedInPlace() {
        let live = snapshot(id: "live", ageHours: 0.5)
        XCTAssertEqual(decide([live], canCreate: true), .update(id: "live"))
    }

    // THE BUG THAT MADE THE ISLAND STAY DEAD.
    //
    // iOS ends a Live Activity at the 8h mark, but the ended activity REMAINS in
    // Activity.activities for up to four more hours, still carrying today's date.
    // The old code checked only the day, took the update branch, and called
    // update() on a corpse — which does nothing — so it never requested a new
    // activity. The island didn't just vanish; it never came back, not even when
    // the user reopened the app.
    func test_endedActivity_isReplaced_notUpdated() {
        let corpse = snapshot(id: "corpse", isUpdatable: false, ageHours: 9)
        XCTAssertEqual(decide([corpse], canCreate: true), .replace)
    }

    // EVERY OPEN RESETS THE 8H CLOCK. The old policy rotated only at 7h, so an
    // open at hour 6 bought nothing and the island still died at hour 8 — the
    // "it dies unless I open the app at exactly the right time" complaint. Now
    // any foreground pass past the threshold trades the old activity for a
    // fresh eight-hour window.
    func test_foreground_rotatesAnythingOlderThanTheThreshold() {
        let aged = snapshot(id: "aged", ageHours: 1.5)
        XCTAssertEqual(decide([aged], canCreate: true), .replace)
    }

    func test_foregroundRotationThreshold_leavesAFreshActivityAlone() {
        // Rotation is end + request — a flicker. It must not happen on every
        // five-second HomeView tick, only once the clock is actually worth
        // resetting.
        XCTAssertGreaterThanOrEqual(LiveActivityPolicy.foregroundRotateAfter, 1800)
        // And it must be far enough from 8h that rotating is always a win.
        XCTAssertLessThan(LiveActivityPolicy.foregroundRotateAfter, 7 * 3600)
    }

    // BACKGROUND RUNS UPDATE UNTIL THE MOMENT OF DEATH. The old policy's 7h age
    // cutoff made a background refresh treat a live 7h30m activity as unusable
    // and freeze it a full hour before iOS killed it. Age only matters when a
    // fresh window can actually be bought — i.e. in the foreground.
    func test_background_updatesAnAgedActivityInsteadOfRotating() {
        let aged = snapshot(id: "aged", ageHours: 7.9)
        XCTAssertEqual(decide([aged], canCreate: false), .update(id: "aged"))
    }

    func test_background_withOnlyACorpse_asksToReplace() {
        // The caller guards this with canCreate and marks the island down —
        // the policy just reports the truth: nothing here is updatable.
        let corpse = snapshot(id: "corpse", isUpdatable: false, ageHours: 9)
        XCTAssertEqual(decide([corpse], canCreate: false), .replace)
    }

    // Midnight rollover: the day boundary runs in the monitor extension, which
    // cannot reach ActivityKit at all, so yesterday's activity survives the night.
    func test_yesterdaysActivity_isReplaced() {
        let yesterday = snapshot(id: "old-day", day: "2026-07-11", ageHours: 3)
        XCTAssertEqual(decide([yesterday], canCreate: true), .replace)
    }

    func test_picksTheUsableActivity_whenACorpseIsListedFirst() {
        let corpse = snapshot(id: "corpse", isUpdatable: false, ageHours: 9)
        let live = snapshot(id: "live", ageHours: 0.2)
        XCTAssertEqual(decide([corpse, live], canCreate: true), .update(id: "live"))
    }
}

// The dead island's handoff to the monitor extension: the app's background runs
// flag the death, exactly ONE nudge carries the fact, and a revival clears the
// slate so a second death the same day earns its own single mention.
final class IslandStatusTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "island-status-tests"
    private let today = "2026-07-12"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func test_noDeathRecorded_announcesNothing() {
        XCTAssertFalse(IslandStatus.takeAnnouncement(today: today, defaults: defaults))
    }

    func test_death_isAnnouncedExactlyOnce() {
        IslandStatus.markDown(today: today, defaults: defaults)
        XCTAssertTrue(IslandStatus.takeAnnouncement(today: today, defaults: defaults))
        // The island is still down, but a repeated line stops being read.
        XCTAssertFalse(IslandStatus.takeAnnouncement(today: today, defaults: defaults))
    }

    func test_yesterdaysDeath_doesNotCaptionTodaysNudges() {
        IslandStatus.markDown(today: "2026-07-11", defaults: defaults)
        XCTAssertFalse(IslandStatus.takeAnnouncement(today: today, defaults: defaults))
    }

    func test_revival_clearsTheSlate_soASecondDeathAnnouncesAgain() {
        IslandStatus.markDown(today: today, defaults: defaults)
        XCTAssertTrue(IslandStatus.takeAnnouncement(today: today, defaults: defaults))

        IslandStatus.markAlive(defaults: defaults)
        // Alive: nothing to say.
        XCTAssertFalse(IslandStatus.takeAnnouncement(today: today, defaults: defaults))

        // Dies again the same day — one more mention, not silence.
        IslandStatus.markDown(today: today, defaults: defaults)
        XCTAssertTrue(IslandStatus.takeAnnouncement(today: today, defaults: defaults))
    }
}
