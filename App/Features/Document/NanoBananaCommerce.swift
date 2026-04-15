import Foundation
import StoreKit

@MainActor
final class NanoBananaCommerce: ObservableObject {
    static let monthlyProductID = "com.bestcatscience.primo.nanobanana.monthly"

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSubscriptionActive = false
    @Published private(set) var latestEntitlementJWS = ""
    @Published private(set) var purchaseErrorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func prepare() async {
        startObservingTransactionsIfNeeded()
        if products.isEmpty {
            await loadProducts()
        }
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoading = true
        purchaseErrorMessage = nil
        defer { isLoading = false }

        do {
            products = try await Product.products(for: [Self.monthlyProductID])
                .sorted { $0.displayName < $1.displayName }
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    func purchasePrimaryProduct() async {
        guard let product = products.first else {
            purchaseErrorMessage = "Subscription product is unavailable."
            return
        }

        isLoading = true
        purchaseErrorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    purchaseErrorMessage = "Purchase verification failed."
                    return
                }
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        purchaseErrorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var active = false
        var latestJWS = ""

        for await result in Transaction.currentEntitlements {
            let entitlementJWS = result.jwsRepresentation
            guard case let .verified(transaction) = result else { continue }
            guard transaction.productID == Self.monthlyProductID else { continue }
            guard transaction.revocationDate == nil else { continue }

            active = true
            latestJWS = entitlementJWS
        }

        isSubscriptionActive = active
        latestEntitlementJWS = latestJWS
    }

    func clearPurchaseError() {
        purchaseErrorMessage = nil
    }

    var primaryProduct: Product? {
        products.first
    }

    var manageSubscriptionsURL: URL? {
        URL(string: "https://apps.apple.com/account/subscriptions")
    }

    var proxyEndpoint: String {
        (Bundle.main.object(forInfoDictionaryKey: "NanoBananaProxyEndpoint") as? String) ?? ""
    }

    private func startObservingTransactionsIfNeeded() {
        guard transactionUpdatesTask == nil else { return }
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case let .verified(transaction) = result {
                    await transaction.finish()
                }
                await self.refreshEntitlements()
            }
        }
    }
}
