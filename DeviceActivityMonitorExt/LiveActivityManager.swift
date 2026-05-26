import ActivityKit
import Foundation

final class LiveActivityManager {

    func startOrUpdate(bundleId: String, appName: String, totalSeconds: Int) {
        // accumulatedStart = now - totalSeconds
        // Text(accumulatedStart, style: .timer) then shows totalSeconds + live elapsed
        let accumulatedStart = Date(timeIntervalSinceNow: -Double(totalSeconds))

        let state = TimeTrackerAttributes.ContentState(
            appBundleId: bundleId,
            appName: appName,
            accumulatedStart: accumulatedStart,
            isActive: true
        )

        // End any activity for a different app
        for activity in Activity<TimeTrackerAttributes>.activities
        where activity.attributes.appBundleId != bundleId {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }

        // Update existing activity for this app, or start a new one
        if let existing = Activity<TimeTrackerAttributes>.activities
            .first(where: { $0.attributes.appBundleId == bundleId }) {
            Task {
                await existing.update(
                    ActivityContent(state: state, staleDate: Date(timeIntervalSinceNow: 300))
                )
            }
        } else {
            let attributes = TimeTrackerAttributes(appBundleId: bundleId, appName: appName)
            let content = ActivityContent(state: state, staleDate: Date(timeIntervalSinceNow: 300))
            try? Activity<TimeTrackerAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        }
    }

    func endAllActivities() {
        for activity in Activity<TimeTrackerAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
