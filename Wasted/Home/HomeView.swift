import Charts
import FamilyControls
import SwiftUI

struct HomeView: View {
    @State private var selection = HomeView.loadSavedSelection()
    @State private var showingPicker = false
    @State private var hourlyData = UsageStore().loadTodayHourly()
    @State private var totalSeconds = UsageStore().totalSecondsAllApps()
    @State private var appeared = false
    @State private var insightResult: InsightResult? = nil

    private let store = UsageStore()

    private var timeString: String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "0m"
    }

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
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 72)
                    .padding(.bottom, 60)

                // MARK: — Big number
                VStack(spacing: 6) {
                    Text("you wasted")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.white.opacity(0.35))
                        .tracking(2)
                        .textCase(.lowercase)

                    Text(timeString)
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.85)
                        .animation(.spring(duration: 0.6, bounce: 0.3).delay(0.1), value: appeared)

                    Text("on your phone today")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.white.opacity(0.35))
                        .tracking(2)
                        .textCase(.lowercase)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)

                // MARK: — Equivalent
                if let eq = EquivalentTaskMapper.equivalent(for: totalSeconds) {
                    Text("that's \(eq.description) \(eq.emoji)")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.orange.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 60)
                        .transition(.opacity)
                }

                // MARK: — Divider
                Rectangle()
                    .fill(Color.white.opacity(0.07))
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
                            .padding(.bottom, 40)
                    }
                }

                // MARK: — Divider
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)

                // MARK: — Settings row
                HStack {
                    Text("tracking \(selection.applications.count) app\(selection.applications.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(.white.opacity(0.3))

                    Spacer()

                    Button {
                        showingPicker = true
                    } label: {
                        Text("edit")
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(.white.opacity(0.3))
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
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            hourlyData = store.loadTodayHourly()
            totalSeconds = store.totalSecondsAllApps()
            appeared = true
            loadInsight()
        }
    }

    // MARK: - Insight

    private func loadInsight() {
        let today = store.loadTodayUsage()
        let yesterday = store.loadYesterday()
        let history = store.loadHistory()

        var names: [String: String] = [:]
        if let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
           let data = defaults.data(forKey: AppGroupKeys.displayNamesKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            names = decoded
        }

        insightResult = InsightEngine.analyze(
            today: today, yesterday: yesterday, history: history, displayNames: names
        )
    }

    // MARK: - Helpers

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
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.15))

            Text(daysLeft == 1 ? "day until your pattern unlocks" : "days until your pattern unlocks")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(.white.opacity(0.25))
                .tracking(1)

            // Ghost bars — progressive reveal
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<24, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(i < (7 - daysLeft) * 3 ? 0.12 : 0.04))
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
