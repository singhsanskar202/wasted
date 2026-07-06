import XCTest
@testable import Wasted

final class DailyReceiptTests: XCTestCase {

    private func usage(date: String = "2026-07-06", seconds: [String: Int]) -> DailyUsage {
        var u = DailyUsage(date: date)
        for (id, s) in seconds { u.add(seconds: s, for: id) }
        return u
    }

    func test_build_sortsItemsLargestFirstWithResolvedNames() {
        let receipt = DailyReceipt.build(
            usage: usage(seconds: ["0": 1920, "1": 6120, "2": 3480]),
            displayNames: ["0": "X", "1": "Instagram", "2": "YouTube"]
        )
        XCTAssertEqual(receipt.items.map(\.name), ["Instagram", "YouTube", "X"])
        XCTAssertEqual(receipt.items.map(\.seconds), [6120, 3480, 1920])
    }

    func test_build_fallsBackToIndexNameAndSkipsZeroEntries() {
        let receipt = DailyReceipt.build(
            usage: usage(seconds: ["0": 600, "1": 0]),
            displayNames: [:]
        )
        XCTAssertEqual(receipt.items, [DailyReceipt.Item(name: "app 0", seconds: 600)])
    }

    func test_percentOfAwakeDay_is20PercentFor3h12m() {
        // 3h 12m = 11520s of a 16h awake day (57600s) → 20%
        let receipt = DailyReceipt.build(
            usage: usage(seconds: ["0": 11520]),
            displayNames: ["0": "Instagram"]
        )
        XCTAssertEqual(receipt.percentOfAwakeDay, 20)
        XCTAssertEqual(receipt.summaryLine, "3h 12m today — 20% of your waking hours.")
    }

    func test_percentOfAwakeDay_rounds() {
        // 1h = 3600/57600 = 6.25% → 6
        let receipt = DailyReceipt.build(usage: usage(seconds: ["0": 3600]), displayNames: [:])
        XCTAssertEqual(receipt.percentOfAwakeDay, 6)
    }

    func test_build_emptyDay() {
        let receipt = DailyReceipt.build(usage: usage(seconds: [:]), displayNames: [:])
        XCTAssertTrue(receipt.items.isEmpty)
        XCTAssertEqual(receipt.totalSeconds, 0)
        XCTAssertEqual(receipt.percentOfAwakeDay, 0)
    }

    func test_build_totalSumsAllApps() {
        let receipt = DailyReceipt.build(
            usage: usage(seconds: ["0": 1800, "1": 1800]),
            displayNames: [:]
        )
        XCTAssertEqual(receipt.totalSeconds, 3600)
    }
}
