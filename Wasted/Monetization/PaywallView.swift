import StoreKit
import SwiftUI

// The two legal links the App Store requires on a subscription paywall.
// Terms is Apple's standard EULA (used because the app makes no custom
// terms); privacy is the policy served by the push worker.
enum LegalLinks {
    static let termsURL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    static let privacyURL = "https://wasted-push.singhsanskar2000.workers.dev/privacy"
}

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
                    // One purchase: pay once, own it forever. No subscription,
                    // no streak to protect — the product's whole posture.
                    purchaseButton(filled: true, label: lifetimeLabel, product: store.lifetime)

                    Button {
                        Task { await store.restore() }
                    } label: {
                        Text("restore purchase")
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(Color.ink.opacity(0.3))
                    }
                    .padding(.top, 6)

                    // Apple's standard EULA + the hosted privacy policy. Good
                    // practice and expected in the listing even for a one-time
                    // purchase.
                    HStack(spacing: 18) {
                        Link("terms", destination: URL(string: LegalLinks.termsURL)!)
                        Link("privacy", destination: URL(string: LegalLinks.privacyURL)!)
                    }
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color.ink.opacity(0.28))
                    .padding(.top, 10)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
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

    private var lifetimeLabel: String {
        guard let lifetime = store.lifetime else { return "loading…" }
        return "own it forever — \(lifetime.displayPrice)"
    }
}
