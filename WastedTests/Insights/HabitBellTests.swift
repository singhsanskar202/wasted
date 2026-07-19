import XCTest
@testable import Wasted

// The proactive mirror only speaks when the pattern is real, the number is
// worth hearing, and the user has paid for history that arrives early.
final class HabitBellTests: XCTestCase {

    private func peak(
        startHour: Int = 21,
        daysActive: Int = 5,
        daysTotal: Int = 7,
        windowSeconds: Int = 5 * 2460   // ~41m a time
    ) -> HistoricalPeak {
        HistoricalPeak(
            startHour: startHour,
            endHour: startHour + 2,
            daysActive: daysActive,
            daysTotal: daysTotal,
            windowSeconds: windowSeconds
        )
    }

    func test_aRealHabit_getsABell_atTheWindowsOpening() {
        let plan = HabitBell.plan(peak: peak(), isPro: true)!
        XCTAssertEqual(plan.hour, 21)
        XCTAssertEqual(plan.title, "9pm–11pm")
        XCTAssertEqual(plan.body, "5 of the last 7 days, about 41m a time. today isn't written yet.")
    }

    func test_notPro_noBell() {
        XCTAssertNil(HabitBell.plan(peak: peak(), isPro: false))
    }

    func test_noPeak_noBell() {
        XCTAssertNil(HabitBell.plan(peak: nil, isPro: true))
    }

    // Two active days is a coincidence wearing a pattern's clothes.
    func test_tooFewActiveDays_noBell() {
        XCTAssertNil(HabitBell.plan(peak: peak(daysActive: 2), isPro: true))
    }

    func test_tooLittleHistory_noBell() {
        XCTAssertNil(HabitBell.plan(peak: peak(daysActive: 3, daysTotal: 4), isPro: true))
    }

    // "about 4m a time" is a bell that spends attention it can't pay back.
    func test_limpWindow_noBell() {
        XCTAssertNil(HabitBell.plan(peak: peak(windowSeconds: 5 * 200), isPro: true))
    }
}
