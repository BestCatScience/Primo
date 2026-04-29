import Foundation
import PrimoCoreTypes
import PrimoNanoBananaDomain
import StoreKit

public struct NanoBananaSettingsClient: Sendable {
    public var load: @Sendable () -> NanoBananaSettings
    public var persist: @Sendable (NanoBananaSettings) -> Void

    public static let accessModeStorageKey = "primo.nanobanana.accessMode"
    public static let apiKeyStorageKey = "primo.nanobanana.apiKey"
    public static let openAIAPIKeyStorageKey = "primo.aiImage.openAIAPIKey"

    public init(
        load: @escaping @Sendable () -> NanoBananaSettings,
        persist: @escaping @Sendable (NanoBananaSettings) -> Void
    ) {
        self.load = load
        self.persist = persist
    }

    public static func live(keyValueStoreClient: KeyValueStoreClient) -> NanoBananaSettingsClient {
        NanoBananaSettingsClient(
            load: {
                let rawAccessMode = keyValueStoreClient.stringForKey(Self.accessModeStorageKey)
                let accessMode = rawAccessMode.flatMap(NanoBananaAccessMode.init(rawValue:)) ?? .appManaged
                let apiKey = keyValueStoreClient.stringForKey(Self.apiKeyStorageKey) ?? ""
                let openAIAPIKey = keyValueStoreClient.stringForKey(Self.openAIAPIKeyStorageKey) ?? ""
                return NanoBananaSettings(
                    accessMode: accessMode,
                    apiKey: apiKey,
                    openAIAPIKey: openAIAPIKey
                )
            },
            persist: { settings in
                keyValueStoreClient.setString(settings.accessMode.rawValue, Self.accessModeStorageKey)
                keyValueStoreClient.setString(settings.apiKey, Self.apiKeyStorageKey)
                keyValueStoreClient.setString(settings.openAIAPIKey, Self.openAIAPIKeyStorageKey)
            }
        )
    }
}

public struct NanoBananaCommerceState: Equatable, Sendable {
    public var primaryProduct: NanoBananaCommerceSnapshot.ProductSummary?
    public var isLoading: Bool
    public var isSubscriptionActive: Bool
    public var latestEntitlementJWS: String
    public var purchaseErrorMessage: String?
    public var proxyEndpoint: String

    public init(
        primaryProduct: NanoBananaCommerceSnapshot.ProductSummary? = nil,
        isLoading: Bool = false,
        isSubscriptionActive: Bool = false,
        latestEntitlementJWS: String = "",
        purchaseErrorMessage: String? = nil,
        proxyEndpoint: String = ""
    ) {
        self.primaryProduct = primaryProduct
        self.isLoading = isLoading
        self.isSubscriptionActive = isSubscriptionActive
        self.latestEntitlementJWS = latestEntitlementJWS
        self.purchaseErrorMessage = purchaseErrorMessage
        self.proxyEndpoint = proxyEndpoint
    }

    public func snapshot() -> NanoBananaCommerceSnapshot {
        NanoBananaCommerceSnapshot(
            primaryProduct: primaryProduct,
            isLoading: isLoading,
            isSubscriptionActive: isSubscriptionActive,
            latestEntitlementJWS: latestEntitlementJWS,
            purchaseErrorMessage: purchaseErrorMessage,
            manageSubscriptionsURL: URL(string: "https://apps.apple.com/account/subscriptions"),
            proxyEndpoint: proxyEndpoint
        )
    }
}

public struct NanoBananaCommerceClient: Sendable {
    public var prepare: @Sendable () async -> NanoBananaCommerceSnapshot
    public var purchasePrimaryProduct: @Sendable () async -> NanoBananaCommerceSnapshot
    public var restorePurchases: @Sendable () async -> NanoBananaCommerceSnapshot
    public var clearPurchaseError: @Sendable () async -> NanoBananaCommerceSnapshot

    public init(
        prepare: @escaping @Sendable () async -> NanoBananaCommerceSnapshot,
        purchasePrimaryProduct: @escaping @Sendable () async -> NanoBananaCommerceSnapshot,
        restorePurchases: @escaping @Sendable () async -> NanoBananaCommerceSnapshot,
        clearPurchaseError: @escaping @Sendable () async -> NanoBananaCommerceSnapshot
    ) {
        self.prepare = prepare
        self.purchasePrimaryProduct = purchasePrimaryProduct
        self.restorePurchases = restorePurchases
        self.clearPurchaseError = clearPurchaseError
    }

    @available(macOS 12.0, iOS 15.0, *)
    public static func live(bundle: Bundle = .main) -> NanoBananaCommerceClient {
        let store = NanoBananaCommerceStore(bundle: bundle)
        return NanoBananaCommerceClient(
            prepare: {
                await store.prepare()
            },
            purchasePrimaryProduct: {
                await store.purchasePrimaryProduct()
            },
            restorePurchases: {
                await store.restorePurchases()
            },
            clearPurchaseError: {
                await store.clearPurchaseError()
            }
        )
    }
}

@available(macOS 12.0, iOS 15.0, *)
private actor NanoBananaCommerceStore {
    static let monthlyProductID = "com.bestcatscience.primo.nanobanana.monthly"

    private var products: [Product] = []
    private var state: NanoBananaCommerceState
    private var transactionUpdatesTask: Task<Void, Never>?

    init(bundle: Bundle = .main) {
        state = NanoBananaCommerceState(
            proxyEndpoint: (bundle.object(forInfoDictionaryKey: "NanoBananaProxyEndpoint") as? String) ?? ""
        )
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func prepare() async -> NanoBananaCommerceSnapshot {
        startObservingTransactionsIfNeeded()
        if products.isEmpty {
            await loadProducts()
        }
        await refreshEntitlements()
        return state.snapshot()
    }

    func purchasePrimaryProduct() async -> NanoBananaCommerceSnapshot {
        guard let product = products.first else {
            state.purchaseErrorMessage = "Subscription product is unavailable."
            return state.snapshot()
        }

        state.isLoading = true
        state.purchaseErrorMessage = nil
        defer { state.isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    state.purchaseErrorMessage = "Purchase verification failed."
                    return state.snapshot()
                }
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            state.purchaseErrorMessage = error.localizedDescription
        }

        return state.snapshot()
    }

    func restorePurchases() async -> NanoBananaCommerceSnapshot {
        state.isLoading = true
        state.purchaseErrorMessage = nil
        defer { state.isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            state.purchaseErrorMessage = error.localizedDescription
        }

        return state.snapshot()
    }

    func clearPurchaseError() -> NanoBananaCommerceSnapshot {
        state.purchaseErrorMessage = nil
        return state.snapshot()
    }

    private func loadProducts() async {
        state.isLoading = true
        state.purchaseErrorMessage = nil
        defer { state.isLoading = false }

        do {
            products = try await Product.products(for: [Self.monthlyProductID])
                .sorted { $0.displayName < $1.displayName }
            state.primaryProduct = products.first.map {
                NanoBananaCommerceSnapshot.ProductSummary(
                    id: $0.id,
                    displayName: $0.displayName,
                    displayPrice: $0.displayPrice
                )
            }
        } catch {
            state.purchaseErrorMessage = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        var isSubscriptionActive = false
        var latestEntitlementJWS = ""

        for await result in Transaction.currentEntitlements {
            let entitlementJWS = result.jwsRepresentation
            guard case let .verified(transaction) = result else { continue }
            guard transaction.productID == Self.monthlyProductID else { continue }
            guard transaction.revocationDate == nil else { continue }

            isSubscriptionActive = true
            latestEntitlementJWS = entitlementJWS
        }

        state.isSubscriptionActive = isSubscriptionActive
        state.latestEntitlementJWS = latestEntitlementJWS
    }

    private func startObservingTransactionsIfNeeded() {
        guard transactionUpdatesTask == nil else { return }
        transactionUpdatesTask = Task { [self] in
            for await result in Transaction.updates {
                if case let .verified(transaction) = result {
                    await transaction.finish()
                }
                await refreshEntitlements()
            }
        }
    }
}
