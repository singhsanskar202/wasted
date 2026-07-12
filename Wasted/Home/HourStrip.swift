import SwiftUI

// Today, hour by hour. Replaces the "CLEAN ZONES" card, which spent a four-item
// colour legend (Clean / Low / Moderate / Danger) on a strip that usually has
// one coloured cell in it — more legend than data, and four shades of orange
// that the palette never had.
//
// Here there is nothing to decode: taller and brighter means more time. The one
// colour in the system, alarm red, is spent only on an hour that crosses an hour
// of usage — the same rule the rest of the app uses. Everything else rides an
// ink opacity ramp, so red keeps meaning "this is bad" instead of meaning "this
// is a chart".
struct HourStrip: View {
    let hourly: [Int]           // 24 values, seconds per hour

    private var peak: Int { max(hourly.max() ?? 0, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<24, id: \.self) { hour in
                    let seconds = hour < hourly.count ? hourly[hour] : 0
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(color(for: seconds))
                        .frame(height: height(for: seconds))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 56, alignment: .bottom)

            // Four anchors, not twenty-four. The shape carries the meaning; the
            // axis only has to say roughly when.
            HStack(spacing: 0) {
                ForEach(["12a", "6a", "12p", "6p"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .light))
                        .foregroundStyle(Color.ink.opacity(0.3))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func color(for seconds: Int) -> Color {
        guard seconds > 0 else { return .hairline }
        if seconds >= Severity.alarmingHourSeconds { return .alarm }
        let fraction = Double(seconds) / Double(peak)
        return Color.ink.opacity(0.20 + 0.45 * fraction)
    }

    private func height(for seconds: Int) -> CGFloat {
        guard seconds > 0 else { return 3 }
        let fraction = Double(seconds) / Double(peak)
        return 6 + 50 * fraction
    }
}

// Seven days, once there are seven days. Until then there is NO chart — the old
// screen drew `CGFloat.random(in: 12...48)` bars here, which is fabricated data
// on the home screen of an app whose entire promise is that the number is true.
// An empty state that admits it's empty is worth more than a decorative lie.
struct WeekStrip: View {
    let totals: [Int]           // one total per day, oldest first
    let labels: [String]

    private var peak: Int { max(totals.max() ?? 0, 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(totals.enumerated()), id: \.offset) { index, seconds in
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Severity.dayColor(seconds).opacity(seconds >= Severity.alarmingDaySeconds ? 0.9 : 0.35))
                        .frame(height: max(3, 60 * Double(seconds) / Double(peak)))

                    Text(index < labels.count ? labels[index] : "")
                        .font(.system(size: 10, weight: .light))
                        .foregroundStyle(Color.ink.opacity(0.3))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 80, alignment: .bottom)
    }
}
