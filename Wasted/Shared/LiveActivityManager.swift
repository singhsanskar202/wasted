import ActivityKit
import Foundation

// Activity.request() can only succeed from the main app process — the
// DeviceActivityMonitor extension always gets .unsupportedTarget. The main
// app is responsible for the *first* start each session (triggered on
// foreground); once an activity exists, the extension's calls here land on
// the "update existing" branch instead.
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
                    ActivityContent(state: state, staleDate: Date(timeIntervalSinceNow: 2700))
                )
                logDebug("updated existing activity id=\(existing.id) total=\(totalSeconds)")
            }
        } else {
            let attributes = TimeTrackerAttributes(appBundleId: bundleId, appName: appName)
            let content = ActivityContent(state: state, staleDate: Date(timeIntervalSinceNow: 2700))
            let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
            do {
                let activity = try Activity<TimeTrackerAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                logDebug("request OK id=\(activity.id) areActivitiesEnabled=\(enabled) total=\(totalSeconds)")
            } catch {
                logDebug("request FAILED: \(error) areActivitiesEnabled=\(enabled)")
            }
        }
    }

    func endAllActivities() {
        for activity in Activity<TimeTrackerAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    // Awaits the end so a caller can guarantee a truly fresh .request() next,
    // rather than racing endAllActivities()'s fire-and-forget Tasks.
    func endAllActivitiesAndWait() async {
        for activity in Activity<TimeTrackerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    var hasActiveActivity: Bool {
        !Activity<TimeTrackerAttributes>.activities.isEmpty
    }

    // TEMPORARY diagnostic — remove once Live Activity start is confirmed
    // working on device. Keeps the last few entries so repeated threshold
    // fires don't overwrite the evidence.
    private func logDebug(_ message: String) {
        guard let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID) else { return }
        let entry = "\(Date()): \(message)"
        let previous = (defaults.string(forKey: "debug_live_activity_log") ?? "")
            .components(separatedBy: "\n---\n")
        let combined = ([entry] + previous).prefix(8).joined(separator: "\n---\n")
        defaults.set(combined, forKey: "debug_live_activity_log")
    }
}
