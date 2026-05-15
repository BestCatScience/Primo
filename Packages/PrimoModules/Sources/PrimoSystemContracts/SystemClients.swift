import Foundation

public struct ProcessEnvironmentClient: Sendable {
    public let stringValue: @Sendable (String) -> String?

    public init(stringValue: @escaping @Sendable (String) -> String?) {
        self.stringValue = stringValue
    }
}

public struct MainQueueClient: Sendable {
    public let async: @Sendable (@escaping @MainActor () -> Void) -> Void

    public init(async: @escaping @Sendable (@escaping @MainActor () -> Void) -> Void) {
        self.async = async
    }
}

public struct DateClient: Sendable {
    public let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date) {
        self.now = now
    }
}

public struct UUIDClient: Sendable {
    public let generate: @Sendable () -> UUID

    public init(generate: @escaping @Sendable () -> UUID) {
        self.generate = generate
    }
}

public struct FileClient: Sendable {
    public let temporaryDirectory: @Sendable () -> URL
    public let urls: @Sendable (FileManager.SearchPathDirectory, FileManager.SearchPathDomainMask) -> [URL]
    public let fileExists: @Sendable (String) -> Bool
    public let createDirectory: @Sendable (URL, Bool) throws -> Void
    public let removeItem: @Sendable (URL) throws -> Void
    public let copyItem: @Sendable (URL, URL) throws -> Void
    public let moveItem: @Sendable (URL, URL) throws -> Void
    public let replaceItem: @Sendable (URL, URL, String?) throws -> Void
    public let contentsOfDirectory: @Sendable (URL, [URLResourceKey], FileManager.DirectoryEnumerationOptions) throws -> [URL]
    public let enumerateURLs: @Sendable (URL, [URLResourceKey], FileManager.DirectoryEnumerationOptions) -> [URL]
    public let readData: @Sendable (URL) throws -> Data
    public let writeData: @Sendable (Data, URL, Data.WritingOptions) throws -> Void

    public init(
        temporaryDirectory: @escaping @Sendable () -> URL,
        urls: @escaping @Sendable (FileManager.SearchPathDirectory, FileManager.SearchPathDomainMask) -> [URL],
        fileExists: @escaping @Sendable (String) -> Bool,
        createDirectory: @escaping @Sendable (URL, Bool) throws -> Void,
        removeItem: @escaping @Sendable (URL) throws -> Void,
        copyItem: @escaping @Sendable (URL, URL) throws -> Void,
        moveItem: @escaping @Sendable (URL, URL) throws -> Void,
        replaceItem: @escaping @Sendable (URL, URL, String?) throws -> Void,
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
        self.replaceItem = replaceItem
        self.contentsOfDirectory = contentsOfDirectory
        self.enumerateURLs = enumerateURLs
        self.readData = readData
        self.writeData = writeData
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct HTTPClient: Sendable {
    public let data: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    public init(data: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) {
        self.data = data
    }
}

public struct KeyValueStoreClient: Sendable {
    public let stringForKey: @Sendable (String) -> String?
    public let setString: @Sendable (String?, String) -> Void

    public init(
        stringForKey: @escaping @Sendable (String) -> String?,
        setString: @escaping @Sendable (String?, String) -> Void
    ) {
        self.stringForKey = stringForKey
        self.setString = setString
    }
}

public enum SecretStoreError: Error, Equatable, Sendable {
    case unhandledStatus(OSStatus)
    case invalidData
}

public struct SecretStoreClient: Sendable {
    public let readSecret: @Sendable (String) throws -> String?
    public let writeSecret: @Sendable (String?, String) throws -> Void

    public init(
        readSecret: @escaping @Sendable (String) throws -> String?,
        writeSecret: @escaping @Sendable (String?, String) throws -> Void
    ) {
        self.readSecret = readSecret
        self.writeSecret = writeSecret
    }
}

public struct SecurityScopedResourceClient: Sendable {
    public let startAccessing: @Sendable (URL) -> Bool
    public let stopAccessing: @Sendable (URL) -> Void

    public init(
        startAccessing: @escaping @Sendable (URL) -> Bool,
        stopAccessing: @escaping @Sendable (URL) -> Void
    ) {
        self.startAccessing = startAccessing
        self.stopAccessing = stopAccessing
    }
}
