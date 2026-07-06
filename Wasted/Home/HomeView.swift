import Charts
import FamilyControls
import SwiftUI

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection = HomeView.loadSavedSelection()
    @State private var showingPicker = false
    @State private var showingReceipt = false
    @State private var hourlyData = UsageStore().loadTodayHourly()
    @State private var totalSeconds = UsageStore().totalSecondsAllApps()
    @State private var appeared = false
    @State private var insightResult: InsightResult? = nil
    @State private var historicalPeak: HistoricalPeak? = nil

    private let store = UsageStore()

    private var heatmapDaysLeft: Int {
        max(0, 7 - store.loadHistory().count)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // MARK: — Quote
                Text(QuoteBank.todaysQuote)
                    .font(.system(size: 15, weight: .light, design: .serif))
                    .italic()
                    .foregroundStyle(Color.ink.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 72)
                    .padding(.bottom, 60)

                // MARK: — Big number
                VStack(spacing: 6) {
                    Text("you wasted")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(Color.ink.opacity(0.35))
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
                        .foregroundStyle(Color.ink.opacity(0.35))
                        .tracking(2)
                        .textCase(.lowercase)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)

                // MARK: — Equivalent
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

                // MARK: — Receipt
                Button {
                    Haptics.light()
                    showingReceipt = true
                } label: {
                    Text("today's receipt")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color.inkFaint)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.ink.opacity(0.15), lineWidth: 1)
                        )
                }
                .padding(.bottom, 60)
                .sheet(isPresented: $showingReceipt) {
                    ReceiptView(receipt: DailyReceipt.build(
                        usage: store.loadTodayUsage(),
                        displayNames: loadDisplayNames()
                    ))
                }

                // MARK: — Divider
                Rectangle()
                    .fill(Color.ink.opacity(0.07))
                    .frame(height: 1)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)

                // MARK: — Heatmap or days-left
                if heatmapDaysLeft == 0 && !hourlyData.hours.isEmpty {
                    HeatmapView(hourlyData: hourlyData)
                        .padding(.bottom, 40)
                } else {
                    PatternLockedView(daysLeft: heatmapDaysLeft)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)
                }

                // MARK: — Danger Zones + Weekly insight
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

                // MARK: — Peak hour across history
                if let peak = historicalPeak {
                    VStack(spacing: 6) {
                        Text("you lose the most time between \(InsightEngine.hourLabel(peak.startHour))–\(InsightEngine.hourLabel(peak.endHour % 24)).")
                            .font(.system(size: 17, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(Color.ink.opacity(0.85))
                            .multilineTextAlignment(.center)

                        Text("\(peak.daysActive) of the last \(peak.daysTotal) days")
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(Color.ink.opacity(0.35))
                            .tracking(1)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
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
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color.ink.opacity(0.3))

                    Spacer()

                    Button {
                        showingPicker = true
                    } label: {
                        Text("edit")
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(Color.ink.opacity(0.3))
                    }
                    .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
                    .onChange(of: selection) { _, newValue in
                        saveSelection(newValue)
                        ActivityScheduler.shared.startMonitoring(selection: newValue)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
        .background(Color.canvas.ignoresSafeArea())
        .onAppear {
            hourlyData = store.loadTodayHourly()
            totalSeconds = store.totalSecondsAllApps()
            appeared = true
            loadInsight()
        }
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
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Color.ink.opacity(0.25))
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
