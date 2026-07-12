import XCTest
@testable import Wasted

final class ThresholdTests: XCTestCase {

    func test_everyPlan_isStrictlyAscending() {
        for plan in ThresholdPlan.ladder {
            for series in [plan.combined, plan.perApp] {
                // The last-resort plan has an EMPTY per-app series by design, so
                // this must not assume a non-empty one.
                for i in series.indices.dropFirst() {
                    XCTAssertGreaterThan(series[i], series[i - 1], "\(plan.name) is not ascending")
                }
            }
        }
    }

    // A plan that skips a 15-minute multiple silently swallows that nudge — the
    // gate can only see thresholds that were actually registered. The last-resort
    // plan is exempt because it has no per-app series AT ALL, and says so.
    func test_everyAppTrackingPlan_landsOnEveryNudgeStep() {
        for plan in ThresholdPlan.ladder where plan.tracksIndividualApps {
            XCTAssertTrue(plan.coversNudgeSteps, "\(plan.name) misses a nudge step")
        }
    }

    // The old grids stopped at 480 minutes, so a day heavier than 8h froze the
    // number at 8h forever — the worst failure an app built on "the number only
    // goes up" can have.
    func test_everyPlan_runsToTwelveHours() {
        for plan in ThresholdPlan.ladder {
            XCTAssertEqual(plan.combined.last, 720, "\(plan.name) combined stops early")
            if plan.tracksIndividualApps {
                XCTAssertEqual(plan.perApp.last, 720, "\(plan.name) per-app stops early")
            }
        }
    }

    // AUDIT P1: if every plan was rejected, the day silently recorded NOTHING.
    // Per-app events are the expensive ones — their count is multiplied by the
    // number of tracked apps — so someone tracking a lot of apps could blow
    // DeviceActivity's cap on the per-app series alone and lose the whole day.
    //
    // The floor of the ladder now gives up the per-app series and keeps the
    // combined one: no nudges, no receipt breakdown, but the number, the island,
    // the widget and the heatmap all survive. A degraded day beats a blank one.
    func test_theLadderEndsInAPlanThatCannotBeBlownOutByAppCount() {
        let last = ThresholdPlan.ladder.last!
        XCTAssertEqual(last.name, "total-only")
        XCTAssertFalse(last.tracksIndividualApps)

        // Its cost is FIXED — tracking 1 app or 50 costs exactly the same.
        XCTAssertEqual(last.eventCount(appCount: 1), last.eventCount(appCount: 50))
    }

    // The whole point of a ladder is that each rung is genuinely cheaper. At high
    // app counts the per-app series dominates, and that's exactly when the cap
    // bites — so the shrink has to hold there too, not just at 1–5 apps.
    func test_ladderStillShrinksWhenTheUserTracksManyApps() {
        for appCount in [1, 5, 10, 25, 50] {
            let costs = ThresholdPlan.ladder.map { $0.eventCount(appCount: appCount) }
            for i in 1..<costs.count {
                XCTAssertLessThan(
                    costs[i], costs[i - 1],
                    "ladder stopped shrinking at \(appCount) apps: \(costs)"
                )
            }
        }
    }

    // The ladder only means anything if each rung is genuinely cheaper than the
    // one above — otherwise a rejected plan falls back to an equally rejected one.
    func test_ladder_getsStrictlyCheaperAtEveryStep() {
        for appCount in 1...5 {
            let costs = ThresholdPlan.ladder.map { $0.eventCount(appCount: appCount) }
            for i in 1..<costs.count {
                XCTAssertLessThan(costs[i], costs[i - 1], "ladder does not shrink at \(appCount) apps")
            }
        }
    }

    func test_finePlan_firesEveryMinuteForTheFirstEightHours() {
        XCTAssertEqual(Array(ThresholdPlan.fine.combined.prefix(480)), Array(1...480))
    }

    // The reported bug: at ~2h50m the widget updated every 5-8 minutes, because
    // that band was on 2-minute steps. Every plan now covers 2h50m at 1-minute
    // spacing or better.
    func test_everyPlan_hasMinuteFidelityWhereTheUserNoticedTheLag() {
        for plan in ThresholdPlan.ladder {
            XCTAssertEqual(Array(plan.combined.prefix(120)), Array(1...120), "\(plan.name)")
        }
        XCTAssertTrue(ThresholdPlan.fine.combined.contains(170))
        XCTAssertTrue(ThresholdPlan.medium.combined.contains(170))
    }

    // The island's promise is a true lower bound — round down, never up.
    func test_formattedDuration_floorsPartialMinutes_neverOverstates() {
        XCTAssertEqual(AppGroupKeys.formattedDuration(119), "1m")
        XCTAssertEqual(AppGroupKeys.formattedDuration(3599), "59m")
    }
}
