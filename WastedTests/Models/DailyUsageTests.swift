import XCTest
@testable import Wasted

final class DailyUsageTests: XCTestCase {

    func test_encodeDecode_roundtrip() throws {
        var usage = DailyUsage(date: "2026-05-25")
        usage.add(seconds: 3600, for: "com.instagram.instagrammobile")
        usage.add(seconds: 900, for: "net.whatsapp.WhatsApp")

        let data = try JSONEncoder().encode(usage)
        let decoded = try JSONDecoder().decode(DailyUsage.self, from: data)

        XCTAssertEqual(decoded, usage)
    }

    func test_totalSeconds_returnsZero_whenAppNotPresent() {
        let usage = DailyUsage(date: "2026-05-25")
        XCTAssertEqual(usage.totalSeconds(for: "com.unknown.app"), 0)
    }

    func test_addSeconds_accumulatesForSameApp() {
        var usage = DailyUsage(date: "2026-05-25")
        usage.add(seconds: 1800, for: "com.instagram.instagrammobile")
        usage.add(seconds: 900, for: "com.instagram.instagrammobile")
        XCTAssertEqual(usage.totalSeconds(for: "com.instagram.instagrammobile"), 2700)
    }

    func test_todayString_matchesCurrentDate() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        XCTAssertEqual(DailyUsage.todayString(), formatter.string(from: Date()))
    }

    // #5: hourly must always end up 24 slots, so the direct indexers (addHourly,
    // InsightEngine's yesterday-peak) can never run off the end of a malformed
    // stored array.
    func test_normalizedHourly_padsShort_truncatesLong_preservesExact() {
        XCTAssertEqual(DailyUsage.normalizedHourly([]).count, 24)
        XCTAssertEqual(DailyUsage.normalizedHourly([1, 2, 3]).count, 24)
        XCTAssertEqual(DailyUsage.normalizedHourly([1, 2, 3])[0], 1)
        XCTAssertEqual(DailyUsage.normalizedHourly([1, 2, 3])[2], 3)
        XCTAssertEqual(DailyUsage.normalizedHourly(Array(repeating: 9, count: 100)).count, 24)
        let exact = Array(0..<24)
        XCTAssertEqual(DailyUsage.normalizedHourly(exact), exact)
    }

    func test_decode_shortHourly_normalizesAndIndexingTopHourIsSafe() throws {
        let json = #"{"date":"2026-05-25","seconds":{},"hourly":[1,2,3]}"#
        var decoded = try JSONDecoder().decode(DailyUsage.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.hourly.count, 24)
        // Would have been an out-of-bounds crash before normalization.
        decoded.addHourly(60, hour: 23)
        XCTAssertEqual(decoded.hourly[23], 60)
    }

    // #1: the day key is Gregorian ASCII regardless of format, so it stays
    // comparable with archived keys and the push server's Gregorian `day`.
    func test_dateString_isGregorianAsciiForKnownDate() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 27; comps.hour = 12
        let date = Calendar(identifier: .gregorian).date(from: comps)!
        let s = DailyUsage.dateString(from: date)
        XCTAssertEqual(s.count, 10)
        XCTAssertTrue(s.hasPrefix("2026-"))
        XCTAssertTrue(s.allSatisfy { $0.isNumber || $0 == "-" })
    }
}
