import DeviceActivity
import Foundation
import UserNotifications
import WidgetKit

// The system wakes this extension when registered apps hit usage thresholds.
// Event name format: "index:minutes" e.g. "0:60" — set by ActivityScheduler.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    let store = UsageStore()
    let liveActivityManager = LiveActivityManager()
    let notificationScheduler = NotificationScheduler()

    override func intervalDidStart(for activity: DeviceActivityName) {
        // New day — reset badge and increment days-tracked counter
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
        }
        guard let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID) else { return }
        let count = defaults.integer(forKey: AppGroupKeys.daysTrackedKey)
        defaults.set(count + 1, forKey: AppGroupKeys.daysTrackedKey)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        // Archive completed day into history before clearing
        let today = store.loadTodayUsage()
        store.archiveToHistory(today)
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
        let delta = totalSeconds > current ? totalSeconds - current : 0
        if delta > 0 {
            store.addSeconds(delta, for: appIndex)
            store.addHourlySeconds(delta)
        }

        liveActivityManager.startOrUpdate(
            bundleId: appIndex,
            appName: appName,
            totalSeconds: totalSeconds
        )

        if minutes % 60 == 0 {
            let hours = minutes / 60
            notificationScheduler.scheduleHourlyMilestone(
                appName: appName,
                hours: hours,
                totalSeconds: store.totalSecondsAllApps()
            )
        }

        let totalMinutes = store.totalSecondsAllApps() / 60
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(totalMinutes)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Private

    private func resolveDisplayName(for index: String) -> String {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = defaults.data(forKey: AppGroupKeys.displayNamesKey),
            let names = try? JSONDecoder().decode([String: String].self, from: data)
        else { return "App \(index)" }
        return names[index] ?? "App \(index)"
    }
}
