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

        if parts[0] == AppGroupKeys.totalEventPrefix {
            handleTotalThreshold(minutes: minutes)
            return
        }

        let appIndex = parts[0]
        let totalSeconds = minutes * 60
        let appName = resolveDisplayName(for: appIndex)
        LiveActivityManager.log("threshold fired \(event.rawValue) app=\(appIndex) min=\(minutes)")

        // Recording never stops — trial gating only affects what's surfaced.
        // Hourly heatmap attribution deliberately NOT here: the combined
        // "total:N" series covers the same usage at minute fidelity, and
        // adding both would double count.
        let current = store.loadTodayUsage().totalSeconds(for: appIndex)
        let delta = totalSeconds > current ? totalSeconds - current : 0
        if delta > 0 {
            store.addSeconds(delta, for: appIndex)
        }

        let trialState = TrialClock.state(firstLaunch: store.firstLaunchDate(), unlocked: store.isUnlocked())
        if trialState != .expired {
            if NudgeGate.shouldNudge(minutes: minutes, last: store.lastNudge(for: appIndex)) {
                notificationScheduler.scheduleNudge(appName: appName, minutes: minutes)
                store.recordNudge(minutes: minutes, for: appIndex)
            }

            receiptScheduler.refresh(usage: store.loadTodayUsage(), displayNames: allDisplayNames())
        }

        let total = store.totalSecondsAllApps()
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(total / 60)
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
                totalSeconds: total,
                capSeconds: AppGroupKeys.staleSeconds(afterTotalSeconds: total)
            )
        }
    }

    // The combined series is the island's heartbeat: every minute of usage
    // across all tracked apps lands here with the exact new total.
    private func handleTotalThreshold(minutes: Int) {
        let newTotal = minutes * 60
        let stored = store.combinedSecondsToday()
        // includesPastActivity can replay every already-passed threshold in a
        // burst after a mid-day selection change — only the high-water mark
        // does real work, so the burst costs almost nothing.
        guard newTotal > stored else { return }
        store.setCombinedSecondsToday(newTotal)
        store.addHourlySeconds(newTotal - stored)
        LiveActivityManager.log("total threshold \(minutes)m")

        let total = store.totalSecondsAllApps()
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(total / 60)
        }
        WidgetCenter.shared.reloadAllTimelines()

        let trialState = TrialClock.state(firstLaunch: store.firstLaunchDate(), unlocked: store.isUnlocked())
        if trialState != .expired {
            // Blocking and last, same as the per-app path.
            liveActivityManager.updateExistingAndWait(
                totalSeconds: total,
                capSeconds: AppGroupKeys.staleSeconds(afterTotalSeconds: total)
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
