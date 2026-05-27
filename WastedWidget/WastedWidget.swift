import SwiftUI
import WidgetKit

// MARK: - Timeline

struct ScreenTimeEntry: TimelineEntry {
    let date: Date
    let totalMinutes: Int
    let peakHourLabel: String
}

struct WastedTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScreenTimeEntry {
        ScreenTimeEntry(date: Date(), totalMinutes: 47, peakHourLabel: "9pm")
    }

    func getSnapshot(in context: Context, completion: @escaping (ScreenTimeEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScreenTimeEntry>) -> Void) {
        let entry = makeEntry()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func makeEntry() -> ScreenTimeEntry {
        let store = UsageStore()
        let totalMinutes = store.totalSecondsAllApps() / 60
        let hourly = store.loadTodayHourly()
        let peakLabel: String
        if let peak = hourly.peakHour {
            peakLabel = peak < 12 ? "\(peak == 0 ? 12 : peak)am" : "\(peak == 12 ? 12 : peak - 12)pm"
        } else {
            peakLabel = "--"
        }
        return ScreenTimeEntry(date: Date(), totalMinutes: totalMinutes, peakHourLabel: peakLabel)
    }
}

// MARK: - Views

struct CircularWidgetView: View {
    let entry: ScreenTimeEntry

    var body: some View {
        Gauge(value: Double(min(entry.totalMinutes, 240)), in: 0...240) {
            Text("min")
                .font(.system(size: 8))
        } currentValueLabel: {
            Text("\(entry.totalMinutes)")
                .font(.system(.body, design: .rounded).bold())
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(.white)
    }
}

struct RectangularWidgetView: View {
    let entry: ScreenTimeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("WASTED")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("\(entry.totalMinutes) min")
                .font(.system(.title3, design: .rounded).bold())
            Text("peak \(entry.peakHourLabel)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget

struct WastedScreenTimeWidget: Widget {
    let kind = "WastedScreenTime"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WastedTimelineProvider()) { entry in
            Group {
                switch WidgetInfo.family {
                case .accessoryCircular:
                    CircularWidgetView(entry: entry)
                default:
                    RectangularWidgetView(entry: entry)
                }
            }
            .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Screen Time")
        .description("Today's total tracked screen time.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// Workaround to read widget family inside view body
private enum WidgetInfo {
    @Environment(\.widgetFamily) static var family
}
