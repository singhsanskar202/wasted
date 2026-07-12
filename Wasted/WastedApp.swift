import BackgroundTasks
import SwiftUI

@main
struct WastedApp: App {
    @AppStorage("onboarding_complete") private var onboardingComplete = false
    @Environment(\.scenePhase) private var scenePhase

    // iOS ends a Live Activity 8h after it was CREATED. Updating it does not
    // reset that clock — this comment used to claim it did, which is what
    // produced the "one activity, all day" design and the vanishing island.
    // The only way to persist is to end the old activity and request a new one
    // (LiveActivityPolicy.rotateAfter), and only THIS process can do either.
    // So every run of the app — foreground or this background task — is a
    // chance to rotate before the guillotine. iOS grants these at its own
    // discretion, so it's a safety net, not a cure: an app left unopened for
    // more than 8h will lose its island until it's next opened.
    static let bgRefreshID = "com.sanskar.Wasted.refresh"

    var body: some Scene {
        WindowGroup {
            #if targetEnvironment(simulator)
            HomeView()
            #else
            if onboardingComplete {
                HomeView()
            } else {
                OnboardingContainerView {
                    onboardingComplete = true
                }
            }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            // This app hosts the unit tests: requesting a Live Activity at
            // launch pops the system permission dialog, which hangs the test
            // runner before it can connect. No side effects under test.
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
            switch phase {
            case .active:
                // Re-registers the DeviceActivity events if this build changed
                // their shape — otherwise devices keep the old schedule until
                // the user happens to re-pick their apps.
                ActivityScheduler.shared.refreshRegistrationIfNeeded()
                let store = UsageStore()
                store.stampFirstLaunchIfNeeded()
                #if targetEnvironment(simulator)
                // DeviceActivity never records in the simulator, so every
                // usage-driven surface renders empty and can't be judged. Seed a
                // realistically BURSTY day — the device logs showed real usage
                // arrives in clumps, not a smooth curve — with one hour over the
                // 1h mark, so the hour strip's single red bar can be verified as
                // scarce rather than decorative.
                if store.combinedSecondsToday() == 0 {
                    let minutesByHour = [8: 6, 9: 12, 12: 20, 13: 15, 17: 9, 21: 62, 22: 21]
                    var usage = store.loadTodayUsage()
                    for (hour, minutes) in minutesByHour {
                        usage.addHourly(minutes * 60, hour: hour)
                    }
                    let total = minutesByHour.values.reduce(0, +) * 60
                    usage.add(seconds: total, for: "0")
                    store.save(usage)
                    store.setCombinedSecondsToday(total)
                }
                #endif
                let displayNames = loadDisplayNames()
                ReceiptScheduler().refresh(
                    usage: store.loadTodayUsage(),
                    displayNames: displayNames
                )
                Task { await refreshLiveActivity(store: store) }
            case .background:
                scheduleAppRefresh()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(Self.bgRefreshID)) {
            await handleAppRefresh()
        }
    }

    // MARK: - Background refresh

    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.bgRefreshID)
        // Ask as early as iOS allows — each granted run re-anchors the island
        // to the exact total and restarts its self-advancing window, so more
        // grants = tighter island↔app sync. iOS budgets the actual cadence
        // (a few per hour at best); asking early costs nothing.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleAppRefresh() async {
        scheduleAppRefresh()               // chain the next one
        let store = UsageStore()
        await refreshLiveActivity(store: store)
    }

    // Activity.request() only succeeds from the main app process — the
    // DeviceActivityMonitor extension always gets .unsupportedTarget. So the
    // main app both creates the daily activity and, on every foreground,
    // refreshes it: pushing its stale date forward and correcting the total.
    // Now that all ActivityKit calls are awaited (no racing fire-and-forget
    // Tasks), running this on every foreground is safe.
    private func refreshLiveActivity(store: UsageStore) async {
        let trialState = TrialClock.state(firstLaunch: store.firstLaunchDate(), unlocked: store.isUnlocked())
        guard trialState != .expired else { return }

        // This is the ONLY process that can write to the island, so every run of
        // it — foreground or BG refresh — is the island's one chance to catch up
        // to the truth the extension has been recording all along.
        await LiveActivityManager().startOrUpdate(totalSeconds: store.totalSecondsAllApps())
    }

    private func loadDisplayNames() -> [String: String] {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = defaults.data(forKey: AppGroupKeys.displayNamesKey),
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return decoded
    }
}
