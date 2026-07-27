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

    // The App Store can't load a product — sandbox timing, an agreement not yet
    // active, no network. Apple rejected 1.1(5) for exactly this: on an iPad the
    // Pro page "loaded indefinitely" because the button sat on "loading…" with no
    // way out. So the load is a small state machine with a hard timeout, and the
    // screen ALWAYS has a close button. A paywall the user can't leave is a bug
    // before it's ever a sale.
    private enum LoadPhase { case loading, ready, failed }
    @State private var phase: LoadPhase = .loading

    // StoreKit's product fetch can hang with no network; never let the spinner
    // outlive this.
    private static let loadTimeout: UInt64 = 15_000_000_000 // 15s

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
                    purchaseArea

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
        // Always an exit. Presented as a sheet, but a reviewer (or a user on a
        // flaky connection) must never be trapped waiting on the store.
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.ink.opacity(0.4))
                    .padding(14)
                    .contentShape(Rectangle())
            }
            .padding(.top, 6)
            .padding(.trailing, 6)
            .accessibilityLabel("close")
        }
        .task { await loadProducts() }
        .onChange(of: store.isUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    // The purchase control, by phase: the real button once the product is here,
    // a brief "loading…", or an honest failure with a way to retry — never an
    // endless spinner.
    @ViewBuilder
    private var purchaseArea: some View {
        switch phase {
        case .ready:
            // One purchase: pay once, own it forever. No subscription, no streak
            // to protect — the product's whole posture.
            purchaseButton(filled: true, label: lifetimeLabel, product: store.lifetime)
        case .loading:
            purchaseButton(filled: true, label: "loading…", product: nil)
        case .failed:
            VStack(spacing: 10) {
                Text("couldn't reach the store. check your connection.")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Color.inkFaint)
                    .multilineTextAlignment(.center)
                Button { Task { await loadProducts() } } label: {
                    Text("try again")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.ink.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.ink.opacity(0.22), lineWidth: 1)
                        )
                }
            }
        }
    }

    private func loadProducts() async {
        phase = .loading
        // Race the fetch against a timeout: whichever finishes first wins, so a
        // StoreKit call that never returns can't pin the screen on "loading…".
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await store.load() }
            group.addTask { try? await Task.sleep(nanoseconds: Self.loadTimeout) }
            await group.next()
            group.cancelAll()
        }
        phase = store.lifetime == nil ? .failed : .ready
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
