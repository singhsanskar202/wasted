import Combine
import FamilyControls
import StoreKit
import SwiftUI

// THE LEDGER.
//
// One hero on the centre axis, everything else on the left axis as a ledger —
// which is the metaphor the product already owns with the receipt. No cards, no
// filled panels, no coloured banners: structure comes from whitespace and a
// single hairline. The old screen stacked eight centred blocks in six different
// surface treatments, so nothing outranked anything and the eye never found the
// number the whole app exists to show.
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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                trackingHealth
                quote

                ZStack {
                    VStack(spacing: 0) {
                        hero
                        Rule().padding(.top, 52)
                        today
                        Rule()
                        pattern
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

    private var quote: some View {
        Text(QuoteBank.todaysQuote)
            .font(.system(size: 15, weight: .light, design: .serif))
            .italic()
            .foregroundStyle(Color.ink.opacity(0.38))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.top, 56)
    }

    // The reason the app exists. It gets the top of the screen, the largest type
    // in the system, and no neighbours.
    private var hero: some View {
        VStack(spacing: 0) {
            HeroNumber(seconds: totalSeconds)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.9)
                .animation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.25).delay(0.1), value: appeared)
                .padding(.top, 44)

            Text("you wasted today")
                .font(.system(size: 12, weight: .light))
                .tracking(2)
                .foregroundStyle(Color.inkLabel)
                .padding(.top, 10)

            if let equivalent = EquivalentTaskMapper.equivalent(for: totalSeconds) {
                // The mapper returns a whole sentence now — past 4h it stops
                // comparing and states the annual cost instead, which doesn't
                // fit a "that's …" fragment.
                MirrorLine(text: equivalent.line)
                    .padding(.top, 22)
                    .transition(.opacity)
            }

            QuietButton(title: "today's receipt") {
                if isExpired { showingPaywall = true } else { showingReceipt = true }
            }
            .padding(.top, 28)
        }
        .frame(maxWidth: .infinity)
    }

    private var today: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "today")
                .padding(.top, 28)

            // An empty day is stated, not drawn. A 24-slot chart with nothing in
            // it renders as a void above a dashed rule, which reads as a broken
            // component rather than as "you haven't picked up your phone".
            if hourlyOrdered.contains(where: { $0 > 0 }) {
                HourStrip(hourly: hourlyOrdered)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
            } else {
                MirrorLine(text: "nothing yet today.", size: 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
            }

            // The mirror's read on the day, in its own voice — NOT a keyed row.
            // It was briefly labelled "vs yesterday", which lied: the verdict is
            // whichever rule matched, and most of them have nothing to do with
            // yesterday. It was also, before that, a filled GREEN banner reading
            // "91% less than yesterday. Actual progress." — a success state, in
            // an app whose design guide bans them and whose whole thesis is that
            // it never congratulates you.
            if let insight = insightResult, !insight.verdictLine.isEmpty {
                MirrorLine(text: insight.verdictLine, size: 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .padding(.bottom, 6)
            }

            if let peak = historicalPeak {
                LedgerRow(
                    label: "worst hours",
                    value: "\(InsightEngine.hourLabel(peak.startHour))–\(InsightEngine.hourLabel(peak.endHour % 24))"
                )
            }

            LedgerRow(label: "tracking", value: trackedLabel) {
                showingPicker = true
            }
            .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
            .onChange(of: selection) { _, newValue in
                saveSelection(newValue)
                ActivityScheduler.shared.startMonitoring(selection: newValue)
            }
            .padding(.bottom, 12)
        }
    }

    // Seven days of real history, or an honest sentence. Never a decorative
    // chart of random numbers — which is literally what stood here before
    // (`CGFloat.random(in: 12...48)`), on the home screen of an app that sells
    // the truth.
    private var pattern: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "this week")
                .padding(.top, 28)

            if let weekly = insightResult?.weekly {
                WeekStrip(totals: weekly.totalSeconds, labels: weekly.dateLabels)
                    .padding(.top, 20)

                MirrorLine(text: weekly.verdictLine, size: 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 18)
            } else {
                Text(daysUntilPattern == 1
                     ? "your pattern needs seven days. one to go."
                     : "your pattern needs seven days. \(daysUntilPattern) to go.")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color.ink.opacity(0.35))
                    .padding(.top, 16)
            }
        }
        .padding(.bottom, 26)
    }

    private var footer: some View {
        Group {
            if let trialDayLine {
                Text(trialDayLine)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color.ink.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 22)
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
        hourlyData = store.loadTodayHourly()
        totalSeconds = store.totalSecondsAllApps()
        trackingFailed = store.defaults.bool(forKey: AppGroupKeys.trackingFailedKey)
        trackingDegraded = store.defaults.bool(forKey: AppGroupKeys.trackingDegradedKey)
        loadInsight()
        updateTrialState()
        updateRealityCheck()
        maybeAutoShowReceipt()
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
