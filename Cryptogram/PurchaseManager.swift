import Combine
import Foundation
import StoreKit

enum PurchaseStatus {
    case idle
    case unavailable
    case verificationFailed
    case adsRemoved
    case purchaseCompleted
    case pending
    case cancelled
    case unknown
    case purchaseFailed
    case restored
    case notFound
    case restoreFailed
    case loadFailed
}

@MainActor
final class PurchaseManager: ObservableObject {
    static let removeAdsProductID = "SmitBY.Cryptogram.remove_ads"

    @Published private(set) var removeAdsProduct: Product?
    @Published private(set) var isAdsRemoved = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPerformingAction = false
    @Published private(set) var status: PurchaseStatus = .idle

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = observeTransactionUpdates()

        Task {
            await prepareStore()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var displayPrice: String? {
        removeAdsProduct?.displayPrice
    }

    var canPurchase: Bool {
        !isAdsRemoved && removeAdsProduct != nil && !isPerformingAction
    }

    var canRestore: Bool {
        !isPerformingAction
    }

    func prepareStore() async {
        await loadProductsIfNeeded()
        await refreshEntitlements()
    }

    func purchaseRemoveAds() async {
        status = .idle
        await loadProductsIfNeeded()

        guard let removeAdsProduct else {
            status = .unavailable
            return
        }

        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            let result = try await removeAdsProduct.purchase()

            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    status = .verificationFailed
                    return
                }

                await refreshEntitlements()
                await transaction.finish()
                status = isAdsRemoved ? .adsRemoved : .purchaseCompleted
            case .pending:
                status = .pending
            case .userCancelled:
                status = .cancelled
            @unknown default:
                status = .unknown
            }
        } catch {
            status = .purchaseFailed
        }
    }

    func restorePurchases() async {
        status = .idle
        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            status = isAdsRemoved ? .restored : .notFound
        } catch {
            status = .restoreFailed
        }
    }

    private func loadProductsIfNeeded() async {
        guard removeAdsProduct == nil, !isLoadingProducts else {
            return
        }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: [Self.removeAdsProductID])
            removeAdsProduct = products.first
        } catch {
            status = .loadFailed
        }
    }

    private func refreshEntitlements() async {
        var hasRemoveAds = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            guard transaction.productID == Self.removeAdsProductID,
                  transaction.revocationDate == nil else {
                continue
            }

            hasRemoveAds = true
            break
        }

        isAdsRemoved = hasRemoveAds
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else {
                return
            }

            for await result in Transaction.updates {
                await self.handle(transactionResult: result)
            }
        }
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = transactionResult else {
            return
        }

        await refreshEntitlements()
        await transaction.finish()
    }
}
