import ComposableArchitecture
import PrimoCoreTypes
import PrimoNanoBananaApplication
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

private enum NanoBananaCommandBuilderKey: DependencyKey {
    static let liveValue = NanoBananaCommandBuilder()
}

private enum NanoBananaEditUseCaseKey: DependencyKey {
    static var liveValue: NanoBananaEditUseCase {
        @Dependency(\.httpClient) var httpClient
        let remoteClient = NanoBananaRemoteEditClient.live(httpClient: httpClient)
        return NanoBananaEditUseCase.live(remoteClient: remoteClient)
    }
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

    var nanoBananaCommandBuilder: NanoBananaCommandBuilder {
        get { self[NanoBananaCommandBuilderKey.self] }
        set { self[NanoBananaCommandBuilderKey.self] = newValue }
    }

    var nanoBananaEditUseCase: NanoBananaEditUseCase {
        get { self[NanoBananaEditUseCaseKey.self] }
        set { self[NanoBananaEditUseCaseKey.self] = newValue }
    }
}
