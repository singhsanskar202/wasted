import SwiftUI

private let red       = Color.alarm
private let cardBg    = Color(white: 0.055)
private let dimText   = Color(white: 0.45)

struct DangerZonesCard: View {
    let result: InsightResult

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color(white: 0.08))
            timelineStrip
            legend
            Divider().overlay(Color(white: 0.08))
            if result.zones.filter({ $0.level != .clean }).isEmpty {
                emptyState
            } else {
                zoneList
                if !result.topAppIndices.isEmpty {
                    topAppsRow
                }
            }
            verdictBanner
        }
        .background(Color(white: 0.055))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text(cardTitle)
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(dimText)
            Spacer()
            Text("TODAY")
                .font(.system(size: 10))
                .foregroundStyle(Color(white: 0.4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var cardTitle: String {
        switch result.tone {
        case .positive: return "CLEAN ZONES"
        case .neutral:  return "USAGE PATTERN"
        case .warning:  return "DANGER ZONES"
        }
    }

    // MARK: Timeline strip

    private var timelineStrip: some View {
        VStack(spacing: 0) {
            HStack(spacing: 1) {
                ForEach(0..<24, id: \.self) { hour in
                    let level = result.timelineSegments.indices.contains(hour)
                        ? result.timelineSegments[hour] : .clean
                    Rectangle()
                        .fill(segmentColor(level))
                        .frame(maxWidth: .infinity)
                        .frame(height: 22)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .padding(.horizontal, 16)
            .padding(.top, 14)

            HStack {
                Text("12am")
                Spacer()
                Text("6am")
                Spacer()
                Text("12pm")
                Spacer()
                Text("6pm")
                Spacer()
                Text("11pm")
            }
            .font(.system(size: 10))
            .foregroundStyle(Color(white: 0.4))
            .padding(.horizontal, 16)
            .padding(.top, 5)
            .padding(.bottom, 12)
        }
    }

    private func segmentColor(_ level: DangerZone.Level) -> Color {
        switch level {
        case .clean:    return Color(white: 0.1)
        case .low:      return Color(red: 0.18, green: 0.10, blue: 0.05)
        case .moderate: return Color(red: 0.48, green: 0.19, blue: 0.06)
        case .danger:   return red
        }
    }

    // MARK: Legend

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(color: Color(white: 0.1), label: "Clean")
            legendItem(color: Color(red: 0.18, green: 0.10, blue: 0.05), label: "Low")
            legendItem(color: Color(red: 0.48, green: 0.19, blue: 0.06), label: "Moderate")
            legendItem(color: red, label: "Danger")
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(Color(white: 0.45))
        }
    }

    // MARK: Zone list

    private var zoneList: some View {
        VStack(spacing: 6) {
            ForEach(result.zones.filter({ $0.level != .clean })) { zone in
                zoneRow(zone)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        Text("No activity yet.")
            .font(.system(size: 13))
            .foregroundStyle(Color(white: 0.45))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
    }

    private func zoneRow(_ zone: DangerZone) -> some View {
        HStack(spacing: 10) {
            pill(for: zone.level)
            Text(InsightEngine.timeRangeLabel(start: zone.startHour, end: zone.endHour))
                .font(.system(size: 12))
                .foregroundStyle(Color(white: 0.65))
            Spacer()
            Text(formatted(zone.seconds))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color(white: 0.55))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // We can't attribute apps to individual zones (only per-hour totals are
    // stored), so the day's top apps are shown once instead of per zone.
    private var topAppsRow: some View {
        HStack(spacing: 6) {
            Text("TOP APPS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Color(white: 0.4))
            ForEach(Array(result.topAppIndices.enumerated()), id: \.offset) { pair in
                if pair.offset > 0 {
                    Text("·").foregroundStyle(Color(white: 0.35))
                }
                TrackedAppLabel(index: pair.element, showsIcon: true)
            }
            Spacer()
        }
        .font(.system(size: 11))
        .foregroundStyle(Color(white: 0.5))
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private func pill(for level: DangerZone.Level) -> some View {
        let (label, fg, bg): (String, Color, Color) = {
            switch level {
            case .clean:    return ("CLEAN",    Color(white: 0.55), Color(white: 0.12))
            case .low:      return ("LOW",      Color(white: 0.6),  Color(white: 0.12))
            case .moderate: return ("MOD",      Color(red: 0.85, green: 0.58, blue: 0.2),
                                                Color(red: 0.76, green: 0.50, blue: 0.13).opacity(0.15))
            case .danger:   return ("DANGER",   red,                red.opacity(0.15))
            }
        }()
        return Text(label)
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(fg)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    // MARK: Verdict banner

    private var verdictBanner: some View {
        let bgColor: Color = {
            switch result.tone {
            case .positive: return Color(red: 0.05, green: 0.18, blue: 0.08)
            case .neutral:  return Color(white: 0.07)
            case .warning:  return red.opacity(0.07)
            }
        }()
        let borderColor: Color = {
            switch result.tone {
            case .positive: return Color(red: 0.15, green: 0.45, blue: 0.22).opacity(0.4)
            case .neutral:  return Color(white: 0.12)
            case .warning:  return red.opacity(0.18)
            }
        }()
        let textColor: Color = {
            switch result.tone {
            case .positive: return Color(red: 0.4, green: 0.85, blue: 0.5)
            case .neutral:  return Color(white: 0.68)
            case .warning:  return Color(white: 0.8)
            }
        }()

        return Text(result.verdictLine)
            .font(.system(size: 13))
            .foregroundStyle(textColor)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(bgColor)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(borderColor, lineWidth: 0.5)
            )
    }

    // MARK: Formatter

    private func formatted(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
