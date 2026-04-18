import Foundation
import PrimoCoreTypes
import PrimoLocalization

typealias DateClient = PrimoCoreTypes.DateClient
typealias UUIDClient = PrimoCoreTypes.UUIDClient
typealias FileClient = PrimoCoreTypes.FileClient
typealias HTTPClient = PrimoCoreTypes.HTTPClient
typealias KeyValueStoreClient = PrimoCoreTypes.KeyValueStoreClient
typealias SecurityScopedResourceClient = PrimoCoreTypes.SecurityScopedResourceClient

struct AppLanguageClient: Sendable {
    var load: @Sendable () -> AppLanguage
    var persist: @Sendable (AppLanguage) -> Void

    static func live(keyValueStoreClient: KeyValueStoreClient) -> AppLanguageClient {
        AppLanguageClient(
            load: {
                guard
                    let rawValue = keyValueStoreClient.stringForKey(AppLanguage.storageKey),
                    let language = AppLanguage(rawValue: rawValue)
                else {
                    return .japanese
                }
                return language
            },
            persist: { language in
                keyValueStoreClient.setString(language.rawValue, AppLanguage.storageKey)
            }
        )
    }
}
