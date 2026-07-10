import Charts
import Combine
import FamilyControls
import StoreKit
import SwiftUI

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
    @State private var realityCheckHapticFired = false

    private let store = UsageStore()

    // The extension writes usage to the App Group only at thresholds; without
    // a poll the screen would only catch up on foreground. 5s keeps it close
    // to live while Wasted is open (the underlying data still steps at
    // thresholds, so this is as fresh as the OS makes usage available).
    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var heatmapDaysLeft: Int {
        max(0, 7 - store.loadHistory().count)
    }

    private var isExpired: Bool {
        if case .expired = trialState { return true }
        return false
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // MARK: — Quote
                Text(QuoteBank.todaysQuote)
                    .font(.system(size: 16, weight: .light, design: .serif))
                    .italic()
                    .foregroundStyle(Color.ink.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 72)
                    .padding(.bottom, realityCheck == nil ? 60 : 24)

                // MARK: — Guess vs reality (shown until dismissed, once ever)
                if let check = realityCheck {
                    realityCheckCard(check)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }

                // MARK: — Gated content (number, receipt, heatmap, insights)
                ZStack {
                    VStack(spacing: 0) {
                        // Big number
                        VStack(spacing: 6) {
                            Text("you wasted")
                                .font(.system(size: 14, weight: .light))
                                .foregroundStyle(Color.ink.opacity(0.5))
                                .tracking(2)
                                .textCase(.lowercase)

                            Text(AppGroupKeys.formattedDuration(totalSeconds))
                                .font(.system(size: 68, weight: .bold, design: .serif))
                                .foregroundStyle(Color.ink)
                                .contentTransition(.numericText())
                                .opacity(appeared ? 1 : 0)
                                .scaleEffect(appeared || reduceMotion ? 1 : 0.85)
                                .animation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.3).delay(0.1), value: appeared)

                            Text("on your phone today")
                                .font(.system(size: 14, weight: .light))
                                .foregroundStyle(Color.ink.opacity(0.5))
                                .tracking(2)
                                .textCase(.lowercase)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 32)

                        // Equivalent
                        if let eq = EquivalentTaskMapper.equivalent(for: totalSeconds) {
                            Text("that's \(eq.description).")
                                .font(.system(size: 16, weight: .regular, design: .serif))
                                .italic()
                                .foregroundStyle(Color.inkFaint)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                                .padding(.bottom, 32)
                                .transition(.opacity)
                        }

                        // Receipt
                        Button {
                            if isExpired {
                                showingPaywall = true
                            } else {
                                Haptics.light()
                                showingReceipt = true
                            }
                        } label: {
                            Text("today's receipt")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color.ink.opacity(0.65))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.ink.opacity(0.25), lineWidth: 1)
                                )
                        }
                        .padding(.bottom, 60)

                        // Divider
                        Rectangle()
                            .fill(Color.ink.opacity(0.07))
                            .frame(height: 1)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 40)

                        // Heatmap or days-left
                        if heatmapDaysLeft == 0 && !hourlyData.hours.isEmpty {
                            HeatmapView(hourlyData: hourlyData)
                                .padding(.bottom, 40)
                        } else {
                            PatternLockedView(daysLeft: heatmapDaysLeft)
                                .padding(.horizontal, 32)
                                .padding(.bottom, 40)
                        }

                        // Danger Zones + Weekly insight
                        if let result = insightResult {
                            DangerZonesCard(result: result)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)

                            if let weekly = result.weekly {
                                WeeklyCard(weekly: weekly)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 16)
                            }
                        }

                        // Peak hour across history
                        if let peak = historicalPeak {
                            VStack(spacing: 6) {
                                Text("you lose the most time between \(InsightEngine.hourLabel(peak.startHour))–\(InsightEngine.hourLabel(peak.endHour % 24)).")
                                    .font(.system(size: 17, weight: .regular, design: .serif))
                                    .italic()
                                    .foregroundStyle(Color.ink.opacity(0.85))
                                    .multilineTextAlignment(.center)

                                Text("\(peak.daysActive) of the last \(peak.daysTotal) days")
                                    .font(.system(size: 13, weight: .light))
                                    .foregroundStyle(Color.ink.opacity(0.45))
                                    .tracking(1)
                            }
                            .padding(.horizontal, 40)
                            .padding(.top, 16)
                            .padding(.bottom, 40)
                        }
                    }
                    .blur(radius: isExpired ? 14 : 0)
                    .redacted(reason: isExpired ? .placeholder : [])
                    .allowsHitTesting(!isExpired)

                    if isExpired {
                        expiredOverlay
                    }
                }

                // MARK: — Divider
                Rectangle()
                    .fill(Color.ink.opacity(0.07))
                    .frame(height: 1)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)

                // MARK: — Settings row
                HStack {
                    Text("tracking \(selection.applications.count) app\(selection.applications.count == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(Color.ink.opacity(0.45))

                    Spacer()

                    Button {
                        showingPicker = true
                    } label: {
                        Text("edit")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.ink.opacity(0.65))
                    }
                    .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
                    .onChange(of: selection) { _, newValue in
                        saveSelection(newValue)
                        ActivityScheduler.shared.startMonitoring(selection: newValue)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, trialDayLine == nil ? 52 : 6)

                if let trialDayLine {
                    Text(trialDayLine)
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Color.ink.opacity(0.4))
                        .padding(.horizontal, 32)
                        .padding(.bottom, 52)
                }
            }
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
        .sheet(isPresented: $showingReceipt, onDismiss: refresh) {
            ReceiptView(receipt: DailyReceipt.build(
                usage: store.loadTodayUsage(),
                displayNames: loadDisplayNames()
            ))
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(store: lifetimeStore)
        }
    }

    // MARK: - Refresh

    private func refresh() {
        hourlyData = store.loadTodayHourly()
        totalSeconds = store.totalSecondsAllApps()
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
        else {
            realityCheck = nil
            return
        }
        let firstDayTotal = firstDay.seconds.values.reduce(0, +)
        guard let check = RealityCheck.make(guessSeconds: guessSeconds, firstFullDaySeconds: firstDayTotal) else {
            realityCheck = nil
            return
        }
        realityCheck = check
        if !realityCheckHapticFired {
            Haptics.medium()
            realityCheckHapticFired = true
        }
    }

    private func maybeAutoShowReceipt() {
        guard !isExpired else { return }
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= AppGroupKeys.receiptHour, totalSeconds > 0 else { return }
        let today = DailyUsage.todayString()
        guard store.lastReceiptAutoShowDate() != today else { return }
        store.markReceiptAutoShown(date: today)
        showingReceipt = true
    }

    // MARK: - Insight

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

    // MARK: - Trial / paywall helpers

    private var trialDayLine: String? {
        guard case .trial(let daysLeft) = trialState else { return nil }
        let dayNumber = TrialClock.trialDays - daysLeft + 1
        return "day \(dayNumber) of \(TrialClock.trialDays) — then it's \(unlockPrice) once."
    }

    private var unlockPrice: String {
        lifetimeStore.product?.displayPrice ?? "$9.99"
    }

    private var expiredOverlay: some View {
        VStack(spacing: 16) {
            Text("still counting.\nyou just can't see it.")
                .font(.system(size: 20, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)

            Button {
                showingPaywall = true
            } label: {
                Text("unlock forever — \(unlockPrice)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.black)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 28)
                    .background(Color.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(24)
    }

    private func realityCheckCard(_ check: RealityCheck) -> some View {
        VStack(spacing: 10) {
            Text(check.guessLine)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color.inkFaint)

            Text(check.realityLine)
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(Color.ink)

            Text(check.deltaLine)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color.alarm)

            Button {
                store.setRealityCheckShown(true)
                realityCheck = nil
            } label: {
                Text("understood")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color.ink.opacity(0.4))
                    .padding(.top, 6)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(Color.ink.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

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

// MARK: - Pattern Locked View

private struct PatternLockedView: View {
    let daysLeft: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("\(daysLeft)")
                .font(.system(size: 48, weight: .bold, design: .serif))
                .foregroundStyle(Color.ink.opacity(0.15))

            Text(daysLeft == 1 ? "day until your pattern unlocks" : "days until your pattern unlocks")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Color.ink.opacity(0.4))
                .tracking(1)

            // Ghost bars — progressive reveal
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<24, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.ink.opacity(i < (7 - daysLeft) * 3 ? 0.12 : 0.04))
                        .frame(width: 10, height: CGFloat.random(in: 12...48))
                }
            }
            .frame(height: 52)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
}
