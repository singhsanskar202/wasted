import Combine
import FamilyControls
import StoreKit
import SwiftUI

// THE BILL.
//
// The receipt is the metaphor this product owns, and it spent this whole time
// buried in a sheet while the home screen showed a lonely number that couldn't
// say where it came from. A number can be argued with. An itemised bill — your
// own app icons, your own names, a total that adds up — cannot.
//
// The screen is sequenced as an ARGUMENT, not a dashboard: the mirror speaks,
// then hands you the bill, then shows you exactly which hours it was spent in
// (the only actionable thing here), then shows you a week-long pattern you can't
// see yet. That last one is what brings you back tomorrow.
struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var lifetimeStore = LifetimeStore.shared

    @State private var selection = HomeView.loadSavedSelection()
    @State private var showingPicker = false
    @State private var showingReceipt = false
    @State private var showingPaywall = false
    @State private var hourlyData = UsageStore().loadTodayHourly()
    @State private var totalSeconds = UsageStore().totalSecondsAllApps()
    @State private var appeared = false
    @State private var insightResult: InsightResult? = nil
    @State private var historicalPeak: HistoricalPeak? = nil
    @State private var trialState: TrialState = .unlocked
    @State private var realityCheck: RealityCheck? = nil
    @State private var trackingFailed = false
    @State private var trackingDegraded = false
    // The last total actually pushed to ActivityKit, so a five-second poll that
    // finds nothing new doesn't hammer the update budget.
    @State private var lastPushedTotal = -1
    // The bill, and the week's grid. Both are disk reads, so they're built once
    // per refresh rather than on every one of this view's five-second renders.
    @State private var receipt = DailyReceipt(dateString: "", items: [], totalSeconds: 0, percentOfAwakeDay: 0)
    @State private var weekDays: [DailyUsage] = []

    private let store = UsageStore()

    // The extension writes usage to the App Group only at thresholds; without
    // a poll the screen would only catch up on foreground. 5s keeps it close
    // to live while Wasted is open (the underlying data still steps at
    // thresholds, so this is as fresh as the OS makes usage available).
    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private let gutter: CGFloat = 28

    private var daysUntilPattern: Int { max(0, 7 - store.loadHistory().count) }

    private var isExpired: Bool {
        if case .expired = trialState { return true }
        return false
    }

    // FOUR BEATS, and each one earns the next.
    //
    //   1. THE VOICE      the mirror speaks, and it gets meaner as you scroll
    //   2. THE BILL       an itemised receipt. a number can be argued with —
    //                     a bill with your own app icons on it cannot
    //   3. THE ZONES      WHERE the day leaks. the only actionable thing here
    //   4. THE WEEK       locked and blurred. is this a bad evening, or a life?
    //
    // Sequenced as an argument, not a dashboard: you're confronted, shown the
    // receipt, shown where it happened, and then shown that there's a pattern you
    // can't see yet. The last one is the hook that brings you back tomorrow.
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                trackingHealth
                voice

                ZStack {
                    VStack(spacing: 0) {
                        bill
                        Rule().padding(.top, 34)
                        zones
                        Rule()
                        week
                        Rule()
                        footer
                    }
                    .blur(radius: isExpired ? 14 : 0)
                    .redacted(reason: isExpired ? .placeholder : [])
                    .allowsHitTesting(!isExpired)

                    if isExpired { expiredOverlay }
                }
            }
            .padding(.horizontal, gutter)
        }
        .background(Color.canvas.ignoresSafeArea())
        .task { await lifetimeStore.load() }
        .onAppear {
            appeared = true
            refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refresh()
        }
        .onReceive(refreshTimer) { _ in
            guard scenePhase == .active else { return }
            refresh()
        }
        // The conversion moment gets the whole screen, once, with nothing to
        // compete against — see RealityCheckView.
        .fullScreenCover(item: $realityCheck) { check in
            RealityCheckView(check: check) {
                store.setRealityCheckShown(true)
                realityCheck = nil
            }
        }
        .sheet(isPresented: $showingReceipt, onDismiss: refresh) {
            ReceiptView(receipt: DailyReceipt.build(
                usage: store.loadTodayUsage(),
                displayNames: loadDisplayNames()
            ))
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(store: lifetimeStore)
        }
    }

    // MARK: - Sections

    // The only place in this app where red is allowed to mean "something is
    // broken" rather than "this number is bad".
    //
    // If DeviceActivity rejects the event registration, the day records nothing —
    // and the failure mode is vicious: the number simply never moves. The user
    // doesn't see an error, they see a low number, and they might BELIEVE it.
    // An app whose entire promise is "you can't unsee the number" cannot quietly
    // show a false one.
    @ViewBuilder
    private var trackingHealth: some View {
        if trackingFailed {
            healthBanner(
                title: "tracking is off.",
                detail: "your phone isn't reporting usage. this number is not real.",
                action: "try again"
            ) {
                retryMonitoring()
            }
        } else if trackingDegraded {
            healthBanner(
                title: "nudges are off.",
                detail: "too many apps to track individually. the total still counts.",
                action: "track fewer apps"
            ) {
                showingPicker = true
            }
        }
    }

    private func healthBanner(
        title: String,
        detail: String,
        action: String,
        perform: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.alarm)

            Text(detail)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Color.inkQuiet)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                Haptics.light()
                perform()
            }) {
                Text(action)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.ink)
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }

    private func retryMonitoring() {
        guard !selection.applications.isEmpty else {
            showingPicker = true
            return
        }
        ActivityScheduler.shared.startMonitoring(selection: selection)
        refresh()
    }

    // THE MIRROR, SPEAKING. Not a fortune cookie: its temper comes from today's
    // real number, so it's patient at twenty minutes and it is not at four hours.
    // The line changes underneath the user as the day gets worse, which is the
    // only kind of provocation that can't be shrugged off — it knows.
    private var voice: some View {
        Text(QuoteBank.quote(forSeconds: totalSeconds))
            .font(.system(size: 15, weight: .light, design: .serif))
            .italic()
            .foregroundStyle(Color.ink.opacity(0.42))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.top, 52)
            .animation(.easeInOut(duration: 0.5), value: QuoteBank.Temper(seconds: totalSeconds))
    }

    // THE BILL. A number can be argued with. An itemised receipt — with your own
    // app icons on it, adding up to a total — cannot. This was buried in a sheet
    // while the home screen showed a lonely number that couldn't say where it came
    // from. Tapping it still opens the full receipt.
    private var bill: some View {
        ReceiptCard(
            // Built in refresh(), not here: this body re-evaluates every five
            // seconds, and building it inline meant a JSON decode off disk on
            // every single render.
            receipt: receipt,
            trueTotalSeconds: totalSeconds,
            isExpired: isExpired,
            onTap: {
                if isExpired { showingPaywall = true } else { showingReceipt = true }
            }
        )
        .padding(.top, 36)
        .opacity(appeared ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.1), value: appeared)
    }

    // WHERE IT LEAKS. The only actionable thing on the screen: the total tells you
    // that you lost time; this tells you WHEN, so "9pm is where my evening goes"
    // becomes a fact you can do something about.
    private var zones: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "danger zones")
                .padding(.top, 34)

            // An empty day is stated, not drawn. A 24-slot chart with nothing in it
            // reads as a broken component, not as "you haven't picked up your phone".
            if hourlyOrdered.contains(where: { $0 > 0 }) {
                DangerZones(hourly: hourlyOrdered)
                    .padding(.top, 22)
            } else {
                MirrorLine(text: "nothing yet today.", size: 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 16)
            }
        }
        .padding(.bottom, 34)
    }

    // IS THIS A BAD EVENING, OR A BAD LIFE? Locked and blurred until there are
    // seven days — but the data under the blur is REAL, and it fills in a little
    // more each day. The old screen faked this with random bars; curiosity built
    // on a lie is worth nothing.
    private var week: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: "your week")
                if let peak = historicalPeak {
                    Text("worst: \(InsightEngine.hourLabel(peak.startHour))–\(InsightEngine.hourLabel(peak.endHour % 24))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.alarm)
                }
            }
            .padding(.top, 34)

            WeekHeatmap(days: weekDays, daysRequired: 7)
                .frame(height: 130)
                .padding(.top, 22)
        }
        .padding(.bottom, 26)
    }

    // WHAT IT'S TRACKING, AND WHAT IT COSTS.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            LedgerRow(label: "tracking", value: trackedLabel) {
                showingPicker = true
            }
            .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
            .onChange(of: selection) { _, newValue in
                saveSelection(newValue)
                ActivityScheduler.shared.startMonitoring(selection: newValue)
            }

            if let trialDayLine {
                Text(trialDayLine)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color.ink.opacity(0.3))
                    .padding(.top, 6)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 48)
    }


    private var expiredOverlay: some View {
        VStack(spacing: 20) {
            Text("still counting.\nyou just can't see it.")
                .font(.system(size: 21, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)

            Button {
                Haptics.light()
                showingPaywall = true
            } label: {
                Text("unlock forever — \(unlockPrice)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.canvas)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 30)
                    .background(Color.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }

    // MARK: - Data

    // HourlyUsage is a sparse dictionary; the strip wants a dense 24-slot day.
    private var hourlyOrdered: [Int] {
        (0..<24).map { hourlyData.hours[$0] ?? 0 }
    }


    private var trackedLabel: String {
        let count = selection.applications.count
        return "\(count) app\(count == 1 ? "" : "s")"
    }

    private func refresh() {
        let usage = store.loadTodayUsage()
        hourlyData = store.loadTodayHourly()
        totalSeconds = store.totalSecondsAllApps()
        receipt = DailyReceipt.build(usage: usage, displayNames: loadDisplayNames())
        // Up to seven days, oldest first, TODAY LAST. History excludes today, so
        // today is appended — otherwise the newest row of the heatmap would always
        // be yesterday, the one day the user least needs to be told about.
        weekDays = store.loadHistory().suffix(6) + [usage]
        trackingFailed = store.defaults.bool(forKey: AppGroupKeys.trackingFailedKey)
        trackingDegraded = store.defaults.bool(forKey: AppGroupKeys.trackingDegradedKey)
        loadInsight()
        updateTrialState()
        updateRealityCheck()
        maybeAutoShowReceipt()
        syncIsland()
    }

    // THE ISLAND WAS FROZEN AT WHATEVER THE TOTAL HAPPENED TO BE IN THE SINGLE
    // MILLISECOND YOU FOREGROUNDED THE APP.
    //
    // Only the main app can write to the island, and it used to write exactly
    // once per foreground (scenePhase == .active). But DeviceActivity delivers
    // thresholds LATE, in bursts — the device logs proved that — so the sequence
    // was:
    //
    //   1. you scroll; the extension records the usage but cannot touch the island
    //   2. you open Wasted; the store says 6m, so the island is anchored at 6m
    //   3. over the next seconds the extension delivers the BACKLOG: 7m … 13m
    //   4. this view's five-second poll picks that up and shows 13m
    //   5. nothing ever pushes it to the island, because scenePhase never changed
    //
    // App: 13m. Island: 6m. Both reading the same store.
    //
    // So the island is kept in sync while the app is OPEN, not just when it
    // OPENS. Pushed only when the value actually moves — the total changes at
    // most once a minute, so this is nowhere near ActivityKit's update budget,
    // whereas firing on every five-second tick would be.
    private func syncIsland() {
        guard !isExpired, totalSeconds != lastPushedTotal else { return }
        lastPushedTotal = totalSeconds
        Task { await LiveActivityCoordinator.shared.sync(totalSeconds: totalSeconds) }
    }

    private func updateTrialState() {
        #if targetEnvironment(simulator)
        trialState = .unlocked
        #else
        trialState = TrialClock.state(firstLaunch: store.firstLaunchDate(), unlocked: lifetimeStore.isUnlocked)
        #endif
    }

    private func updateRealityCheck() {
        guard
            !store.isRealityCheckShown(),
            let guessSeconds = store.guessSeconds(),
            let firstDay = store.loadHistory().first
        else { return }

        let firstDayTotal = firstDay.seconds.values.reduce(0, +)
        guard let check = RealityCheck.make(guessSeconds: guessSeconds, firstFullDaySeconds: firstDayTotal) else {
            return
        }
        // Setting this presents the full-screen moment; the haptic lives in the
        // view so it fires with the reveal, not with the state change.
        realityCheck = check
        EventLog.log(.trial, "REALITY CHECK shown — \(check.guessLine) \(check.realityLine) \(check.deltaLine)")
    }

    private func maybeAutoShowReceipt() {
        guard !isExpired, realityCheck == nil else { return }
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= AppGroupKeys.receiptHour, totalSeconds > 0 else { return }
        let today = DailyUsage.todayString()
        guard store.lastReceiptAutoShowDate() != today else { return }
        store.markReceiptAutoShown(date: today)
        showingReceipt = true
    }

    private func loadInsight() {
        let history = store.loadHistory()
        insightResult = InsightEngine.analyze(
            today: store.loadTodayUsage(),
            yesterday: store.loadYesterday(),
            history: history,
            displayNames: loadDisplayNames()
        )
        historicalPeak = InsightEngine.historicalPeak(history: history)
    }

    // MARK: - Trial

    private var trialDayLine: String? {
        guard case .trial(let daysLeft) = trialState else { return nil }
        let dayNumber = TrialClock.trialDays - daysLeft + 1
        return "day \(dayNumber) of \(TrialClock.trialDays) — then it's \(unlockPrice) once."
    }

    private var unlockPrice: String {
        lifetimeStore.product?.displayPrice ?? "$9.99"
    }

    // MARK: - Persistence

    private func loadDisplayNames() -> [String: String] {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = defaults.data(forKey: AppGroupKeys.displayNamesKey),
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return decoded
    }

    private static func loadSavedSelection() -> FamilyActivitySelection {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = defaults.data(forKey: AppGroupKeys.trackedSelectionKey),
            let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return selection
    }

    private func saveSelection(_ selection: FamilyActivitySelection) {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = try? JSONEncoder().encode(selection)
        else { return }
        defaults.set(data, forKey: AppGroupKeys.trackedSelectionKey)
    }
}
