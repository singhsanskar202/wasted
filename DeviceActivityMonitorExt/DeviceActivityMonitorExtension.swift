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
    let morningReport = MorningReport()

    // The day boundary. If these two stop firing, EVERY downstream surface
    // silently keeps yesterday's numbers — and until now nothing recorded
    // whether they fired at all.
    override func intervalDidStart(for activity: DeviceActivityName) {
        EventLog.log(.monitor, "intervalDidStart — new day begins")
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
        }
        guard let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID) else {
            EventLog.error(.monitor, "intervalDidStart: App Group UNREACHABLE")
            return
        }
        let count = defaults.integer(forKey: AppGroupKeys.daysTrackedKey)
        defaults.set(count + 1, forKey: AppGroupKeys.daysTrackedKey)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        let today = store.loadTodayUsage()
        EventLog.log(.monitor, "intervalDidEnd — archiving \(today.date) total=\(today.seconds.values.reduce(0, +))s")
        store.archiveToHistory(today)
        // Known no-op: ActivityKit is unreachable from this process, so the
        // island survives midnight regardless. The view resets itself instead
        // (staleDate pinned to midnight + a day check).
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
        else {
            // An unparseable event name means the registration and this parser
            // disagree — usage would silently stop being recorded.
            EventLog.error(.monitor, "UNPARSEABLE event name '\(event.rawValue)' — usage not recorded")
            return
        }

        if parts[0] == AppGroupKeys.totalEventPrefix {
            handleTotalThreshold(minutes: minutes)
            return
        }

        let appIndex = parts[0]
        let totalSeconds = minutes * 60
        let appName = resolveDisplayName(for: appIndex)
        EventLog.log(.monitor, "per-app threshold \(event.rawValue) app=\(appIndex) min=\(minutes)")

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
                // Pick a line today hasn't spent yet, then burn it — a nudge the
                // user has already read is a nudge they scroll past.
                let line = NudgeCopy.next(minutes: minutes, used: store.usedNudgeLines())
                notificationScheduler.scheduleNudge(appName: appName, minutes: minutes, body: line.text)
                store.markNudgeLine(line.id)
                store.recordNudge(minutes: minutes, for: appIndex)
                EventLog.log(.nudge, "SENT at \(minutes)m app=\(appIndex) line=\(line.id) \"\(line.text)\"")
            } else {
                // Logging the SUPPRESSED case matters as much as the sent one:
                // "why did I not get a nudge?" is unanswerable without it, and
                // the gate has three separate reasons to stay quiet.
                EventLog.log(.nudge, "suppressed at \(minutes)m app=\(appIndex) (last=\(store.lastNudge(for: appIndex)?.minutes.description ?? "none"))")
            }

            receiptScheduler.refresh(usage: store.loadTodayUsage(), displayNames: allDisplayNames())
            // Yesterday's bill, delivered tomorrow morning while the day can still
            // be changed. A local notification carries STATIC content, so the only
            // way its number can be right is to keep replacing it with a fresher one.
            morningReport.refresh(store: store)
        } else {
            EventLog.log(.trial, "EXPIRED — recording continues, nudges/island suppressed")
        }

        let total = store.totalSecondsAllApps()
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(total / 60)
        }

        // The island cannot be pushed from this process — ActivityKit is
        // unreachable here — so publish the total for its view to PULL at render
        // time instead.
        store.publishLiveTotal()

        WidgetCenter.shared.reloadAllTimelines()
        EventLog.log(.widget, "reload requested from extension total=\(total)s")

        if trialState != .expired {
            // The island shows the grand total across all tracked apps, not
            // this one app's slice. A no-op in practice — ActivityKit is
            // unreachable from this process — so it stays LAST, after the work
            // that does land (nudge, receipt, badge, widget).
            liveActivityManager.updateExistingAndWait(totalSeconds: total)
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
        guard newTotal > stored else {
            // A replayed threshold (includesPastActivity re-fires everything
            // already passed after a re-registration). Logged because a FLOOD of
            // these is the signature of the schedule being re-registered in a
            // loop — which would be a real bug and is otherwise invisible.
            EventLog.log(.monitor, "combined threshold \(minutes)m REPLAYED (stored=\(stored / 60)m)")
            return
        }
        store.setCombinedSecondsToday(newTotal)
        store.addHourlySeconds(newTotal - stored)
        EventLog.log(.monitor, "combined threshold \(minutes)m (+\((newTotal - stored) / 60)m)")

        let total = store.totalSecondsAllApps()
        store.publishLiveTotal()
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(total / 60)
        }
        WidgetCenter.shared.reloadAllTimelines()

        let trialState = TrialClock.state(firstLaunch: store.firstLaunchDate(), unlocked: store.isUnlocked())
        if trialState != .expired {
            // Blocking and last, same as the per-app path.
            liveActivityManager.updateExistingAndWait(totalSeconds: total)
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
