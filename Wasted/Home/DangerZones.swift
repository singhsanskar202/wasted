import SwiftUI

// WHERE THE DAY LEAKS. The only actionable thing on this screen.
//
// The total tells you that you lost time. It cannot tell you what to change.
// This can: it names the hours, so "9pm–11pm is where my evening goes" becomes a
// fact you can act on instead of a vague sense that you're on your phone too much.
//
// COLOUR CARRIES THE SEVERITY, not just height. A previous version encoded usage
// only as bar height with a single red for anything past an hour — so a 55-minute
// hour and a 6-minute hour were the same colour and you had to eyeball bar
// heights to find the one that hurt. Now: quiet ink → amber → red.
//
// No green. Ever. Green would be a success state and the mirror does not
// congratulate — the traffic light here runs from "quiet" to "bad" and has no
// "good".
//
// And the zones CALL THEMSELVES OUT beneath the chart. The old design spent a
// four-row legend (CLEAN / LOW / MODERATE / DANGER) teaching you to decode a
// strip that usually had one coloured cell in it. A pointer that says
// "9pm–10pm — 1h 2m gone" needs no key.
struct DangerZones: View {
    let hourly: [Int]           // 24 values, seconds per hour

    private var peak: Int { max(hourly.max() ?? 0, 1) }

    // The hours worth naming, worst first. Two at most: a list of five "zones" is
    // a chart with extra steps, and the point is to give the user ONE thing to
    // change.
    private var zones: [(hour: Int, seconds: Int)] {
        hourly.indices
            .filter { Severity.Hour(seconds: hourly[$0]).isCallable }
            .sorted { hourly[$0] > hourly[$1] }
            .prefix(2)
            .map { (hour: $0, seconds: hourly[$0]) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<24, id: \.self) { hour in
                    let seconds = hour < hourly.count ? hourly[hour] : 0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Severity.color(hourSeconds: seconds))
                        .frame(height: height(for: seconds))
                        .frame(maxWidth: .infinity)
                }
            }
            // Tall enough that the shape of the day is legible. The point of this
            // section is the shape; at 56pt it was a rumour.
            .frame(height: 96, alignment: .bottom)

            HStack(spacing: 0) {
                ForEach(["12a", "6a", "12p", "6p"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .light))
                        .foregroundStyle(Color.ink.opacity(0.28))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if zones.isEmpty {
                Text("no zone worth naming yet.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color.ink.opacity(0.3))
                    .padding(.top, 6)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(zones, id: \.hour) { zone in
                        callout(hour: zone.hour, seconds: zone.seconds)
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private func callout(hour: Int, seconds: Int) -> some View {
        let level = Severity.Hour(seconds: seconds)
        let tint = Severity.color(hourSeconds: seconds)
        let window = "\(InsightEngine.hourLabel(hour))–\(InsightEngine.hourLabel((hour + 1) % 24))"

        return HStack(alignment: .center, spacing: 9) {
            // The dot IS the legend — it's the same colour as the bar it points at.
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            Text(window)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)

            Text(level == .danger
                 ? "you lost \(AppGroupKeys.formattedDuration(seconds)) here."
                 : "\(AppGroupKeys.formattedDuration(seconds)) here.")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color.inkQuiet)

            Spacer(minLength: 0)
        }
    }

    // The tallest bar reaches the TOP of the band. Scaling to less than the frame
    // leaves dead air above the peak, which reads as a chart that failed to draw.
    private func height(for seconds: Int) -> CGFloat {
        guard seconds > 0 else { return 3 }
        return 8 + 86 * (Double(seconds) / Double(peak))
    }
}
