import Foundation

struct DateClient: Sendable {
    var now: @Sendable () -> Date

    static let live = DateClient(now: Date.init)
}

struct UUIDClient: Sendable {
    var generate: @Sendable () -> UUID

    static let live = UUIDClient(generate: UUID.init)
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
        let fileManager = FileManager.default
        return FileClient(
            temporaryDirectory: { fileManager.temporaryDirectory },
            urls: { directory, domain in fileManager.urls(for: directory, in: domain) },
            fileExists: { path in fileManager.fileExists(atPath: path) },
            createDirectory: { url, createIntermediates in
                try fileManager.createDirectory(at: url, withIntermediateDirectories: createIntermediates)
            },
            removeItem: { url in
                try fileManager.removeItem(at: url)
            },
            copyItem: { sourceURL, destinationURL in
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            },
            moveItem: { sourceURL, destinationURL in
                try fileManager.moveItem(at: sourceURL, to: destinationURL)
            },
            contentsOfDirectory: { url, keys, options in
                try fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: keys,
                    options: options
                )
            },
            enumerateURLs: { url, keys, options in
                guard let enumerator = fileManager.enumerator(
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
