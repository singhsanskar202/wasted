import Combine
import Foundation
import StoreKit

// Pro = the mirror's memory, bought once, forever. Monthly/yearly subscriptions
// were built and then pulled before launch (Sanskar's call) — lifetime only for
// now. The subscription plumbing can come back by re-adding the product IDs.
@MainActor
final class ProStore: ObservableObject {
    static let shared = ProStore()

    @Published var lifetime: Product?
    @Published var isUnlocked: Bool
    @Published var isPurchasing = false

    private let store = UsageStore()
    private var updatesTask: Task<Void, Never>?

    private static let productIDs = [AppGroupKeys.lifetimeProductID]

    var isPro: Bool { ProGate.isPro(unlocked: isUnlocked) }

    init() {
        isUnlocked = store.isUnlocked()
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func load() async {
        let products = (try? await Product.products(for: Self.productIDs)) ?? []
        lifetime = products.first { $0.id == AppGroupKeys.lifetimeProductID }
        await refreshEntitlement()
    }

    func refreshEntitlement() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIDs.contains(transaction.productID) {
                unlocked = true
            }
        }
        isUnlocked = unlocked
        store.setUnlocked(unlocked)
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }

        guard let result = try? await product.purchase() else { return }
        switch result {
        case .success(let verification):
            await handle(verification)
            Haptics.success()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    // MARK: - Private

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result,
              Self.productIDs.contains(transaction.productID)
        else { return }
        isUnlocked = true
        store.setUnlocked(true)
        await transaction.finish()
    }
}
