import SwiftUI

@main
struct WastedApp: App {
    @AppStorage("onboarding_complete") private var onboardingComplete = false
    @Environment(\.scenePhase) private var scenePhase

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
            guard phase == .active else { return }
            let store = UsageStore()
            store.stampFirstLaunchIfNeeded()
            let displayNames = loadDisplayNames()
            ReceiptScheduler().refresh(
                usage: store.loadTodayUsage(),
                displayNames: displayNames
            )
            Task { await refreshLiveActivity(store: store) }
        }
    }

    // Activity.request() only succeeds from the main app process — the
    // DeviceActivityMonitor extension always gets .unsupportedTarget. So the
    // main app both creates the daily activity and, on every foreground,
    // refreshes it: pushing its stale date forward and correcting the total.
    // Being in Wasted is not being in a tracked app, so isLive is false — the
    // island shows the exact total statically until a threshold proves active
    // usage again. Now that all ActivityKit calls are awaited (no racing
    // fire-and-forget Tasks), running this on every foreground is safe.
    private func refreshLiveActivity(store: UsageStore) async {
        let trialState = TrialClock.state(firstLaunch: store.firstLaunchDate(), unlocked: store.isUnlocked())
        guard trialState != .expired else { return }

        // Optimistic ticking: the island can't be updated from the background,
        // so on every foreground we re-anchor to the exact total and let it
        // tick up on its own (bounded by optimisticTickCapSeconds). isLive only
        // once there's real usage, so a fresh 0m start never fakes time.
        let total = store.totalSecondsAllApps()
        await LiveActivityManager().startOrUpdate(
            totalSeconds: total,
            isLive: total > 0
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
