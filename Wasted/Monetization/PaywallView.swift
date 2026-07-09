import StoreKit
import SwiftUI

struct PaywallView: View {
    @ObservedObject var store: LifetimeStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("keep the\nmirror.")
                        .font(.system(size: 36, weight: .bold, design: .serif))
                        .foregroundStyle(Color.ink)
                        .lineSpacing(4)

                    Text("no subscription. no streak to protect.\npay once. it's yours — until you\ndon't need it anymore.")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Color.inkFaint)
                        .lineSpacing(6)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        Task { await store.purchase() }
                    } label: {
                        Text(purchaseLabel)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(store.product == nil || store.isPurchasing)
                    .opacity(store.product == nil ? 0.4 : 1)

                    Button {
                        Task { await store.restore() }
                    } label: {
                        Text("restore purchases")
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(Color.ink.opacity(0.3))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
        .task { await store.load() }
        .onChange(of: store.isUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    private var purchaseLabel: String {
        guard let product = store.product else { return "loading…" }
        return "unlock forever — \(product.displayPrice)"
    }
}
