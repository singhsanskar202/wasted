import SwiftUI

// SEVEN DAYS, SEVEN BARS. Is this a bad evening, or a bad life?
//
// This used to be a 7×24 heatmap: 168 eight-pixel cells that asked the reader
// to cross-reference two axes on a scroll-by. Nobody does that work, so the
// grid answered nothing — Sanskar's own verdict was "I'm unable to understand
// it, and if someone can't understand it, how will they act?" A glance holds
// ONE fact. So the chart now shows the only per-day fact that matters (how
// much each day cost), and the analysis the grid demanded of the reader —
// "which hour keeps repeating?" — is done by the app and STATED underneath,
// exactly the way danger zones states its findings. Chart shows the shape;
// sentences carry the insight; nothing is decoded.
//
// LOCKED, AND BLURRED — BUT THE DATA UNDER THE BLUR IS REAL. The old screen
// once drew random bars here; this blurs the days you ACTUALLY have. It grows
// a little more real every day, and on day seven the blur lifts to reveal what
// was underneath the whole time. Curiosity, without a lie holding it up.
struct WeekBars: View {
    let days: [DailyUsage]          // oldest first, up to 7, including today
    let daysRequired: Int
    let peak: HistoricalPeak?       // the recurring window across history

    private let chartHeight: CGFloat = 96

    private var isLocked: Bool { days.count < daysRequired }
    private var daysToGo: Int { max(0, daysRequired - days.count) }

    var body: some View {
        ZStack {
            content
                .blur(radius: isLocked ? 7 : 0)
                .drawingGroup()
                .opacity(isLocked ? 0.55 : 1)
                .allowsHitTesting(!isLocked)
                .accessibilityHidden(isLocked)

            if isLocked { lockOverlay }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .top) {
                // The ceiling: 4h — a quarter of the waking day, the point
                // where the home number itself turns red. Same absolute-scale
                // law as the hour strip: without a unit line, "tall" means
                // nothing and the chart lies on quiet weeks.
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(Color.ink.opacity(0.10))
                            .frame(height: 1)
                        Text("4h")
                            .font(.system(size: 9, weight: .light))
                            .foregroundStyle(Color.ink.opacity(0.3))
                    }
                    Spacer(minLength: 0)
                }

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(0..<daysRequired, id: \.self) { slot in
                        let usage = day(at: slot)
                        let seconds = usage.map(total) ?? 0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(usage == nil ? Color.hairline : Severity.dayRamp(seconds))
                            .frame(height: height(for: seconds, exists: usage != nil))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: chartHeight)

            // Weekday initials; today reads brighter, so the row needs no
            // "today" caption.
            HStack(spacing: 10) {
                ForEach(0..<daysRequired, id: \.self) { slot in
                    Text(label(for: slot))
                        .font(.system(size: 10, weight: slot == daysRequired - 1 ? .medium : .light))
                        .foregroundStyle(Color.ink.opacity(slot == daysRequired - 1 ? 0.7 : 0.3))
                        .frame(maxWidth: .infinity)
                }
            }

            findings.padding(.top, 6)
        }
    }

    // THE INSIGHT LIVES HERE, IN SENTENCES — the work the heatmap used to
    // demand of the reader. Two lines at most, same law as danger zones: the
    // worst single day, and the window that keeps repeating. Facts, no advice.
    @ViewBuilder
    private var findings: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let worst = worstDay, total(worst) >= 3600 {
                callout(
                    tint: Severity.dayRamp(total(worst)),
                    lead: dayName(worst),
                    line: "you lost \(AppGroupKeys.formattedDuration(total(worst))) — the worst of the week."
                )
            } else {
                Text("no day crossed an hour this week.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color.ink.opacity(0.3))
            }

            // The bad-evening-or-bad-life fact: HistoricalPeak always knew how
            // many days the window repeated — the grid just never said it.
            if let peak, peak.daysActive >= 2 {
                callout(
                    tint: .alarm,
                    lead: InsightEngine.timeRangeLabel(start: peak.startHour, end: peak.endHour),
                    line: "there \(peak.daysActive) of the last \(peak.daysTotal) days."
                )
            }
        }
    }

    private func callout(tint: Color, lead: String, line: String) -> some View {
        HStack(alignment: .center, spacing: 9) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            Text(lead)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)

            Text(line)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color.inkQuiet)

            Spacer(minLength: 0)
        }
    }

    private var lockOverlay: some View {
        VStack(spacing: 7) {
            Image(systemName: "lock.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.ink.opacity(0.6))

            Text(daysToGo == 1 ? "one more day" : "\(daysToGo) more days")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(Color.ink.opacity(0.9))

            Text("then you'll see the shape of your week.")
                .font(.system(size: 13, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color.ink.opacity(0.5))
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Data

    // Slots are aligned to the RIGHT: today is always the last bar, so the
    // chart fills leftward as history accumulates and today never moves.
    private func day(at slot: Int) -> DailyUsage? {
        let index = days.count - 1 - (daysRequired - 1 - slot)
        guard index >= 0, index < days.count else { return nil }
        return days[index]
    }

    private func total(_ usage: DailyUsage) -> Int {
        usage.seconds.values.reduce(0, +)
    }

    private var worstDay: DailyUsage? {
        days.max { total($0) < total($1) }
    }

    // ABSOLUTE, NOT RELATIVE — same law as the hour strip. A bar at the line
    // means a red day. Past the line it clamps: the colour already screams,
    // and a chart that rescales to its worst day makes every other day lie.
    private func height(for seconds: Int, exists: Bool) -> CGFloat {
        guard exists else { return 3 }
        guard seconds > 0 else { return 3 }
        let fraction = min(1.0, Double(seconds) / Double(Severity.alarmingDaySeconds))
        return max(4, chartHeight * fraction)
    }

    private func label(for slot: Int) -> String {
        guard let usage = day(at: slot) else { return "" }
        return String(dayName(usage).prefix(1))
    }

    private func dayName(_ usage: DailyUsage) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: usage.date) else { return "" }
        let out = DateFormatter()
        out.dateFormat = "EEE"
        return out.string(from: date).lowercased()
    }
}
