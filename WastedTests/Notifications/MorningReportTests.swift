import XCTest
@testable import Wasted

final class MorningReportTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            timeZone: TimeZone(identifier: "UTC"),
            year: 2026, month: 7, day: day, hour: hour, minute: minute
        ))!
    }

    // THE BUG THIS GUARDS: the report always describes "yesterday" from the
    // READER's point of view. Before 8am the next firing is TODAY, so it must
    // carry the archived previous day. After 8am the next firing is TOMORROW, so
    // it must carry the day that is running now.
    //
    // Get that backwards and a threshold at 6:30am would reschedule this morning's
    // pending notification to tomorrow — and the report would silently never
    // arrive, which is the worst kind of bug: nothing crashes, it just never comes.
    func test_beforeEight_theNextFiringIsToday() {
        let fire = MorningReport.nextFireDate(after: date(14, 6, 30), calendar: calendar)
        XCTAssertEqual(fire, date(14, 8))
    }

    func test_afterEight_theNextFiringIsTomorrow() {
        let fire = MorningReport.nextFireDate(after: date(14, 9, 15), calendar: calendar)
        XCTAssertEqual(fire, date(15, 8))
    }

    func test_exactlyEight_rollsToTomorrow_soItCannotFireTwice() {
        let fire = MorningReport.nextFireDate(after: date(14, 8), calendar: calendar)
        XCTAssertEqual(fire, date(15, 8))
    }

    // MARK: - The copy

    // It CARRIES the number. It never asks for a tap.
    //
    // The moment a notification's real job is to get the app opened — to revive a
    // Live Activity, say — it stops being a mirror and becomes the attention
    // farming this product exists to argue against. This one is complete on the
    // Lock Screen; opening the app is a side effect, not the point.
    func test_theBodyNeverAsksForATap() {
        let cta = ["tap", "open", "see your", "check your", "view", "learn more"]
        for minutes in [1, 20, 45, 90, 150, 300, 600] {
            let body = MorningReport.body(seconds: minutes * 60).lowercased()
            for phrase in cta {
                XCTAssertFalse(body.contains(phrase), "call to action at \(minutes)m: \(body)")
            }
        }
    }

    func test_theBodyCarriesTheNumber() {
        XCTAssertTrue(MorningReport.body(seconds: 90 * 60).hasPrefix("1h 30m"))
        XCTAssertTrue(MorningReport.body(seconds: 20 * 60).hasPrefix("20m"))
    }

    // Past four hours the equivalent stops comparing and states the annual cost —
    // and it's two lines, which must be flattened for a notification body.
    func test_theBodyIsASingleLine() {
        for minutes in [20, 90, 300, 600] {
            let body = MorningReport.body(seconds: minutes * 60)
            XCTAssertFalse(body.contains("\n"), "notification body wrapped: \(body)")
        }
        XCTAssertTrue(MorningReport.body(seconds: 300 * 60).contains("days a year"))
    }
}
