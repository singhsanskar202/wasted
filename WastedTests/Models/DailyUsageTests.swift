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
        formatter.dateFormat = "yyyy-MM-dd"
        XCTAssertEqual(DailyUsage.todayString(), formatter.string(from: Date()))
    }
}
