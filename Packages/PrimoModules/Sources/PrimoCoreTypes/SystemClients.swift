import Foundation

public struct DateClient: Sendable {
    public var now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date) {
        self.now = now
    }

    public static let live = DateClient(now: { Date() })
}

public struct UUIDClient: Sendable {
    public var generate: @Sendable () -> UUID

    public init(generate: @escaping @Sendable () -> UUID) {
        self.generate = generate
    }

    public static let live = UUIDClient(generate: { UUID() })
}

public struct FileClient: Sendable {
    public var temporaryDirectory: @Sendable () -> URL
    public var urls: @Sendable (FileManager.SearchPathDirectory, FileManager.SearchPathDomainMask) -> [URL]
    public var fileExists: @Sendable (String) -> Bool
    public var createDirectory: @Sendable (URL, Bool) throws -> Void
    public var removeItem: @Sendable (URL) throws -> Void
    public var copyItem: @Sendable (URL, URL) throws -> Void
    public var moveItem: @Sendable (URL, URL) throws -> Void
    public var contentsOfDirectory: @Sendable (URL, [URLResourceKey], FileManager.DirectoryEnumerationOptions) throws -> [URL]
    public var enumerateURLs: @Sendable (URL, [URLResourceKey], FileManager.DirectoryEnumerationOptions) -> [URL]
    public var readData: @Sendable (URL) throws -> Data
    public var writeData: @Sendable (Data, URL, Data.WritingOptions) throws -> Void

    public init(
        temporaryDirectory: @escaping @Sendable () -> URL,
        urls: @escaping @Sendable (FileManager.SearchPathDirectory, FileManager.SearchPathDomainMask) -> [URL],
        fileExists: @escaping @Sendable (String) -> Bool,
        createDirectory: @escaping @Sendable (URL, Bool) throws -> Void,
        removeItem: @escaping @Sendable (URL) throws -> Void,
        copyItem: @escaping @Sendable (URL, URL) throws -> Void,
        moveItem: @escaping @Sendable (URL, URL) throws -> Void,
        contentsOfDirectory: @escaping @Sendable (URL, [URLResourceKey], FileManager.DirectoryEnumerationOptions) throws -> [URL],
        enumerateURLs: @escaping @Sendable (URL, [URLResourceKey], FileManager.DirectoryEnumerationOptions) -> [URL],
        readData: @escaping @Sendable (URL) throws -> Data,
        writeData: @escaping @Sendable (Data, URL, Data.WritingOptions) throws -> Void
    ) {
        self.temporaryDirectory = temporaryDirectory
        self.urls = urls
        self.fileExists = fileExists
        self.createDirectory = createDirectory
        self.removeItem = removeItem
        self.copyItem = copyItem
        self.moveItem = moveItem
        self.contentsOfDirectory = contentsOfDirectory
        self.enumerateURLs = enumerateURLs
        self.readData = readData
        self.writeData = writeData
    }

    public static let live: FileClient = {
        FileClient(
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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct HTTPClient: Sendable {
    public var data: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    public init(data: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) {
        self.data = data
    }

    public static let live = HTTPClient { request in
        try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data, let response else {
                    continuation.resume(
                        throwing: URLError(.badServerResponse)
                    )
                    return
                }

                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
    }
}

public struct KeyValueStoreClient: Sendable {
    public var stringForKey: @Sendable (String) -> String?
    public var setString: @Sendable (String?, String) -> Void

    public init(
        stringForKey: @escaping @Sendable (String) -> String?,
        setString: @escaping @Sendable (String?, String) -> Void
    ) {
        self.stringForKey = stringForKey
        self.setString = setString
    }

    public static let live = KeyValueStoreClient(
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

public struct SecurityScopedResourceClient: Sendable {
    public var startAccessing: @Sendable (URL) -> Bool
    public var stopAccessing: @Sendable (URL) -> Void

    public init(
        startAccessing: @escaping @Sendable (URL) -> Bool,
        stopAccessing: @escaping @Sendable (URL) -> Void
    ) {
        self.startAccessing = startAccessing
        self.stopAccessing = stopAccessing
    }

    public static let live = SecurityScopedResourceClient(
        startAccessing: { url in
            url.startAccessingSecurityScopedResource()
        },
        stopAccessing: { url in
            url.stopAccessingSecurityScopedResource()
        }
    )
}
