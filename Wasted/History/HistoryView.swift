import SwiftUI

// The Pro surface. Same bones as the daily receipt — wordmark, dashed rules, a
// ledger — because it IS the receipt, just longer. One number shouts (the
// all-time total); the months answer to it.
struct HistoryView: View {
    let receipt: LongReceipt?

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("WASTED")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(4)
                            .foregroundStyle(Color.ink.opacity(0.55))
                        Spacer()
                        Text("the long receipt")
                            .font(.system(size: 12, weight: .light))
                            .italic()
                            .foregroundStyle(Color.ink.opacity(0.35))
                    }

                    DashedRule().padding(.vertical, 20)

                    if let receipt {
                        content(receipt)
                    } else {
                        // Stated, not drawn — a zeroed ledger reads as broken.
                        Text("nothing on file yet.")
                            .font(.system(size: 20, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(Color.ink.opacity(0.4))
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 30)
                .padding(.top, 40)
            }
        }
    }

    @ViewBuilder
    private func content(_ receipt: LongReceipt) -> some View {
        // The sandwich, same as home: caption, number, caption.
        VStack(spacing: 0) {
            HeroCaption(text: "you have wasted")

            Text(LongReceipt.formattedSpan(receipt.allTimeSeconds))
                .font(.system(size: 56, weight: .bold, design: .serif))
                .foregroundStyle(Severity.dayColor(receipt.averageDaySeconds))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.top, 12)

            // "days on file" was a ledger row once — bookkeeping wearing a
            // number's clothes. It answers no question of the user's; it
            // belongs in the caption, qualifying the hero.
            HeroCaption(text: "since \(LongReceipt.dayLabel(receipt.sinceDate)) — \(receipt.daysCounted) days")
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)

        DashedRule().padding(.vertical, 20)

        LedgerRow(label: "average day", value: AppGroupKeys.formattedDuration(receipt.averageDaySeconds))
        LedgerRow(label: "worst day — \(LongReceipt.dayLabel(receipt.worstDayDate))") {
            Text(AppGroupKeys.formattedDuration(receipt.worstDaySeconds))
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Severity.dayColor(receipt.worstDaySeconds))
        }

        // THE TRAJECTORY — the fact that makes history actionable without a
        // word of advice: is it moving? Absent until 14 days exist.
        if let lastSeven = receipt.lastSevenSeconds, let previousSeven = receipt.previousSevenSeconds {
            LedgerRow(label: "last 7 days", value: AppGroupKeys.formattedDuration(lastSeven))
            LedgerRow(label: "the 7 before", value: AppGroupKeys.formattedDuration(previousSeven))

            MirrorLine(text: LongReceipt.trendLine(lastSeven: lastSeven, previousSeven: previousSeven), size: 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        }

        // A single month under an all-time hero is the same number printed
        // twice — the exact sin that got itemisation thrown off the home
        // screen. Months appear when there are months to compare.
        if receipt.months.count >= 2 {
            DashedRule().padding(.vertical, 20)

            SectionLabel(text: "by month")
                .padding(.bottom, 4)

            ForEach(receipt.months) { month in
                LedgerRow(label: month.label, value: AppGroupKeys.formattedDuration(month.seconds))
            }
        }

        if let projected = receipt.projectedYearSeconds {
            DashedRule().padding(.vertical, 20)

            MirrorLine(text: LongReceipt.projectionLine(projectedYearSeconds: projected))
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }
}
