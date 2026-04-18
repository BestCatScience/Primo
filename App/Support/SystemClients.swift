import Foundation

struct DateClient: Sendable {
    var now: @Sendable () -> Date

    static let live = DateClient(now: { Date() })
}

struct UUIDClient: Sendable {
    var generate: @Sendable () -> UUID

    static let live = UUIDClient(generate: { UUID() })
}

struct FileClient: Sendable {
    var temporaryDirectory: @Sendable () -> URL
    var urls: @Sendable (FileManager.SearchPathDirectory, FileManager.SearchPathDomainMask) -> [URL]
    var fileExists: @Sendable (String) -> Bool
    var createDirectory: @Sendable (URL, Bool) throws -> Void
    var removeItem: @Sendable (URL) throws -> Void
    var copyItem: @Sendable (URL, URL) throws -> Void
    var moveItem: @Sendable (URL, URL) throws -> Void
    var contentsOfDirectory: @Sendable (URL, [URLResourceKey], FileManager.DirectoryEnumerationOptions) throws -> [URL]
    var enumerateURLs: @Sendable (URL, [URLResourceKey], FileManager.DirectoryEnumerationOptions) -> [URL]
    var readData: @Sendable (URL) throws -> Data
    var writeData: @Sendable (Data, URL, Data.WritingOptions) throws -> Void

    static let live: FileClient = {
        return FileClient(
            temporaryDirectory: { FileManager.default.temporaryDirectory },
            urls: { directory, domain in FileManager.default.urls(for: directory, in: domain) },
            fileExists: { path in FileManager.default.fileExists(atPath: path) },
            createDirectory: { url, createIntermediates in
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: createIntermediates)
            },
            removeItem: { url in
                try FileManager.default.removeItem(at: url)
            },
            copyItem: { sourceURL, destinationURL in
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            },
            moveItem: { sourceURL, destinationURL in
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            },
            contentsOfDirectory: { url, keys, options in
                try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: keys,
                    options: options
                )
            },
            enumerateURLs: { url, keys, options in
                guard let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: keys,
                    options: options
                ) else {
                    return []
                }
                return enumerator.compactMap { $0 as? URL }
            },
            readData: { url in
                try Data(contentsOf: url)
            },
            writeData: { data, url, options in
                try data.write(to: url, options: options)
            }
        )
    }()
}

struct HTTPClient: Sendable {
    var data: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static let live = HTTPClient { request in
        try await URLSession.shared.data(for: request)
    }
}

struct KeyValueStoreClient: Sendable {
    var stringForKey: @Sendable (String) -> String?
    var setString: @Sendable (String?, String) -> Void

    static let live = KeyValueStoreClient(
        stringForKey: { key in
            UserDefaults.standard.string(forKey: key)
        },
        setString: { value, key in
            if let value {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    )
}

struct SecurityScopedResourceClient: Sendable {
    var startAccessing: @Sendable (URL) -> Bool
    var stopAccessing: @Sendable (URL) -> Void

    static let live = SecurityScopedResourceClient(
        startAccessing: { url in
            url.startAccessingSecurityScopedResource()
        },
        stopAccessing: { url in
            url.stopAccessingSecurityScopedResource()
        }
    )
}

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
