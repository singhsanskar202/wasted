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
    let receiptScheduler = ReceiptScheduler()

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
        liveActivityManager.endAllActivitiesAndWait()
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
        LiveActivityManager.log("threshold fired \(event.rawValue) app=\(appIndex) min=\(minutes)")

        // Recording never stops — trial gating only affects what's surfaced.
        let current = store.loadTodayUsage().totalSeconds(for: appIndex)
        let delta = totalSeconds > current ? totalSeconds - current : 0
        if delta > 0 {
            store.addSeconds(delta, for: appIndex)
            store.addHourlySeconds(delta)
        }

        let trialState = TrialClock.state(firstLaunch: store.firstLaunchDate(), unlocked: store.isUnlocked())
        if trialState != .expired {
            if NudgeGate.shouldNudge(minutes: minutes, last: store.lastNudge(for: appIndex)) {
                notificationScheduler.scheduleNudge(appName: appName, minutes: minutes)
                store.recordNudge(minutes: minutes, for: appIndex)
            }

            receiptScheduler.refresh(usage: store.loadTodayUsage(), displayNames: allDisplayNames())
        }

        let totalMinutes = store.totalSecondsAllApps() / 60
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(totalMinutes)
        }

        WidgetCenter.shared.reloadAllTimelines()

        if trialState != .expired {
            // The island shows the grand total across all tracked apps, not
            // this one app's slice. Blocking: the extension is suspended the
            // instant this callback returns, so a fire-and-forget async update
            // would be dropped. Deliberately LAST — it may poll several seconds
            // for .activities to sync into this fresh process, and if the
            // system kills the callback mid-wait, only this (already-failing)
            // update is lost, never the nudge/receipt/badge work above.
            liveActivityManager.updateExistingAndWait(
                totalSeconds: store.totalSecondsAllApps()
            )
        }
    }

    // MARK: - Private

    private func resolveDisplayName(for index: String) -> String {
        allDisplayNames()[index] ?? "App \(index)"
    }

    private func allDisplayNames() -> [String: String] {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = defaults.data(forKey: AppGroupKeys.displayNamesKey),
            let names = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return names
    }
}
