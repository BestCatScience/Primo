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
    var aiImageSettingsClient: NanoBananaSettingsClient {
        get { self[NanoBananaSettingsClientKey.self] }
        set { self[NanoBananaSettingsClientKey.self] = newValue }
    }

    var aiImageCommerceClient: NanoBananaCommerceClient {
        get { self[NanoBananaCommerceClientKey.self] }
        set { self[NanoBananaCommerceClientKey.self] = newValue }
    }

    var aiImageCommandBuilder: NanoBananaCommandBuilder {
        get { self[NanoBananaCommandBuilderKey.self] }
        set { self[NanoBananaCommandBuilderKey.self] = newValue }
    }

    var aiImageEditUseCase: NanoBananaEditUseCase {
        get { self[NanoBananaEditUseCaseKey.self] }
        set { self[NanoBananaEditUseCaseKey.self] = newValue }
    }

    var nanoBananaSettingsClient: NanoBananaSettingsClient {
        get { aiImageSettingsClient }
        set { aiImageSettingsClient = newValue }
    }

    var nanoBananaCommerceClient: NanoBananaCommerceClient {
        get { aiImageCommerceClient }
        set { aiImageCommerceClient = newValue }
    }

    var nanoBananaCommandBuilder: NanoBananaCommandBuilder {
        get { aiImageCommandBuilder }
        set { aiImageCommandBuilder = newValue }
    }

    var nanoBananaEditUseCase: NanoBananaEditUseCase {
        get { aiImageEditUseCase }
        set { aiImageEditUseCase = newValue }
    }
}
