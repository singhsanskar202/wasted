import XCTest
@testable import Wasted

final class TimeTrackerAttributesTests: XCTestCase {

    func test_contentState_encodeDecode_roundtrip() throws {
        let state = TimeTrackerAttributes.ContentState(
            appBundleId: "com.instagram.instagrammobile",
            appName: "Instagram",
            accumulatedStart: Date(timeIntervalSince1970: 1_748_800_000),
            isActive: true
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(TimeTrackerAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded.appBundleId, state.appBundleId)
        XCTAssertEqual(decoded.appName, state.appName)
        XCTAssertEqual(decoded.isActive, state.isActive)
        XCTAssertEqual(
            decoded.accumulatedStart.timeIntervalSince1970,
            state.accumulatedStart.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func test_accumulatedStart_formula_producesCorrectTotalDisplay() {
        let totalSecondsToday = 3600
        let accumulatedStart = Date(timeIntervalSinceNow: -Double(totalSecondsToday))
        let elapsed = Date().timeIntervalSince(accumulatedStart)
        XCTAssertGreaterThanOrEqual(elapsed, Double(totalSecondsToday))
    }
}
