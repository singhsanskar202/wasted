import SwiftUI

// THE BILL, on the home screen, not hidden behind a button.
//
// The receipt is the metaphor this product owns, and it was buried in a sheet
// while the home screen showed a lonely number with no idea where it came from.
// A number can be argued with. An itemised bill — with the real app icons, the
// real names, and a total that adds up — cannot.
//
// A RECEIPT MUST ADD UP, and that turned out to be the hard part. The combined
// threshold series fires every minute; the per-app series fires every five. So on
// the device right now the true total is 19m while the last per-app threshold was
// 15m. Items summing to 15m under a TOTAL of 19m is a broken receipt, and for an
// app whose entire thesis is "the number is true", a receipt that doesn't
// reconcile is worse than no receipt.
//
// So the gap is named rather than fudged: "still counting" is real usage the OS
// has confirmed but not yet attributed to an app, and it shrinks to nothing as
// the per-app thresholds catch up. The receipt always balances.
struct ReceiptCard: View {
    let receipt: DailyReceipt
    let trueTotalSeconds: Int      // the authoritative total; ≥ the sum of items
    let isExpired: Bool
    let onTap: () -> Void

    private var unattributed: Int {
        max(0, trueTotalSeconds - receipt.items.reduce(0) { $0 + $1.seconds })
    }

    private var percentOfDay: Int {
        Int((Double(trueTotalSeconds) / Double(AppGroupKeys.awakeDayHours * 3600) * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            DashedRule().padding(.top, 16)

            if receipt.items.isEmpty && trueTotalSeconds == 0 {
                Text("nothing yet today.")
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color.ink.opacity(0.35))
                    .padding(.vertical, 26)
            } else {
                items.padding(.vertical, 20)
                DashedRule()
                total.padding(.top, 18)
            }

            DashedRule().padding(.top, 20)
            footer.padding(.top, 14)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.light()
            onTap()
        }
    }

    // MARK: - Parts

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("WASTED")
                .font(.system(size: 12, weight: .semibold))
                .tracking(4)
                .foregroundStyle(Color.ink.opacity(0.55))
            Spacer()
            Text(today)
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Color.ink.opacity(0.35))
        }
    }

    private var items: some View {
        VStack(spacing: 15) {
            ForEach(receipt.items, id: \.index) { item in
                HStack(alignment: .center, spacing: 10) {
                    // Real icon, real name. Label(token) only resolves inside the
                    // authorized foreground app — which is exactly where we are,
                    // and exactly why the island can never do this.
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

            // The reconciliation line. Only when it's real — a phantom "0m still
            // counting" row would be noise, and a receipt that invents rows to
            // balance is the thing this line exists to avoid.
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

    private var total: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("total")
                    .font(.system(size: 12, weight: .light))
                    .tracking(2)
                    .foregroundStyle(Color.ink.opacity(0.4))

                Spacer()

                Text(AppGroupKeys.formattedDuration(trueTotalSeconds))
                    .font(.system(size: 44, weight: .bold, design: .serif))
                    .foregroundStyle(Severity.dayColor(trueTotalSeconds))
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }

            Text("\(percentOfDay)% of your waking hours.")
                .font(.system(size: 15, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color.inkQuiet)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var footer: some View {
        HStack {
            if let equivalent = EquivalentTaskMapper.equivalent(for: trueTotalSeconds) {
                Text(equivalent.line)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color.ink.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.ink.opacity(0.25))
        }
    }

    private var today: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: Date()).lowercased()
    }
}

// A thermal-printer rule. The dashes are the whole reason this reads as a
// receipt and not as another card with a border.
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
