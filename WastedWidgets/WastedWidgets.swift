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

    // Two entries: the total now, and zero at midnight.
    //
    // The midnight entry is what resets the widget on the day boundary without
    // anything having to run — WidgetKit renders it on schedule. Without it the
    // widget would keep yesterday's number until the next reload happened to
    // land, which is the same bug the island had.
    //
    // Between now and midnight the number only changes when usage does, and the
    // monitor extension reloads the timeline on every threshold crossing. So no
    // periodic backstop is needed: if nothing reloads us, nothing changed.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ScreenTimeEntry>) -> Void) {
        let midnight = AppGroupKeys.nextMidnight()
        let current = makeEntry()
        let fresh = ScreenTimeEntry(date: midnight, totalSeconds: 0, isExpired: current.isExpired)
        completion(Timeline(entries: [current, fresh], policy: .after(midnight)))
    }

    private func makeEntry() -> ScreenTimeEntry {
        let store = UsageStore()
        let totalSeconds = store.totalSecondsAllApps()
        let trialState = TrialClock.state(firstLaunch: store.firstLaunchDate(), unlocked: store.isUnlocked())
        // The widget is the one surface the monitor extension CAN drive, so it
        // should be the most accurate thing we ship. Logging what it actually
        // renders is how we find out whether WidgetKit honours our reloads or
        // quietly throttles them — the open question behind "it updates every
        // 5-8 minutes".
        EventLog.log(.widget, "timeline built total=\(totalSeconds)s expired=\(trialState == .expired)")
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

    // "1h 23m" on one line inside a circle this small scales down to something
    // unreadable. Stack it instead — the circle is tall enough for two lines,
    // and stacking keeps the digits big.
    var body: some View {
        Group {
            if entry.isExpired {
                Text("??")
                    .font(.system(size: 15, weight: .bold, design: .serif))
            } else {
                let hours = entry.totalSeconds / 3600
                let minutes = (entry.totalSeconds % 3600) / 60
                VStack(spacing: -2) {
                    if hours > 0 {
                        Text("\(hours)h")
                            .font(.system(size: 14, weight: .bold, design: .serif))
                    }
                    Text("\(minutes)m")
                        .font(.system(size: hours > 0 ? 13 : 17, weight: .bold, design: .serif))
                }
                .minimumScaleFactor(0.8)
            }
        }
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
