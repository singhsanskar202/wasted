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
            #if !targetEnvironment(simulator)
            let store = UsageStore()
            store.stampFirstLaunchIfNeeded()
            let displayNames = loadDisplayNames()
            ReceiptScheduler().refresh(
                usage: store.loadTodayUsage(),
                displayNames: displayNames
            )
            startLiveActivityIfNeeded(store: store, displayNames: displayNames)
            #endif
        }
    }

    // Activity.request() only succeeds from the main app process — the
    // DeviceActivityMonitor extension always gets .unsupportedTarget. This is
    // the one place that can create the first activity of the day; once one
    // exists, the extension's own calls land on the update-existing path.
    private func startLiveActivityIfNeeded(store: UsageStore, displayNames: [String: String]) {
        let manager = LiveActivityManager()
        guard !manager.hasActiveActivity else { return }

        let trialState = TrialClock.state(firstLaunch: store.firstLaunchDate(), unlocked: store.isUnlocked())
        guard trialState != .expired else { return }

        let usage = store.loadTodayUsage()
        guard let topApp = usage.seconds.max(by: { $0.value < $1.value }), topApp.value > 0 else { return }

        manager.startOrUpdate(
            bundleId: topApp.key,
            appName: displayNames[topApp.key] ?? "App \(topApp.key)",
            totalSeconds: topApp.value
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
