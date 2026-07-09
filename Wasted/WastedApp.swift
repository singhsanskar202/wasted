import FamilyControls
import SwiftUI

@main
struct WastedApp: App {
    @AppStorage("onboarding_complete") private var onboardingComplete = false
    @Environment(\.scenePhase) private var scenePhase

    // scenePhase can transition to .active more than once during a single
    // cold launch; each firing spawned an independent, unsynchronized async
    // Task. A later firing's "end all activities" could race the first
    // firing's freshly-created one and kill it before the system ever
    // rendered it. Guarding to once per process avoids that entirely.
    private static var hasAttemptedLiveActivityThisLaunch = false

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
            backfillTokensIfNeeded()
            Task { await startLiveActivityIfNeeded(store: store, displayNames: displayNames) }
        }
    }

    // Activity.request() only succeeds from the main app process — the
    // DeviceActivityMonitor extension always gets .unsupportedTarget. This is
    // the one place that can create the first activity of the day; once one
    // exists, the extension's own calls land on the update-existing path.
    private func startLiveActivityIfNeeded(store: UsageStore, displayNames: [String: String]) async {
        guard !Self.hasAttemptedLiveActivityThisLaunch else { return }
        Self.hasAttemptedLiveActivityThisLaunch = true

        let trialState = TrialClock.state(firstLaunch: store.firstLaunchDate(), unlocked: store.isUnlocked())
        guard trialState != .expired else { return }

        // Start (or refresh) the single daily activity even before any usage
        // exists — the extension can only update an existing activity, never
        // create one, so this is the only chance to get it on screen for the
        // rest of the day.
        let usage = store.loadTodayUsage()
        let topApp = usage.seconds.max(by: { $0.value < $1.value })
        // isLive: false — being in Wasted is not being in a tracked app; show
        // the exact total statically until a threshold proves active usage.
        LiveActivityManager().startOrUpdate(
            bundleId: topApp?.key ?? "",
            appName: topApp.map { displayNames[$0.key] ?? "App \($0.key)" } ?? "today",
            totalSeconds: topApp?.value ?? 0,
            isLive: false
        )
    }

    // Tokens (for real app names in the island) are stored by
    // startMonitoring, which normally only runs when the selection changes —
    // users who picked their apps before token storage existed would never
    // get them. Re-running startMonitoring is the only safe way to backfill:
    // the index<->token mapping must be built in the same call as the
    // threshold events or the island could show the wrong app's name.
    private func backfillTokensIfNeeded() {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            defaults.data(forKey: AppGroupKeys.appTokensKey) == nil,
            let data = defaults.data(forKey: AppGroupKeys.trackedSelectionKey),
            let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data),
            !selection.applications.isEmpty
        else { return }
        ActivityScheduler.shared.startMonitoring(selection: selection)
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
