import SwiftUI

struct ReceiptView: View {
    let receipt: DailyReceipt

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("WASTED")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(4)
                    .foregroundStyle(Color.inkFaint)

                Text(formattedDate)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color.ink.opacity(0.3))
                    .padding(.top, 4)

                DashedRule()
                    .padding(.vertical, 20)

                if receipt.items.isEmpty {
                    Text("nothing yet.")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(Color.inkFaint)
                } else {
                    itemRows

                    DashedRule()
                        .padding(.vertical, 20)

                    HStack(alignment: .firstTextBaseline) {
                        Text("total")
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(Color.inkFaint)
                        Spacer()
                        Text(AppGroupKeys.formattedDuration(receipt.totalSeconds))
                            .font(.system(size: 34, weight: .bold, design: .serif))
                            .foregroundStyle(receipt.totalSeconds >= 3600 ? Color.alarm : Color.ink)
                    }

                    Text("\(receipt.percentOfAwakeDay)% of your waking hours.")
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(Color.inkFaint)
                        .padding(.top, 16)
                }

                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 48)
        }
    }

    private var itemRows: some View {
        VStack(spacing: 14) {
            ForEach(receipt.items, id: \.name) { item in
                HStack {
                    Text(item.name.lowercased())
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(Color.ink.opacity(0.75))
                    Spacer()
                    Text(AppGroupKeys.formattedDuration(item.seconds))
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.ink.opacity(0.75))
                }
            }
        }
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: receipt.dateString) else { return receipt.dateString }
        let out = DateFormatter()
        out.dateFormat = "MMM d, yyyy"
        return out.string(from: date).lowercased()
    }
}

private struct DashedRule: View {
    var body: some View {
        Line()
            .stroke(Color.ink.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(height: 1)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return p
        }
    }
}

#Preview {
    ReceiptView(receipt: DailyReceipt(
        dateString: "2026-07-06",
        items: [
            .init(name: "Instagram", seconds: 6120),
            .init(name: "YouTube", seconds: 3480),
            .init(name: "X", seconds: 1920),
        ],
        totalSeconds: 11520,
        percentOfAwakeDay: 20
    ))
}
