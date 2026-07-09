import Combine
import Foundation
import StoreKit

@MainActor
final class LifetimeStore: ObservableObject {
    static let shared = LifetimeStore()

    @Published var product: Product?
    @Published var isUnlocked: Bool
    @Published var isPurchasing = false

    private let store = UsageStore()
    private var updatesTask: Task<Void, Never>?

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
        product = try? await Product.products(for: [AppGroupKeys.lifetimeProductID]).first
        await refreshEntitlement()
    }

    func refreshEntitlement() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == AppGroupKeys.lifetimeProductID {
                unlocked = true
            }
        }
        isUnlocked = unlocked
        store.setUnlocked(unlocked)
    }

    func purchase() async {
        guard let product else { return }
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
              transaction.productID == AppGroupKeys.lifetimeProductID
        else { return }
        isUnlocked = true
        store.setUnlocked(true)
        await transaction.finish()
    }
}
