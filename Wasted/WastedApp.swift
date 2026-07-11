import BackgroundTasks
import SwiftUI

@main
struct WastedApp: App {
    @AppStorage("onboarding_complete") private var onboardingComplete = false
    @Environment(\.scenePhase) private var scenePhase

    // iOS ends a Live Activity ~8h after its last update, and we can only
    // update from this process (foreground or this background task). Touching
    // the activity here resets that clock, so the island survives longer
    // between app opens. iOS grants these on its own schedule (not guaranteed),
    // so it's a best-effort extension, not a cure.
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
                // DeviceActivity never records in the simulator — seed a
                // realistic total so the island/lock screen render with real
                // digits for visual verification.
                if store.combinedSecondsToday() == 0 {
                    store.setCombinedSecondsToday(118 * 60)
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

        // Every anchor restarts the island's self-advancing window. capSeconds
        // = 0 until there's real usage, so a fresh 0m island never fakes time.
        let total = store.totalSecondsAllApps()
        await LiveActivityManager().startOrUpdate(
            totalSeconds: total,
            capSeconds: total > 0 ? LiveActivityManager.optimisticTickCapSeconds : 0
        )
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
