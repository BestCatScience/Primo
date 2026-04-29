import ComposableArchitecture
import PrimoCoreTypes

private enum DateClientKey: DependencyKey {
    static let liveValue = PrimoCoreTypes.DateClient.live
}

private enum UUIDClientKey: DependencyKey {
    static let liveValue = PrimoCoreTypes.UUIDClient.live
}

private enum FileClientKey: DependencyKey {
    static let liveValue = PrimoCoreTypes.FileClient.live
}

private enum ProcessEnvironmentClientKey: DependencyKey {
    static let liveValue = PrimoCoreTypes.ProcessEnvironmentClient.live
}

private enum HTTPClientKey: DependencyKey {
    static let liveValue = PrimoCoreTypes.HTTPClient.live
}

private enum KeyValueStoreClientKey: DependencyKey {
    static let liveValue = PrimoCoreTypes.KeyValueStoreClient.live
}

private enum SecretStoreClientKey: DependencyKey {
    static let liveValue = PrimoCoreTypes.SecretStoreClient.live
}

private enum SecurityScopedResourceClientKey: DependencyKey {
    static let liveValue = PrimoCoreTypes.SecurityScopedResourceClient.live
}

private enum AppLanguageClientKey: DependencyKey {
    static var liveValue: AppLanguageClient {
        @Dependency(\.keyValueStoreClient) var keyValueStoreClient
        return AppLanguageClient.live(keyValueStoreClient: keyValueStoreClient)
    }
}

private enum MainQueueClientKey: DependencyKey {
    static let liveValue = PrimoCoreTypes.MainQueueClient.live
}

extension DependencyValues {
    var dateClient: PrimoCoreTypes.DateClient {
        get { self[DateClientKey.self] }
        set { self[DateClientKey.self] = newValue }
    }

    var uuidClient: PrimoCoreTypes.UUIDClient {
        get { self[UUIDClientKey.self] }
        set { self[UUIDClientKey.self] = newValue }
    }

    var fileClient: PrimoCoreTypes.FileClient {
        get { self[FileClientKey.self] }
        set { self[FileClientKey.self] = newValue }
    }

    var processEnvironmentClient: PrimoCoreTypes.ProcessEnvironmentClient {
        get { self[ProcessEnvironmentClientKey.self] }
        set { self[ProcessEnvironmentClientKey.self] = newValue }
    }

    var httpClient: PrimoCoreTypes.HTTPClient {
        get { self[HTTPClientKey.self] }
        set { self[HTTPClientKey.self] = newValue }
    }

    var keyValueStoreClient: PrimoCoreTypes.KeyValueStoreClient {
        get { self[KeyValueStoreClientKey.self] }
        set { self[KeyValueStoreClientKey.self] = newValue }
    }

    var secretStoreClient: PrimoCoreTypes.SecretStoreClient {
        get { self[SecretStoreClientKey.self] }
        set { self[SecretStoreClientKey.self] = newValue }
    }

    var securityScopedResourceClient: PrimoCoreTypes.SecurityScopedResourceClient {
        get { self[SecurityScopedResourceClientKey.self] }
        set { self[SecurityScopedResourceClientKey.self] = newValue }
    }

    var appLanguageClient: AppLanguageClient {
        get { self[AppLanguageClientKey.self] }
        set { self[AppLanguageClientKey.self] = newValue }
    }

    var mainQueueClient: PrimoCoreTypes.MainQueueClient {
        get { self[MainQueueClientKey.self] }
        set { self[MainQueueClientKey.self] = newValue }
    }
}
