import ComposableArchitecture
import PrimoNanoBananaInfrastructure

private enum NanoBananaSettingsClientKey: DependencyKey {
    static var liveValue: NanoBananaSettingsClient {
        @Dependency(\.keyValueStoreClient) var keyValueStoreClient
        return NanoBananaSettingsClient.live(keyValueStoreClient: keyValueStoreClient)
    }
}

private enum NanoBananaCommerceClientKey: DependencyKey {
    static let liveValue = NanoBananaCommerceClient.live()
}

extension DependencyValues {
    var nanoBananaSettingsClient: NanoBananaSettingsClient {
        get { self[NanoBananaSettingsClientKey.self] }
        set { self[NanoBananaSettingsClientKey.self] = newValue }
    }

    var nanoBananaCommerceClient: NanoBananaCommerceClient {
        get { self[NanoBananaCommerceClientKey.self] }
        set { self[NanoBananaCommerceClientKey.self] = newValue }
    }
}
