import DeviceActivity
import Foundation

// The system wakes this extension when registered apps hit usage thresholds.
// Event name format: "index:minutes" e.g. "0:60" — set by ActivityScheduler.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    let store = UsageStore()
    let liveActivityManager = LiveActivityManager()
    let notificationScheduler = NotificationScheduler()

    override func intervalDidStart(for activity: DeviceActivityName) {
        // New day started. UsageStore.loadTodayUsage() auto-creates fresh daily usage.
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        liveActivityManager.endAllActivities()
        store.clearActiveApp()
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        let parts = event.rawValue.components(separatedBy: ":")
        guard parts.count == 2,
              let minutes = Int(parts[1]),
              minutes > 0
        else { return }

        let appIndex = parts[0]
        let totalSeconds = minutes * 60
        let appName = resolveDisplayName(for: appIndex)

        let current = store.loadTodayUsage().totalSeconds(for: appIndex)
        if totalSeconds > current {
            store.addSeconds(totalSeconds - current, for: appIndex)
        }

        liveActivityManager.startOrUpdate(
            bundleId: appIndex,
            appName: appName,
            totalSeconds: totalSeconds
        )

        if minutes % 60 == 0 {
            let hours = minutes / 60
            notificationScheduler.scheduleHourlyMilestone(appName: appName, hours: hours)
        }
    }

    // MARK: - Private

    private func resolveDisplayName(for index: String) -> String {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = defaults.data(forKey: "display_names"),
            let names = try? JSONDecoder().decode([String: String].self, from: data)
        else { return "App \(index)" }
        return names[index] ?? "App \(index)"
    }
}
