import ComposableArchitecture
import PrimoCoreTypes
import PrimoAIImageApplication
import PrimoAIImageInfrastructure

private enum AIImageSettingsClientKey: DependencyKey {
    static var liveValue: AIImageSettingsClient {
        @Dependency(\.keyValueStoreClient) var keyValueStoreClient
        return AIImageSettingsClient.live(keyValueStoreClient: keyValueStoreClient)
    }
}

private enum AIImageCommerceClientKey: DependencyKey {
    static let liveValue = AIImageCommerceClient.live()
}

private enum AIImageCommandBuilderKey: DependencyKey {
    static let liveValue = AIImageCommandBuilder()
}

private enum AIImageEditUseCaseKey: DependencyKey {
    static var liveValue: AIImageEditUseCase {
        @Dependency(\.httpClient) var httpClient
        let remoteClient = AIImageRemoteEditClient.live(httpClient: httpClient)
        return AIImageEditUseCase.live(remoteClient: remoteClient)
    }
}

extension DependencyValues {
    var aiImageSettingsClient: AIImageSettingsClient {
        get { self[AIImageSettingsClientKey.self] }
        set { self[AIImageSettingsClientKey.self] = newValue }
    }

    var aiImageCommerceClient: AIImageCommerceClient {
        get { self[AIImageCommerceClientKey.self] }
        set { self[AIImageCommerceClientKey.self] = newValue }
    }

    var aiImageCommandBuilder: AIImageCommandBuilder {
        get { self[AIImageCommandBuilderKey.self] }
        set { self[AIImageCommandBuilderKey.self] = newValue }
    }

    var aiImageEditUseCase: AIImageEditUseCase {
        get { self[AIImageEditUseCaseKey.self] }
        set { self[AIImageEditUseCaseKey.self] = newValue }
    }
}
