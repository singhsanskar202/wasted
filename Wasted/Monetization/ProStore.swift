import Combine
import Foundation
import StoreKit

// Pro = the mirror's memory, three ways to buy it: monthly, yearly (with the
// App Store introductory offer as the trial), or once, forever. Any verified
// entitlement to any of the three unlocks the same single thing.
@MainActor
final class ProStore: ObservableObject {
    static let shared = ProStore()

    @Published var monthly: Product?
    @Published var yearly: Product?
    @Published var lifetime: Product?
    @Published var isUnlocked: Bool
    @Published var isPurchasing = false

    private let store = UsageStore()
    private var updatesTask: Task<Void, Never>?

    private static let productIDs = [
        AppGroupKeys.monthlyProductID,
        AppGroupKeys.yearlyProductID,
        AppGroupKeys.lifetimeProductID,
    ]

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
        monthly = products.first { $0.id == AppGroupKeys.monthlyProductID }
        yearly = products.first { $0.id == AppGroupKeys.yearlyProductID }
        lifetime = products.first { $0.id == AppGroupKeys.lifetimeProductID }
        await refreshEntitlement()
    }

    // Runs on every load() — which HomeView performs once per launch — so an
    // expired subscription is caught the next time the app opens, not never.
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
