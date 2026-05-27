import FamilyControls
import SwiftUI

struct HomeView: View {
    @State private var quote = QuoteBank.random
    @State private var selection = HomeView.loadSavedSelection()
    @State private var showingPicker = false
    @State private var hourlyData = UsageStore().loadTodayHourly()
    @State private var totalSeconds = UsageStore().totalSecondsAllApps()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(quote)
                .font(.system(size: 18, weight: .light, design: .serif))
                .italic()
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        quote = QuoteBank.random
                    }
                }

            Spacer()

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 24)

            VStack(spacing: 0) {
                HStack {
                    Text("Tracking")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .textCase(.uppercase)
                        .tracking(1)
                    Spacer()
                    Button {
                        showingPicker = true
                    } label: {
                        Text("Edit")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
                    .onChange(of: selection) { _, newValue in
                        saveSelection(newValue)
                        ActivityScheduler.shared.startMonitoring(selection: newValue)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)

                if selection.applications.isEmpty {
                    Text("No apps selected. Tap Edit.")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                } else {
                    Text("\(selection.applications.count) app\(selection.applications.count == 1 ? "" : "s") tracked")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }

                if let eq = EquivalentTaskMapper.equivalent(for: totalSeconds) {
                    Text("You could've \(eq.description) \(eq.emoji)")
                        .font(.caption)
                        .foregroundStyle(.orange.opacity(0.85))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                }
            }

            if !hourlyData.hours.isEmpty {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                    .padding(.horizontal, 24)

                HeatmapView(hourlyData: hourlyData)
                    .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            let store = UsageStore()
            hourlyData = store.loadTodayHourly()
            totalSeconds = store.totalSecondsAllApps()
        }
    }

    private static func loadSavedSelection() -> FamilyActivitySelection {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = defaults.data(forKey: AppGroupKeys.trackedSelectionKey),
            let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }
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
