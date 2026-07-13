import SwiftUI

// The itemised bill. This is what you open the receipt FOR — the home screen
// shows one number, because a glance can only hold one number.
//
// A RECEIPT MUST ADD UP, and that turns out to be the hard part. The combined
// threshold series fires every minute; the per-app series fires every five. So a
// true total of 19m can sit above items summing to 15m — and a receipt whose
// lines don't reconcile is worse than no receipt at all in an app whose entire
// thesis is that the number is true.
//
// The gap is NAMED, not fudged: "still counting" is real usage iOS has confirmed
// but not yet attributed to an app, and it shrinks to nothing as the per-app
// thresholds catch up. The receipt always balances.
struct ReceiptView: View {
    let receipt: DailyReceipt
    /// The authoritative total. Always ≥ the sum of the items.
    let trueTotalSeconds: Int

    private var unattributed: Int {
        max(0, trueTotalSeconds - receipt.items.reduce(0) { $0 + $1.seconds })
    }

    private var percentOfDay: Int {
        Int((Double(trueTotalSeconds) / Double(AppGroupKeys.awakeDayHours * 3600) * 100).rounded())
    }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("WASTED")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(4)
                        .foregroundStyle(Color.ink.opacity(0.55))
                    Spacer()
                    Text(formattedDate)
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Color.ink.opacity(0.35))
                }

                DashedRule().padding(.vertical, 20)

                if receipt.items.isEmpty && trueTotalSeconds == 0 {
                    Text("nothing yet today.")
                        .font(.system(size: 20, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(Color.ink.opacity(0.4))
                } else {
                    itemRows

                    DashedRule().padding(.vertical, 20)

                    HStack(alignment: .firstTextBaseline) {
                        Text("total")
                            .font(.system(size: 12, weight: .light))
                            .tracking(2)
                            .foregroundStyle(Color.ink.opacity(0.4))
                        Spacer()
                        Text(AppGroupKeys.formattedDuration(trueTotalSeconds))
                            .font(.system(size: 38, weight: .bold, design: .serif))
                            .foregroundStyle(Severity.dayColor(trueTotalSeconds))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }

                    Text("\(percentOfDay)% of your waking hours.")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(Color.inkQuiet)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 10)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
    }

    private var itemRows: some View {
        VStack(spacing: 15) {
            ForEach(receipt.items, id: \.index) { item in
                HStack(spacing: 10) {
                    // Real icon, real name. Label(token) only resolves inside the
                    // authorized foreground app — which is exactly where we are,
                    // and exactly why the Live Activity can never do this.
                    TrackedAppLabel(index: item.index, fallback: item.name.lowercased(), showsIcon: true)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.ink.opacity(0.85))
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    Text(AppGroupKeys.formattedDuration(item.seconds))
                        .font(.system(size: 15, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(Color.ink.opacity(0.85))
                }
            }

            // Only when it's real. A phantom "0m still counting" row would be
            // noise, and a receipt that invents rows to balance is precisely the
            // thing this line exists to avoid.
            if unattributed >= 60 {
                HStack {
                    Text("still counting")
                        .font(.system(size: 15, weight: .light))
                        .italic()
                        .foregroundStyle(Color.ink.opacity(0.4))
                    Spacer()
                    Text(AppGroupKeys.formattedDuration(unattributed))
                        .font(.system(size: 15, weight: .light))
                        .monospacedDigit()
                        .foregroundStyle(Color.ink.opacity(0.4))
                }
            }
        }
    }

    private var formattedDate: String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: receipt.dateString) else { return receipt.dateString }
        let out = DateFormatter()
        out.dateFormat = "EEE d MMM"
        return out.string(from: date).lowercased()
    }
}

// A thermal-printer rule. The dashes are the whole reason this reads as a receipt
// and not as another card with a border.
struct DashedRule: View {
    var body: some View {
        Line()
            .stroke(Color.ink.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            .frame(height: 1)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

#Preview {
    ReceiptView(
        receipt: DailyReceipt(
            dateString: "2026-07-13",
            items: [
                .init(index: "0", name: "Instagram", seconds: 6120),
                .init(index: "1", name: "YouTube", seconds: 3480),
            ],
            totalSeconds: 9600,
            percentOfAwakeDay: 17
        ),
        trueTotalSeconds: 9900
    )
}
