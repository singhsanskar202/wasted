import XCTest
@testable import Wasted

final class ThresholdTests: XCTestCase {

    func test_everyPlan_isStrictlyAscending() {
        for plan in ThresholdPlan.ladder {
            for series in [plan.combined, plan.perApp] {
                for i in 1..<series.count {
                    XCTAssertGreaterThan(series[i], series[i - 1], "\(plan.name) is not ascending")
                }
            }
        }
    }

    // A plan that skips a 15-minute multiple silently swallows that nudge — the
    // gate can only see thresholds that were actually registered.
    func test_everyPlan_landsOnEveryNudgeStep() {
        for plan in ThresholdPlan.ladder {
            XCTAssertTrue(plan.coversNudgeSteps, "\(plan.name) misses a nudge step")
        }
    }

    // The old grids stopped at 480 minutes, so a day heavier than 8h froze the
    // number at 8h forever — the worst failure an app built on "the number only
    // goes up" can have.
    func test_everyPlan_runsToTwelveHours() {
        for plan in ThresholdPlan.ladder {
            XCTAssertEqual(plan.combined.last, 720, "\(plan.name) combined stops early")
            XCTAssertEqual(plan.perApp.last, 720, "\(plan.name) per-app stops early")
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
