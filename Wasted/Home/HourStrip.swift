import SwiftUI

// WHEN the day went. The one job of this component.
//
// It used to encode usage only as height, with red reserved for hours past the
// 1h mark — so a 55-minute hour and a 6-minute hour were the same colour and you
// had to compare bar heights to find the hour that actually hurt. Now severity is
// a colour ramp from ink to alarm, so the worst part of your day is the part your
// eye lands on first, without reading anything.
//
// Two colours, not three. The palette has ink and alarm; adding an amber would
// make this a decorative chart instead of a diagnostic one, and the design guide
// bans exactly that. The ramp between them carries all the information a third
// hue would.
//
// And no legend. The old "CLEAN / LOW / MODERATE / DANGER" key spent four rows
// explaining a strip that usually had one coloured cell in it. The worst window
// names itself underneath instead — which is the only thing the legend was ever
// helping you find.
struct HourStrip: View {
    let hourly: [Int]           // 24 values, seconds per hour

    private var peak: Int { max(hourly.max() ?? 0, 1) }

    // An hour in which you spent a full hour is as bad as an hour gets.
    private func severity(_ seconds: Int) -> Double {
        min(1.0, Double(seconds) / Double(Severity.alarmingHourSeconds))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<24, id: \.self) { hour in
                    let seconds = hour < hourly.count ? hourly[hour] : 0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: seconds))
                        .frame(height: height(for: seconds))
                        .frame(maxWidth: .infinity)
                }
            }
            // Tall enough to be a feature of the screen. At 56pt it read as a
            // thin afterthought under a label, and the shape of the day — which
            // is the whole point of this section — was too small to see.
            .frame(height: 92, alignment: .bottom)

            // Four anchors, not twenty-four. The shape carries the meaning; the
            // axis only has to say roughly when.
            HStack(spacing: 0) {
                ForEach(["12a", "6a", "12p", "6p"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .light))
                        .tracking(0.5)
                        .foregroundStyle(Color.ink.opacity(0.28))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let worst = worstWindow {
                Text(worst)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color.alarm)
                    .padding(.top, 6)
            }
        }
    }

    // The strip's own caption, so the chart explains itself instead of needing a
    // sentence somewhere else on the screen to interpret it.
    private var worstWindow: String? {
        guard let worstHour = hourly.indices.max(by: { hourly[$0] < hourly[$1] }),
              hourly[worstHour] > 0
        else { return nil }
        let minutes = hourly[worstHour] / 60
        // Below ten minutes there's no "worst" worth naming — it would just be
        // pointing at noise and calling it a problem.
        guard minutes >= 10 else { return nil }
        // The mirror's voice, not a chart label. "worst: 9pm–10pm · 62m" read like
        // debug output on a screen that is otherwise trying to be beautiful.
        let window = "\(InsightEngine.hourLabel(worstHour))–\(InsightEngine.hourLabel((worstHour + 1) % 24))"
        return "you lost \(AppGroupKeys.formattedDuration(hourly[worstHour])) between \(window)."
    }

    private func color(for seconds: Int) -> Color {
        guard seconds > 0 else { return .hairline }
        let level = severity(seconds)

        // The hue is curved, not linear. Mixing a warm off-white ink with red at
        // a linear 30% lands in a dusty brown — every mildly-used hour looked
        // muddy and *slightly* alarming, which is the opposite of a diagnostic.
        // Squaring holds the low end at ink, so a ten-minute hour is quiet and
        // neutral, and the colour only turns as the hour genuinely goes bad.
        let heat = level * level

        // Brightness climbs linearly, so a quiet hour recedes into the canvas and
        // a ruinous one is the brightest object on the screen.
        return Color.ink
            .mix(with: Color.alarm, by: heat)
            .opacity(0.35 + 0.65 * level)
    }

    // The tallest bar must reach the TOP of the band. Scaling to less than the
    // frame height leaves a strip of dead air above the peak, which reads as a
    // chart that failed to draw rather than as a day with a shape.
    private func height(for seconds: Int) -> CGFloat {
        guard seconds > 0 else { return 3 }
        return 8 + 82 * (Double(seconds) / Double(peak))
    }
}

// Seven days, once there are seven days. Until then there is NO chart — the old
// screen drew `CGFloat.random(in: 12...48)` bars here, which is fabricated data
// on the home screen of an app whose entire promise is that the number is true.
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
