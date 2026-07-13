import SwiftUI

// SEVEN DAYS × TWENTY-FOUR HOURS. Where the habit lives.
//
// One day's danger zones tell you about today. This tells you whether 9pm is a
// bad evening or a bad LIFE — and that's a different, much harder fact.
//
// LOCKED, AND BLURRED — BUT THE DATA UNDER THE BLUR IS REAL.
//
// That distinction is the whole point. The old screen drew
// `CGFloat.random(in: 12...48)` bars here: fabricated data, on the home screen of
// an app that sells the truth. This blurs the days you ACTUALLY have and fills
// the rest with genuine emptiness. It grows a little more real every day, and on
// day seven the blur lifts to reveal exactly what was underneath the whole time.
// Curiosity, without a lie holding it up.
struct WeekHeatmap: View {
    let days: [DailyUsage]          // oldest first, up to 7, including today
    let daysRequired: Int

    private var isLocked: Bool { days.count < daysRequired }
    private var daysToGo: Int { max(0, daysRequired - days.count) }

    var body: some View {
        ZStack {
            grid
                .blur(radius: isLocked ? 7 : 0)
                .opacity(isLocked ? 0.55 : 1)
                .allowsHitTesting(!isLocked)
                .accessibilityHidden(isLocked)

            if isLocked { lockOverlay }
        }
    }

    private var grid: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<daysRequired, id: \.self) { row in
                HStack(spacing: 3) {
                    Text(label(for: row))
                        .font(.system(size: 9, weight: .light))
                        .foregroundStyle(Color.ink.opacity(0.3))
                        .frame(width: 26, alignment: .leading)

                    ForEach(0..<24, id: \.self) { hour in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Severity.color(hourSeconds: seconds(row: row, hour: hour)))
                            .frame(height: 12)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            HStack(spacing: 0) {
                Spacer().frame(width: 29)
                ForEach(["12a", "6a", "12p", "6p"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9, weight: .light))
                        .foregroundStyle(Color.ink.opacity(0.25))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 2)
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

    // Rows are aligned to the RIGHT: the newest day is always the bottom row, so
    // the grid fills upward as history accumulates and today never moves.
    private func day(at row: Int) -> DailyUsage? {
        let offset = daysRequired - 1 - row      // 0 = today, 6 = six days ago
        let index = days.count - 1 - offset
        guard index >= 0, index < days.count else { return nil }
        return days[index]
    }

    private func seconds(row: Int, hour: Int) -> Int {
        guard let day = day(at: row), hour < day.hourly.count else { return 0 }
        return day.hourly[hour]
    }

    private func label(for row: Int) -> String {
        guard let day = day(at: row) else { return "" }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: day.date) else { return "" }
        let out = DateFormatter()
        out.dateFormat = "EEE"
        return out.string(from: date).lowercased()
    }
}
