import XCTest
@testable import Wasted

final class TimeTrackerAttributesTests: XCTestCase {

    func test_contentState_encodeDecode_roundtrip() throws {
        let state = TimeTrackerAttributes.ContentState(
            accumulatedStart: Date(timeIntervalSince1970: 1_748_800_000),
            totalSeconds: 3600,
            capSeconds: 900
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(TimeTrackerAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded.totalSeconds, state.totalSeconds)
        XCTAssertEqual(decoded.capSeconds, state.capSeconds)
        XCTAssertEqual(
            decoded.accumulatedStart.timeIntervalSince1970,
            state.accumulatedStart.timeIntervalSince1970,
            accuracy: 0.001
        )
    }
}
