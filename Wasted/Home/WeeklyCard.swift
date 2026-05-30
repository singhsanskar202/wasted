import SwiftUI

private let red     = Color(red: 1, green: 0.23, blue: 0.19)
private let cardBg  = Color(white: 0.055)
private let dimText = Color(white: 0.25)

struct WeeklyCard: View {
    let weekly: WeeklyInsight

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color(white: 0.08))
            barChart
            verdictBanner
        }
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("THIS WEEK")
                .font(.system(size: 9, weight: .semibold))
                .tracking(2)
                .foregroundStyle(dimText)
            Spacer()
            trendBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var trendBadge: some View {
        let (label, fg): (String, Color) = {
            switch weekly.trend {
            case .improving: return ("↓ IMPROVING", Color(red: 0.3, green: 0.8, blue: 0.4))
            case .worsening: return ("↑ WORSENING", red)
            case .flat:      return ("→ FLAT",       Color(white: 0.35))
            }
        }()
        return Text(label)
            .font(.system(size: 8, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(fg)
    }

    // MARK: Bar chart

    private var barChart: some View {
        let maxVal = max(weekly.totalSeconds.max() ?? 1, 1)
        return VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(weekly.totalSeconds.enumerated()), id: \.offset) { idx, secs in
                    VStack(spacing: 4) {
                        let barH = CGFloat(secs) / CGFloat(maxVal) * 64 + 2
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(for: idx, total: weekly.totalSeconds.count))
                            .frame(maxWidth: .infinity)
                            .frame(height: barH)
                    }
                }
            }
            .frame(height: 68)

            HStack(spacing: 0) {
                ForEach(Array(weekly.dateLabels.enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(.system(size: 8))
                        .foregroundStyle(Color(white: 0.22))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    /// Older bars dim, newer bars brighten to show recency
    private func barColor(for index: Int, total: Int) -> Color {
        guard total > 1 else { return red }
        let brightness = 0.3 + 0.7 * Double(index) / Double(total - 1)
        return red.opacity(brightness)
    }

    // MARK: Verdict banner

    private var verdictBanner: some View {
        let (bgColor, borderColor, textColor): (Color, Color, Color) = {
            switch weekly.trend {
            case .improving:
                return (
                    Color(red: 0.05, green: 0.18, blue: 0.08),
                    Color(red: 0.15, green: 0.45, blue: 0.22).opacity(0.4),
                    Color(red: 0.4, green: 0.85, blue: 0.5)
                )
            case .worsening:
                return (red.opacity(0.07), red.opacity(0.18), Color(white: 0.7))
            case .flat:
                return (Color(white: 0.07), Color(white: 0.12), Color(white: 0.55))
            }
        }()

        return Text(weekly.verdictLine)
            .font(.system(size: 12))
            .foregroundStyle(textColor)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(bgColor)
            .overlay(
                Rectangle()
                    .stroke(borderColor, lineWidth: 0.5)
            )
    }
}
