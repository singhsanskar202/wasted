import Charts
import SwiftUI

struct HeatmapView: View {
    let hourlyData: HourlyUsage

    private var peakSeconds: Int {
        hourlyData.hours.values.max() ?? 1
    }

    // Red is reserved for "this number is bad" — the peak only earns it
    // once that hour crosses the danger threshold (1h).
    private var peakColor: Color {
        peakSeconds >= 3600 ? .alarm : Color.ink.opacity(0.75)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Most Distracted Hours")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
                if let peak = hourlyData.peakHour {
                    Text("Peak: \(hourLabel(peak))")
                        .font(.caption)
                        .foregroundStyle(peakColor)
                }
            }
            .padding(.horizontal, 24)

            Chart {
                ForEach(0..<24, id: \.self) { hour in
                    let seconds = hourlyData.hours[hour] ?? 0
                    BarMark(
                        x: .value("Hour", hour),
                        y: .value("Min", seconds / 60)
                    )
                    .foregroundStyle(seconds == peakSeconds && seconds > 0 ? peakColor : Color.ink.opacity(0.25))
                    .cornerRadius(2)
                }
            }
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                    AxisValueLabel {
                        if let h = value.as(Int.self) {
                            Text(hourLabel(h))
                                .font(.system(size: 9))
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 80)
            .padding(.horizontal, 24)
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0:  return "12a"
        case 12: return "12p"
        case 23: return "11p"
        default: return hour < 12 ? "\(hour)a" : "\(hour - 12)p"
        }
    }
}
