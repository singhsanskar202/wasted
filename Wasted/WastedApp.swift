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
    // (LiveActivityPolicy.foregroundRotateAfter), and only THIS process can do
    // either.
    // So every run of the app — foreground or this background task — is a
    // chance to rotate before the guillotine. iOS grants these at its own
    // discretion, so it's a safety net, not a cure: an app left unopened for
    // more than 8h will lose its island until it's next opened.
    static let bgRefreshID = "com.sanskar.Wasted.refresh"
    static let bgRotateID = "com.sanskar.Wasted.rotate"

    // SwiftUI's .backgroundTask only knows .appRefresh and URL sessions — there
    // is no BGProcessingTask variant — so the nightly rotation has to be
    // registered the old way, and BGTaskScheduler demands that happen before the
    // app finishes launching. App.init() is early enough; a .task or .onAppear
    // is not, and the registration would silently never fire.
    init() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.bgRotateID, using: nil) { task in
            Self.runRotation(task)
        }
        // Stamps build, device, iOS and the active threshold plan into the log. A
        // log arriving from someone else's phone is close to useless without them.
        EventLog.logSession()
        // A build that shipped with the paywall off should be obvious in the first
        // lines of its own log — not discovered by a user who is never asked to pay.
        if !ProGate.paywallEnabled {
            EventLog.error(.trial, "PAYWALL DISABLED — beta build. ProGate.paywallEnabled must be true to ship.")
        }
    }

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
                EventLog.log(.app, "FOREGROUND total=\(store.totalSecondsAllApps())s pro=\(ProGate.isPro(unlocked: store.isUnlocked()))")

                let displayNames = loadDisplayNames()
                ReceiptScheduler().refresh(
                    usage: store.loadTodayUsage(),
                    displayNames: displayNames
                )
                MorningReport().refresh(store: store)
                Task { await Self.refreshLiveActivity(store: store, canCreate: true) }
            case .background:
                EventLog.log(.app, "BACKGROUND — scheduling refresh + nightly rotation")
                scheduleAppRefresh()
                Self.scheduleNightlyRotation()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(Self.bgRefreshID)) {
            EventLog.log(.background, "app refresh GRANTED by iOS")
            await handleAppRefresh()
        }
    }

    // Registered in init(), fired by iOS overnight. Must always call
    // setTaskCompleted or the system stops granting the task entirely.
    private static func runRotation(_ task: BGTask) {
        let work = Task {
            EventLog.log(.background, "nightly rotation GRANTED by iOS")
            scheduleNightlyRotation()          // chain tomorrow's
            await refreshLiveActivity(store: UsageStore(), canCreate: false)
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
            EventLog.error(.background, "nightly rotation EXPIRED before it finished")
            task.setTaskCompleted(success: false)
        }
    }

    // MARK: - Background refresh
    //
    // These exist so the island survives WITHOUT asking the user to come back.
    // Only this process can create or rotate a Live Activity, and iOS culls one
    // eight hours after creation — so something has to run. The alternative
    // (a notification whose real purpose is "please open the app so our widget
    // stays warm") would spend the user's attention on our plumbing, which is
    // the exact behaviour this product exists to argue against.

    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.bgRefreshID)
        // Ask as early as iOS allows. Each granted run is a chance to rotate the
        // island before the 8h guillotine; iOS budgets the real cadence and
        // asking early costs nothing.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // The 8-hour hole in a person's day is the night they spend asleep — which
    // is exactly when iOS runs BGProcessingTask (it prefers idle, charging
    // devices). A BGAppRefresh is short and rationed; this is the one background
    // slot the system is actually generous with, and it lands precisely in the
    // gap that had the island showing yesterday's total at 6am.
    private static func scheduleNightlyRotation() {
        let request = BGProcessingTaskRequest(identifier: Self.bgRotateID)
        request.requiresNetworkConnectivity = false
        // Not requiring power: a user who doesn't charge overnight still deserves
        // a correct island in the morning. iOS will still favour idle/charging.
        request.requiresExternalPower = false
        // Just after midnight, so the run both rotates the activity and carries
        // it into the new day.
        request.earliestBeginDate = AppGroupKeys.nextMidnight().addingTimeInterval(15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleAppRefresh() async {
        scheduleAppRefresh()               // chain the next one
        Self.scheduleNightlyRotation()
        await Self.refreshLiveActivity(store: UsageStore(), canCreate: false)
    }

    // Activity.request() only succeeds from the main app process — the
    // DeviceActivityMonitor extension always gets .unsupportedTarget. So the
    // main app both creates the daily activity and, on every run, rotates or
    // refreshes it. Static because the overnight BGProcessingTask handler is
    // registered in init() and has no instance to call through.
    /// `canCreate` must be TRUE only when the app is in the FOREGROUND — iOS
    /// refuses Activity.request() from the background (two days of device logs:
    /// every failure was a background run, every success a foreground one).
    private static func refreshLiveActivity(store: UsageStore, canCreate: Bool) async {
        // This is the ONLY process that can write to the island, so every run of
        // it — foreground or BG refresh — is the island's chance to catch up to
        // the truth the extension has been recording all along.
        //
        // It is NOT the only push any more, though: HomeView keeps the island in
        // step while it's on screen, because DeviceActivity delivers thresholds
        // late and in bursts, so the total keeps climbing for seconds AFTER the
        // app came forward. Both callers go through the actor so they can't both
        // decide to create an activity at launch.
        store.publishLiveTotal()
        await LiveActivityCoordinator.shared.sync(totalSeconds: store.totalSecondsAllApps(), canCreate: canCreate)
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
