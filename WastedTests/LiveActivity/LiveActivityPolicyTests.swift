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

    func test_noActivity_createsOne() {
        XCTAssertEqual(LiveActivityPolicy.decide(existing: [], today: today, now: now), .replace)
    }

    func test_freshActivityForToday_isUpdatedInPlace() {
        let live = snapshot(id: "live", ageHours: 2)
        XCTAssertEqual(
            LiveActivityPolicy.decide(existing: [live], today: today, now: now),
            .update(id: "live")
        )
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
        XCTAssertEqual(
            LiveActivityPolicy.decide(existing: [corpse], today: today, now: now),
            .replace
        )
    }

    // We cannot extend past iOS's 8h cap — no API does — so we rotate before it:
    // end the old activity, request a fresh one, get a clean 8h window.
    func test_activityNearingTheEightHourCap_isRotatedEarly() {
        let old = snapshot(id: "old", ageHours: 7.5)
        XCTAssertEqual(
            LiveActivityPolicy.decide(existing: [old], today: today, now: now),
            .replace
        )
    }

    func test_rotationHappensWithMarginBeforeTheCap() {
        // The margin is the point: an activity replaced at 7h59m would be dead
        // before the user ever saw it.
        XCTAssertLessThan(LiveActivityPolicy.rotateAfter, 8 * 3600)

        let justInside = snapshot(id: "ok", ageHours: 6.9)
        XCTAssertEqual(
            LiveActivityPolicy.decide(existing: [justInside], today: today, now: now),
            .update(id: "ok")
        )
    }

    // Midnight rollover: the day boundary runs in the monitor extension, which
    // cannot reach ActivityKit at all, so yesterday's activity survives the night.
    func test_yesterdaysActivity_isReplaced() {
        let yesterday = snapshot(id: "old-day", day: "2026-07-11", ageHours: 3)
        XCTAssertEqual(
            LiveActivityPolicy.decide(existing: [yesterday], today: today, now: now),
            .replace
        )
    }

    func test_picksTheUsableActivity_whenACorpseIsListedFirst() {
        let corpse = snapshot(id: "corpse", isUpdatable: false, ageHours: 9)
        let live = snapshot(id: "live", ageHours: 1)
        XCTAssertEqual(
            LiveActivityPolicy.decide(existing: [corpse, live], today: today, now: now),
            .update(id: "live")
        )
    }
}
