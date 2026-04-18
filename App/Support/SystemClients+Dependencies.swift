import ComposableArchitecture

private enum DateClientKey: DependencyKey {
    static let liveValue = DateClient.live
}

private enum UUIDClientKey: DependencyKey {
    static let liveValue = UUIDClient.live
}

private enum FileClientKey: DependencyKey {
    static let liveValue = FileClient.live
}

private enum HTTPClientKey: DependencyKey {
    static let liveValue = HTTPClient.live
}

private enum KeyValueStoreClientKey: DependencyKey {
    static let liveValue = KeyValueStoreClient.live
}

private enum AppLanguageClientKey: DependencyKey {
    static var liveValue: AppLanguageClient {
        @Dependency(\.keyValueStoreClient) var keyValueStoreClient
        return AppLanguageClient.live(keyValueStoreClient: keyValueStoreClient)
    }
}

extension DependencyValues {
    var dateClient: DateClient {
        get { self[DateClientKey.self] }
        set { self[DateClientKey.self] = newValue }
    }

    var uuidClient: UUIDClient {
        get { self[UUIDClientKey.self] }
        set { self[UUIDClientKey.self] = newValue }
    }

    var fileClient: FileClient {
        get { self[FileClientKey.self] }
        set { self[FileClientKey.self] = newValue }
    }

    var httpClient: HTTPClient {
        get { self[HTTPClientKey.self] }
        set { self[HTTPClientKey.self] = newValue }
    }

    var keyValueStoreClient: KeyValueStoreClient {
        get { self[KeyValueStoreClientKey.self] }
        set { self[KeyValueStoreClientKey.self] = newValue }
    }

    var appLanguageClient: AppLanguageClient {
        get { self[AppLanguageClientKey.self] }
        set { self[AppLanguageClientKey.self] = newValue }
    }
}
