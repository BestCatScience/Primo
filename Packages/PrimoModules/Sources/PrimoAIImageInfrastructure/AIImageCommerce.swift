import Foundation
import PrimoCoreTypes
import PrimoAIImageDomain
import StoreKit

public struct AIImageSettingsClient: Sendable {
    public var load: @Sendable () -> AIImageSettingsDraft
    public var persist: @Sendable (AIImageSettingsDraft) throws -> Void

    public static let accessModeStorageKey = "primo.aiimage.accessMode"
    public static let apiKeyStorageKey = "primo.aiimage.apiKey"
    public static let openAIAPIKeyStorageKey = "primo.aiimage.openAIAPIKey"

    public init(
        load: @escaping @Sendable () -> AIImageSettingsDraft,
        persist: @escaping @Sendable (AIImageSettingsDraft) throws -> Void
    ) {
        self.load = load
        self.persist = persist
    }

    public static func live(
        keyValueStoreClient: KeyValueStoreClient,
        secretStoreClient: SecretStoreClient
    ) -> AIImageSettingsClient {
        AIImageSettingsClient(
            load: {
                let rawAccessMode = keyValueStoreClient.stringForKey(Self.accessModeStorageKey)
                let accessMode = rawAccessMode.flatMap(AIImageAccessMode.init(rawValue:)) ?? .appManaged
                let apiKey = migratedSecret(
                    key: Self.apiKeyStorageKey,
                    keyValueStoreClient: keyValueStoreClient,
                    secretStoreClient: secretStoreClient
                )
                let openAIAPIKey = migratedSecret(
                    key: Self.openAIAPIKeyStorageKey,
                    keyValueStoreClient: keyValueStoreClient,
                    secretStoreClient: secretStoreClient
                )
                return AIImageSettingsDraft(
                    accessMode: accessMode,
                    apiKey: apiKey,
                    openAIAPIKey: openAIAPIKey
                )
            },
            persist: { settings in
                keyValueStoreClient.setString(settings.accessMode.rawValue, Self.accessModeStorageKey)
                try secretStoreClient.writeSecret(secretOrNil(settings.apiKey), Self.apiKeyStorageKey)
                try secretStoreClient.writeSecret(secretOrNil(settings.openAIAPIKey), Self.openAIAPIKeyStorageKey)
                keyValueStoreClient.setString(nil, Self.apiKeyStorageKey)
                keyValueStoreClient.setString(nil, Self.openAIAPIKeyStorageKey)
            }
        )
    }

    private static func migratedSecret(
        key: String,
        keyValueStoreClient: KeyValueStoreClient,
        secretStoreClient: SecretStoreClient
    ) -> String {
        if let secret = (try? secretStoreClient.readSecret(key)) ?? nil {
            return secret
        }
        guard let legacySecret = keyValueStoreClient.stringForKey(key), !legacySecret.isEmpty else {
            return ""
        }
        if migrateLegacySecretIfPossible(legacySecret, key: key, secretStoreClient: secretStoreClient) {
            keyValueStoreClient.setString(nil, key)
        }
        return legacySecret
    }

    private static func migrateLegacySecretIfPossible(
        _ secret: String?,
        key: String,
        secretStoreClient: SecretStoreClient
    ) -> Bool {
        do {
            try secretStoreClient.writeSecret(secret, key)
            return true
        } catch {
            return false
        }
    }

    private static func secretOrNil(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }
}

public struct AIImageCommerceState: Equatable, Sendable {
    public var primaryProduct: AIImageCommerceSnapshot.ProductSummary?
    public var isLoading: Bool
    public var isSubscriptionActive: Bool
    public var latestEntitlementJWS: String
    public var purchaseErrorMessage: String?
    public var proxyEndpoint: String

    public init(
        primaryProduct: AIImageCommerceSnapshot.ProductSummary? = nil,
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

    public func snapshot() -> AIImageCommerceSnapshot {
        AIImageCommerceSnapshot(
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

public struct AIImageCommerceClient: Sendable {
    public var prepare: @Sendable () async -> AIImageCommerceSnapshot
    public var purchasePrimaryProduct: @Sendable () async -> AIImageCommerceSnapshot
    public var restorePurchases: @Sendable () async -> AIImageCommerceSnapshot
    public var clearPurchaseError: @Sendable () async -> AIImageCommerceSnapshot

    public init(
        prepare: @escaping @Sendable () async -> AIImageCommerceSnapshot,
        purchasePrimaryProduct: @escaping @Sendable () async -> AIImageCommerceSnapshot,
        restorePurchases: @escaping @Sendable () async -> AIImageCommerceSnapshot,
        clearPurchaseError: @escaping @Sendable () async -> AIImageCommerceSnapshot
    ) {
        self.prepare = prepare
        self.purchasePrimaryProduct = purchasePrimaryProduct
        self.restorePurchases = restorePurchases
        self.clearPurchaseError = clearPurchaseError
    }

    @available(macOS 12.0, iOS 15.0, *)
    public static func live(bundle: Bundle = .main) -> AIImageCommerceClient {
        let store = AIImageCommerceStore(bundle: bundle)
        return AIImageCommerceClient(
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
private actor AIImageCommerceStore {
    static let monthlyProductID = "com.bestcatscience.primo.aiimage.monthly"

    private var products: [Product] = []
    private var state: AIImageCommerceState
    private var transactionUpdatesTask: Task<Void, Never>?

    init(bundle: Bundle = .main) {
        state = AIImageCommerceState(
            proxyEndpoint: (bundle.object(forInfoDictionaryKey: "AIImageProxyEndpoint") as? String) ?? ""
        )
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func prepare() async -> AIImageCommerceSnapshot {
        startObservingTransactionsIfNeeded()
        if products.isEmpty {
            await loadProducts()
        }
        await refreshEntitlements()
        return state.snapshot()
    }

    func purchasePrimaryProduct() async -> AIImageCommerceSnapshot {
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

    func restorePurchases() async -> AIImageCommerceSnapshot {
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

    func clearPurchaseError() -> AIImageCommerceSnapshot {
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
                AIImageCommerceSnapshot.ProductSummary(
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
