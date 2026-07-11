import SwiftUI
import WidgetKit

// MARK: - Timeline

struct ScreenTimeEntry: TimelineEntry {
    let date: Date
    let totalSeconds: Int
    let isExpired: Bool
}

struct WastedTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScreenTimeEntry {
        ScreenTimeEntry(date: Date(), totalSeconds: 2820, isExpired: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScreenTimeEntry) -> Void) {
        completion(makeEntry())
    }

    // Hourly backstop only — the real freshness comes from the monitor extension
    // reloading timelines on every threshold crossing.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ScreenTimeEntry>) -> Void) {
        let entry = makeEntry()
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func makeEntry() -> ScreenTimeEntry {
        let store = UsageStore()
        let totalSeconds = store.totalSecondsAllApps()
        let trialState = TrialClock.state(firstLaunch: store.firstLaunchDate(), unlocked: store.isUnlocked())
        return ScreenTimeEntry(date: Date(), totalSeconds: totalSeconds, isExpired: trialState == .expired)
    }
}

// MARK: - Views

struct SmallWidgetView: View {
    let entry: ScreenTimeEntry

    var body: some View {
        VStack(spacing: 4) {
            Text("you wasted")
                .font(.system(size: 10, weight: .light))
                .foregroundStyle(Color.ink.opacity(0.35))
                .tracking(1.5)

            Text(entry.isExpired ? "??m" : AppGroupKeys.formattedDuration(entry.totalSeconds))
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(entry.isExpired ? Color.ink.opacity(0.3) : displayColor)

            Text(entry.isExpired ? "unlock to see" : "today")
                .font(.system(size: 10, weight: .light))
                .foregroundStyle(Color.ink.opacity(0.35))
                .tracking(1.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color.canvas, for: .widget)
    }

    private var displayColor: Color {
        entry.totalSeconds >= 3600 ? .alarm : Color.ink
    }
}

struct CircularWidgetView: View {
    let entry: ScreenTimeEntry

    var body: some View {
        Text(entry.isExpired ? "??" : AppGroupKeys.formattedDuration(entry.totalSeconds))
            .font(.system(size: 15, weight: .bold, design: .serif))
            .minimumScaleFactor(0.6)
            .containerBackground(.clear, for: .widget)
    }
}

struct RectangularWidgetView: View {
    let entry: ScreenTimeEntry

    var body: some View {
        HStack(spacing: 4) {
            Text("wasted ·")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(.secondary)
            Text(entry.isExpired ? "??m" : AppGroupKeys.formattedDuration(entry.totalSeconds))
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(entry.totalSeconds >= 3600 && !entry.isExpired ? Color.alarm : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widget

struct WastedScreenTimeWidget: Widget {
    let kind = "WastedScreenTime"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WastedTimelineProvider()) { entry in
            WidgetContent(entry: entry)
        }
        .configurationDisplayName("Wasted")
        .description("The number, on your home or lock screen.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

private struct WidgetContent: View {
    @Environment(\.widgetFamily) private var family
    let entry: ScreenTimeEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

#Preview(as: .systemSmall) {
    WastedScreenTimeWidget()
} timeline: {
    ScreenTimeEntry(date: .now, totalSeconds: 2820, isExpired: false)
    ScreenTimeEntry(date: .now, totalSeconds: 5040, isExpired: false)
}
