import Foundation
import PrimoAIImageDomain

public struct AIImageSettingsClient: Sendable {
    public let load: @Sendable () -> AIImageSettingsDraft
    public let persist: @Sendable (AIImageSettingsDraft) throws -> Void

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
}

public struct AIImageCommerceClient: Sendable {
    public let prepare: @Sendable () async -> AIImageCommerceSnapshot
    public let purchasePrimaryProduct: @Sendable () async -> AIImageCommerceSnapshot
    public let restorePurchases: @Sendable () async -> AIImageCommerceSnapshot
    public let clearPurchaseError: @Sendable () async -> AIImageCommerceSnapshot

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
}
