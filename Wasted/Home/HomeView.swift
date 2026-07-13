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

    // Each block answers ONE question, and no block answers a question another
    // block already answered:
    //
    //   hero     → how much did today cost?
    //   when     → what part of the day was it?
    //   pattern  → is this a habit?
    //   settings → what is being tracked, and what does it cost?
    //
    // Three things were cut getting here, all of them duplicates:
    //   · The rotating quote. It was the THIRD serif-italic mirror line on one
    //     screen (quote, equivalent, verdict) — same voice, same job, and the
    //     only one of the three tied to the user's actual number is the
    //     equivalent. It also pushed the hero, which is the entire product, below
    //     the fold on smaller phones.
    //   · The verdict line ("9pm–11pm is over half of today"). A colour-coded
    //     strip that names its own worst window says this without a sentence.
    //   · The "TODAY" section label, which sat directly under a hero captioned
    //     "you wasted today".
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                trackingHealth

                ZStack {
                    VStack(spacing: 0) {
                        hero
                        Rule().padding(.top, 44)
                        when
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

    // HOW MUCH. The reason the app exists — the top of the screen, the largest
    // type in the system, and no neighbours. The rotating quote used to sit above
    // it and push it down; it was the third serif-italic line on the screen and
    // the only one that knew nothing about the user.
    private var hero: some View {
        VStack(spacing: 0) {
            HeroNumber(seconds: totalSeconds)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.9)
                .animation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.25).delay(0.1), value: appeared)
                .padding(.top, 52)

            Text("you wasted today")
                .font(.system(size: 12, weight: .light))
                .tracking(2)
                .foregroundStyle(Color.inkLabel)
                .padding(.top, 10)

            if let equivalent = EquivalentTaskMapper.equivalent(for: totalSeconds) {
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

    // WHEN. The strip is colour-coded by severity and names its own worst window,
    // so it no longer needs a sentence underneath telling you what it means. The
    // section label used to read "TODAY", directly below a hero captioned "you
    // wasted today".
    private var when: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "when")
                .padding(.top, 28)

            // An empty day is stated, not drawn. A 24-slot chart with nothing in
            // it renders as a void above a dashed rule, which reads as a broken
            // component rather than as "you haven't picked up your phone".
            if hourlyOrdered.contains(where: { $0 > 0 }) {
                HourStrip(hourly: hourlyOrdered)
                    .padding(.top, 18)
            } else {
                MirrorLine(text: "nothing yet today.", size: 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
            }
        }
        .padding(.bottom, 26)
    }

    // IS THIS A HABIT? Everything time-comparative lives here. "worst hours" moved
    // in from the today section, where it never belonged — it's a seven-day
    // statistic that was filed under a heading about the last few hours.
    private var pattern: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "the pattern")
                .padding(.top, 28)

            if let weekly = insightResult?.weekly {
                WeekStrip(totals: weekly.totalSeconds, labels: weekly.dateLabels)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
            } else {
                Text(daysUntilPattern == 1
                     ? "seven days to see a pattern. one to go."
                     : "seven days to see a pattern. \(daysUntilPattern) to go.")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color.ink.opacity(0.35))
                    .padding(.top, 14)
                    .padding(.bottom, 4)
            }

            // A real comparison, not the old rule-engine verdict — which said
            // whichever of eleven things happened to match and mostly had nothing
            // to do with yesterday at all.
            if let change = changeVsYesterday {
                LedgerRow(label: "vs yesterday") {
                    Text(change.text)
                        .font(.system(size: 15, weight: .regular))
                        // Red only when it got WORSE. There is no green here and
                        // never will be: the mirror doesn't congratulate.
                        .foregroundStyle(change.worse ? Color.alarm : Color.ink)
                }
            }

            if let peak = historicalPeak {
                LedgerRow(
                    label: "worst hours",
                    value: "\(InsightEngine.hourLabel(peak.startHour))–\(InsightEngine.hourLabel(peak.endHour % 24))"
                )
            }
        }
        .padding(.bottom, 20)
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

    // MARK: - Yesterday

    private var changeVsYesterday: (text: String, worse: Bool)? {
        guard let yesterday = store.loadYesterday() else { return nil }
        let before = yesterday.seconds.values.reduce(0, +)
        guard before > 0, totalSeconds > 0 else { return nil }

        let ratio = Double(totalSeconds) / Double(before)
        let percent = Int(abs(ratio - 1) * 100)
        // Below 5% it's noise, and calling noise a trend is how a mirror starts
        // lying.
        guard percent >= 5 else { return ("about the same", false) }

        return ratio > 1
            ? ("\(percent)% more", true)
            : ("\(percent)% less", false)
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
