import StoreKit
import SwiftUI

// The paywall sells ONE thing — the mirror's memory — and says so plainly.
// No countdown, no fake discount, no preselected tricks: the mirror doesn't
// lie about time, so it doesn't get to lie about money. The daily mirror is
// free forever and this screen says that too, because a paywall that implies
// the app breaks without paying would be a lie of omission.
struct PaywallView: View {
    @ObservedObject var store: ProStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("the mirror\nremembers.")
                        .font(.system(size: 36, weight: .bold, design: .serif))
                        .foregroundStyle(Color.ink)
                        .lineSpacing(4)

                    Text("weeks. months. the all-time bill.\ntoday's mirror stays free, forever —\nthis buys its memory.")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Color.inkFaint)
                        .lineSpacing(6)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    // Yearly leads: it's the honest best value, and its intro
                    // offer — when configured — is the app's only trial.
                    purchaseButton(filled: true, label: yearlyLabel, product: store.yearly)
                    purchaseButton(filled: false, label: lifetimeLabel, product: store.lifetime)
                    purchaseButton(filled: false, label: monthlyLabel, product: store.monthly)

                    Button {
                        Task { await store.restore() }
                    } label: {
                        Text("restore purchases")
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(Color.ink.opacity(0.3))
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 44)
            }
        }
        .task { await store.load() }
        .onChange(of: store.isUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    @ViewBuilder
    private func purchaseButton(filled: Bool, label: String, product: Product?) -> some View {
        Button {
            guard let product else { return }
            Task { await store.purchase(product) }
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(filled ? .black : Color.ink.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(filled ? Color.ink : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(filled ? .clear : Color.ink.opacity(0.22), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(product == nil || store.isPurchasing)
        .opacity(product == nil ? 0.4 : 1)
    }

    // Labels state the real terms or nothing. The trial line only appears if
    // App Store Connect actually has a free introductory offer configured —
    // promising "7 days free" from copy alone would eventually be a lie.
    private var yearlyLabel: String {
        guard let yearly = store.yearly else { return "loading…" }
        if let offer = yearly.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
            return "\(trialLength(of: offer)) free, then \(yearly.displayPrice)/year"
        }
        return "\(yearly.displayPrice)/year"
    }

    private var monthlyLabel: String {
        guard let monthly = store.monthly else { return "loading…" }
        return "or \(monthly.displayPrice)/month"
    }

    private var lifetimeLabel: String {
        guard let lifetime = store.lifetime else { return "loading…" }
        return "own it forever — \(lifetime.displayPrice)"
    }

    private func trialLength(of offer: Product.SubscriptionOffer) -> String {
        let period = offer.period
        switch period.unit {
        case .day:   return "\(period.value) days"
        case .week:  return "\(period.value * 7) days"
        case .month: return period.value == 1 ? "1 month" : "\(period.value) months"
        case .year:  return period.value == 1 ? "1 year" : "\(period.value) years"
        @unknown default: return "\(period.value)"
        }
    }
}
