import ComposableArchitecture
import CryptoKit
import Foundation

struct DocumentWorkspaceClient: Sendable {
    var createTabBackingStoreURL: @Sendable (UUID) throws -> URL
    var createProjectURL: @Sendable () throws -> URL
    var writePNGToTemporaryDirectory: @Sendable (Data) throws -> URL
    var timelapseTemporaryDirectory: @Sendable () -> URL
    var loadSavedProjects: @Sendable () throws -> [SavedProjectSummary]
    var moveSavedProject: @Sendable (URL, String?) throws -> URL
    var loadAutosaveRecoveryItems: @Sendable () throws -> [AutosaveRecoveryItem]
    var discardAutosaveEntry: @Sendable (String) throws -> Void
    var discardAutosaveSnapshot: @Sendable (OpenDocumentTab) throws -> Void
    var persistAutosaveSnapshot: @Sendable (URL, OpenDocumentTab) throws -> Void
    var persistProjectSnapshot: @Sendable (URL, URL?) throws -> URL
    var loadSaveHistoryEntries: @Sendable (OpenDocumentTab) throws -> [SaveHistoryEntry]
    var persistSaveHistorySnapshot: @Sendable (URL, OpenDocumentTab, SaveHistoryTrigger) throws -> Void
    var removeWorkspaceItem: @Sendable (URL) throws -> Void

    static let live: DocumentWorkspaceClient = {
        let storage = DocumentWorkspaceStorage()
        return DocumentWorkspaceClient(
            createTabBackingStoreURL: { try storage.createTabBackingStoreURL(for: $0) },
            createProjectURL: { try storage.createProjectURL() },
            writePNGToTemporaryDirectory: { try storage.writePNGToTemporaryDirectory(data: $0) },
            timelapseTemporaryDirectory: { storage.timelapseTemporaryDirectory() },
            loadSavedProjects: { try storage.loadSavedProjects() },
            moveSavedProject: { try storage.moveSavedProject(at: $0, toRelativeFolderPath: $1) },
            loadAutosaveRecoveryItems: { try storage.loadAutosaveRecoveryItems() },
            discardAutosaveEntry: { try storage.discardAutosaveEntry(id: $0) },
            discardAutosaveSnapshot: { try storage.discardAutosaveSnapshot(for: $0) },
            persistAutosaveSnapshot: { try storage.persistAutosaveSnapshot(from: $0, tab: $1) },
            persistProjectSnapshot: { try storage.persistProjectSnapshot(from: $0, to: $1) },
            loadSaveHistoryEntries: { try storage.loadSaveHistoryEntries(for: $0) },
            persistSaveHistorySnapshot: { try storage.persistSaveHistorySnapshot(from: $0, tab: $1, trigger: $2) },
            removeWorkspaceItem: { try storage.removeWorkspaceItem(at: $0) }
        )
    }()
}

private enum DocumentWorkspaceClientKey: DependencyKey {
    static let liveValue = DocumentWorkspaceClient.live
}

extension DependencyValues {
    var documentWorkspaceClient: DocumentWorkspaceClient {
        get { self[DocumentWorkspaceClientKey.self] }
        set { self[DocumentWorkspaceClientKey.self] = newValue }
    }
}

private final class DocumentWorkspaceStorage: @unchecked Sendable {
    private static let appProjectsDirectoryName = "primo-projects"
    private static let tabProjectsDirectoryName = "primo-tabs"
    private static let autosavesDirectoryName = ".primo-autosaves"
    private static let saveHistoryDirectoryName = ".primo-save-history"
    private static let exportDirectoryName = "primo-export"
    private static let timelapseDirectoryName = "timelapse"
    private static let projectDirectoryName = "project.atelier"
    private static let metadataFilename = "metadata.json"
    private static let manifestFilename = "manifest.json"
    private static let saveHistoryLimit = 20

    private let fileManager: FileManager
    private let now: @Sendable () -> Date
    private let makeUUID: @Sendable () -> UUID

    init(
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = Date.init,
        makeUUID: @escaping @Sendable () -> UUID = UUID.init
    ) {
        self.fileManager = fileManager
        self.now = now
        self.makeUUID = makeUUID
    }

    func createTabBackingStoreURL(for tabID: UUID) throws -> URL {
        try tabProjectsDirectory().appendingPathComponent(tabID.uuidString, isDirectory: true)
    }

    func createProjectURL() throws -> URL {
        try appProjectsDirectory().appendingPathComponent(projectFilename(for: now()), isDirectory: true)
    }

    func writePNGToTemporaryDirectory(data: Data) throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent(Self.exportDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(exportFilename(for: now()), isDirectory: false)
        try data.write(to: url, options: .atomic)
        return url
    }

    func timelapseTemporaryDirectory() -> URL {
        fileManager.temporaryDirectory
            .appendingPathComponent(Self.exportDirectoryName, isDirectory: true)
            .appendingPathComponent(Self.timelapseDirectoryName, isDirectory: true)
    }

    func loadSavedProjects() throws -> [SavedProjectSummary] {
        let rootDirectory = try appProjectsDirectory()
        let projectURLs = try discoverProjectDirectories(in: rootDirectory)

        return projectURLs.compactMap { projectURL in
            guard let loaded = try? PaintDocumentSession.loadProject(from: projectURL) else {
                return nil
            }
            let presentation = loaded.presentation()
            let previewData = loaded.compositePNGData(paperStyle: loaded.currentPaperStyle)
            let values = try? projectURL.resourceValues(forKeys: [.contentModificationDateKey])
            return SavedProjectSummary(
                url: projectURL,
                name: projectURL.deletingPathExtension().lastPathComponent,
                relativeFolderPath: relativeFolderPath(for: projectURL, rootDirectory: rootDirectory),
                modifiedAt: values?.contentModificationDate ?? .distantPast,
                canvasSize: presentation.canvasSize,
                layerCount: presentation.layerRows.count,
                previewImageData: previewData
            )
        }
        .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func moveSavedProject(at url: URL, toRelativeFolderPath relativeFolderPath: String?) throws -> URL {
        try requireProjectDirectory(at: url, label: "saved project")
        let rootDirectory = try appProjectsDirectory()
        let relativePath = try RelativeProjectFolderPath(validating: relativeFolderPath)
        let destinationDirectory = relativePath.appending(to: rootDirectory)
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let destinationURL = destinationDirectory.appendingPathComponent(url.lastPathComponent, isDirectory: true)
        guard destinationURL.standardizedFileURL != url.standardizedFileURL else {
            return url
        }
        if fileManager.fileExists(atPath: destinationURL.path) {
            throw DocumentWorkspaceError.destinationAlreadyExists(destinationURL)
        }
        try fileManager.moveItem(at: url, to: destinationURL)
        try relocateWorkspaceArtifacts(from: url, to: destinationURL)
        return destinationURL
    }

    func loadAutosaveRecoveryItems() throws -> [AutosaveRecoveryItem] {
        let directory = try autosavesDirectory()
        let entryURLs = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return try entryURLs.compactMap { entryURL -> AutosaveRecoveryItem? in
            guard try isDirectory(entryURL) else { return nil }

            let metadataURL = metadataURL(in: entryURL)
            guard let data = try? Data(contentsOf: metadataURL) else { return nil }
            let metadata = try JSONDecoder().decode(StoredAutosaveMetadata.self, from: data)
            let identifier = try StorageIdentifier(validating: metadata.id)
            let projectURL = projectURL(in: entryURL)
            guard fileManager.fileExists(atPath: projectURL.path) else { return nil }

            let previewImageData: Data? = {
                guard let session = try? PaintDocumentSession.loadProject(from: projectURL) else { return nil }
                return session.compositePNGData(paperStyle: session.currentPaperStyle)
            }()

            return AutosaveRecoveryItem(
                id: identifier.rawValue,
                title: metadata.title,
                sourceProjectURL: metadata.sourceProjectPath.map { URL(fileURLWithPath: $0) },
                autosaveProjectURL: projectURL,
                updatedAt: metadata.updatedAt,
                previewImageData: previewImageData
            )
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    func discardAutosaveEntry(id: String) throws {
        let identifier = try StorageIdentifier(validating: id)
        let directory = try autosavesDirectory().appendingPathComponent(identifier.rawValue, isDirectory: true)
        try removeItemIfExists(at: directory)
    }

    func discardAutosaveSnapshot(for tab: OpenDocumentTab) throws {
        try discardAutosaveEntry(id: autosaveIdentifier(for: tab).rawValue)
    }

    func persistAutosaveSnapshot(from backingStoreURL: URL, tab: OpenDocumentTab) throws {
        let identifier = autosaveIdentifier(for: tab)
        let entryDirectory = try autosaveEntryDirectory(for: identifier)
        let destinationProjectURL = projectURL(in: entryDirectory)
        try replaceProjectDirectory(from: backingStoreURL, to: destinationProjectURL)

        let metadata = StoredAutosaveMetadata(
            id: identifier.rawValue,
            title: tab.title,
            sourceProjectPath: tab.sourceProjectURL?.standardizedFileURL.path,
            updatedAt: now()
        )
        try writeMetadata(metadata, to: metadataURL(in: entryDirectory))
    }

    func persistProjectSnapshot(from sourceProjectURL: URL, to preferredDestinationURL: URL?) throws -> URL {
        let destinationURL = try preferredDestinationURL ?? createProjectURL()
        try replaceProjectDirectory(from: sourceProjectURL, to: destinationURL)
        return destinationURL
    }

    func loadSaveHistoryEntries(for tab: OpenDocumentTab) throws -> [SaveHistoryEntry] {
        let directory = try saveHistoryEntriesDirectory(for: historyIdentifier(for: tab))
        let entryURLs = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return try entryURLs.compactMap { entryURL -> SaveHistoryEntry? in
            guard try isDirectory(entryURL) else { return nil }

            let metadataURL = metadataURL(in: entryURL)
            guard let data = try? Data(contentsOf: metadataURL) else { return nil }
            let metadata = try JSONDecoder().decode(StoredSaveHistoryMetadata.self, from: data)
            let identifier = try StorageIdentifier(validating: metadata.id)
            let projectURL = projectURL(in: entryURL)
            guard fileManager.fileExists(atPath: projectURL.path) else { return nil }

            let previewImageData: Data? = {
                guard let session = try? PaintDocumentSession.loadProject(from: projectURL) else { return nil }
                return session.compositePNGData(paperStyle: session.currentPaperStyle)
            }()

            return SaveHistoryEntry(
                id: identifier.rawValue,
                title: metadata.title,
                projectURL: projectURL,
                createdAt: metadata.createdAt,
                trigger: metadata.trigger,
                previewImageData: previewImageData
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    func persistSaveHistorySnapshot(from backingStoreURL: URL, tab: OpenDocumentTab, trigger: SaveHistoryTrigger) throws {
        let historyID = historyIdentifier(for: tab)
        let entryID = StorageIdentifier(unchecked: makeUUID().uuidString.lowercased())
        let entryDirectory = try saveHistoryEntryDirectory(for: historyID, entryID: entryID)
        let destinationProjectURL = projectURL(in: entryDirectory)
        try replaceProjectDirectory(from: backingStoreURL, to: destinationProjectURL)

        let title = (tab.sourceProjectURL ?? tab.backingStoreURL).deletingPathExtension().lastPathComponent
        let metadata = StoredSaveHistoryMetadata(
            id: entryID.rawValue,
            title: title,
            createdAt: now(),
            trigger: trigger
        )
        try writeMetadata(metadata, to: metadataURL(in: entryDirectory))
        try trimSaveHistoryEntries(for: historyID, limit: Self.saveHistoryLimit)
    }

    func removeWorkspaceItem(at url: URL) throws {
        try removeItemIfExists(at: url)
    }

    private func tabProjectsDirectory() throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent(Self.tabProjectsDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func autosavesDirectory() throws -> URL {
        let directory = try appProjectsDirectory()
            .appendingPathComponent(Self.autosavesDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func autosaveEntryDirectory(for identifier: StorageIdentifier) throws -> URL {
        let directory = try autosavesDirectory()
            .appendingPathComponent(identifier.rawValue, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func saveHistoryDirectory() throws -> URL {
        let directory = try appProjectsDirectory()
            .appendingPathComponent(Self.saveHistoryDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func saveHistoryEntriesDirectory(for identifier: StorageIdentifier) throws -> URL {
        let directory = try saveHistoryDirectory()
            .appendingPathComponent(identifier.rawValue, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func saveHistoryEntryDirectory(for identifier: StorageIdentifier, entryID: StorageIdentifier) throws -> URL {
        let directory = try saveHistoryEntriesDirectory(for: identifier)
            .appendingPathComponent(entryID.rawValue, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func appProjectsDirectory() throws -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documentsDirectory
            .appendingPathComponent(Self.appProjectsDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func autosaveIdentifier(for tab: OpenDocumentTab) -> StorageIdentifier {
        storageIdentifier(for: tab)
    }

    private func historyIdentifier(for tab: OpenDocumentTab) -> StorageIdentifier {
        storageIdentifier(for: tab)
    }

    private func storageIdentifier(for sourceProjectURL: URL) -> StorageIdentifier {
        let digest = SHA256.hash(data: Data(sourceProjectURL.standardizedFileURL.path.utf8))
        let stableIdentifier = digest.map { String(format: "%02x", $0) }.joined()
        return StorageIdentifier(unchecked: "saved-\(stableIdentifier)")
    }

    private func storageIdentifier(for tab: OpenDocumentTab) -> StorageIdentifier {
        if let sourceProjectURL = tab.sourceProjectURL?.standardizedFileURL {
            return storageIdentifier(for: sourceProjectURL)
        }
        return StorageIdentifier(unchecked: "untitled-\(tab.id.uuidString.lowercased())")
    }

    private func discoverProjectDirectories(in rootDirectory: URL) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var projectURLs: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            guard try isDirectory(url) else { continue }
            if try containsProjectManifest(at: url) {
                projectURLs.append(url)
                enumerator.skipDescendants()
            }
        }
        return projectURLs
    }

    private func relativeFolderPath(for projectURL: URL, rootDirectory: URL) -> String? {
        let parentPath = projectURL.deletingLastPathComponent().standardizedFileURL.path
        let rootPath = rootDirectory.standardizedFileURL.path
        guard parentPath != rootPath else { return nil }
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard parentPath.hasPrefix(prefix) else { return nil }
        let relativePath = String(parentPath.dropFirst(prefix.count))
        return relativePath.isEmpty ? nil : relativePath
    }

    private func trimSaveHistoryEntries(for identifier: StorageIdentifier, limit: Int) throws {
        guard limit > 0 else { return }
        let directory = try saveHistoryEntriesDirectory(for: identifier)
        let entryURLs = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let sortedEntryURLs = entryURLs.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }
        guard sortedEntryURLs.count > limit else { return }
        for entryURL in sortedEntryURLs.dropFirst(limit) {
            try removeItemIfExists(at: entryURL)
        }
    }

    private func relocateWorkspaceArtifacts(from sourceProjectURL: URL, to destinationProjectURL: URL) throws {
        let sourceIdentifier = storageIdentifier(for: sourceProjectURL)
        let destinationIdentifier = storageIdentifier(for: destinationProjectURL)
        guard sourceIdentifier != destinationIdentifier else { return }

        let autosaveSource = try autosavesDirectory().appendingPathComponent(sourceIdentifier.rawValue, isDirectory: true)
        let autosaveDestination = try autosavesDirectory().appendingPathComponent(destinationIdentifier.rawValue, isDirectory: true)
        try moveDirectoryIfPresent(from: autosaveSource, to: autosaveDestination)

        let historySource = try saveHistoryDirectory().appendingPathComponent(sourceIdentifier.rawValue, isDirectory: true)
        let historyDestination = try saveHistoryDirectory().appendingPathComponent(destinationIdentifier.rawValue, isDirectory: true)
        try moveDirectoryIfPresent(from: historySource, to: historyDestination)
    }

    private func projectURL(in entryDirectory: URL) -> URL {
        entryDirectory.appendingPathComponent(Self.projectDirectoryName, isDirectory: true)
    }

    private func metadataURL(in entryDirectory: URL) -> URL {
        entryDirectory.appendingPathComponent(Self.metadataFilename, isDirectory: false)
    }

    private func writeMetadata<T: Encodable>(_ metadata: T, to url: URL) throws {
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: url, options: .atomic)
    }

    private func replaceProjectDirectory(from sourceURL: URL, to destinationURL: URL) throws {
        try requireProjectDirectory(at: sourceURL, label: "project snapshot")
        guard sourceURL.standardizedFileURL != destinationURL.standardizedFileURL else {
            return
        }
        try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try removeItemIfExists(at: destinationURL)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private func requireProjectDirectory(at url: URL, label: String) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw DocumentWorkspaceError.missingProjectDirectory(label, url)
        }
        guard try isDirectory(url), try containsProjectManifest(at: url) else {
            throw DocumentWorkspaceError.invalidProjectDirectory(label, url)
        }
    }

    private func containsProjectManifest(at url: URL) throws -> Bool {
        let manifestURL = url.appendingPathComponent(Self.manifestFilename, isDirectory: false)
        return fileManager.fileExists(atPath: manifestURL.path)
    }

    private func isDirectory(_ url: URL) throws -> Bool {
        try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
    }

    private func removeItemIfExists(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func moveDirectoryIfPresent(from sourceURL: URL, to destinationURL: URL) throws {
        guard fileManager.fileExists(atPath: sourceURL.path) else { return }
        guard !fileManager.fileExists(atPath: destinationURL.path) else { return }
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
    }

    private func exportFilename(for date: Date) -> String {
        "primo-\(timestampString(for: date)).png"
    }

    private func projectFilename(for date: Date) -> String {
        "primo-\(timestampString(for: date)).atelier"
    }

    private func timestampString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}

private struct StoredAutosaveMetadata: Codable {
    let id: String
    let title: String
    let sourceProjectPath: String?
    let updatedAt: Date
}

private struct StoredSaveHistoryMetadata: Codable {
    let id: String
    let title: String
    let createdAt: Date
    let trigger: SaveHistoryTrigger
}

private struct StorageIdentifier: Hashable, Sendable {
    let rawValue: String

    init(validating rawValue: String) throws {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else {
            throw DocumentWorkspaceError.invalidIdentifier(rawValue)
        }
        guard normalized.unicodeScalars.allSatisfy(StorageIdentifier.isAllowedScalar(_:)) else {
            throw DocumentWorkspaceError.invalidIdentifier(rawValue)
        }
        self.rawValue = normalized
    }

    init(unchecked rawValue: String) {
        self.rawValue = rawValue
    }

    private static func isAllowedScalar(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 45, 48...57, 97...122:
            return true
        default:
            return false
        }
    }
}

private struct RelativeProjectFolderPath: Sendable {
    let components: [String]

    init(validating rawValue: String?) throws {
        let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            self.components = []
            return
        }
        guard !trimmed.hasPrefix("/") else {
            throw DocumentWorkspaceError.invalidRelativeFolderPath(trimmed)
        }

        let components = trimmed
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard !components.isEmpty else {
            throw DocumentWorkspaceError.invalidRelativeFolderPath(trimmed)
        }
        guard components.allSatisfy({ $0 != "." && $0 != ".." }) else {
            throw DocumentWorkspaceError.invalidRelativeFolderPath(trimmed)
        }
        self.components = components
    }

    func appending(to rootDirectory: URL) -> URL {
        components.reduce(rootDirectory) { partialResult, component in
            partialResult.appendingPathComponent(component, isDirectory: true)
        }
    }
}

private enum DocumentWorkspaceError: LocalizedError {
    case invalidIdentifier(String)
    case invalidRelativeFolderPath(String)
    case missingProjectDirectory(String, URL)
    case invalidProjectDirectory(String, URL)
    case destinationAlreadyExists(URL)

    var errorDescription: String? {
        switch self {
        case let .invalidIdentifier(value):
            return "Invalid workspace identifier: \(value)"
        case let .invalidRelativeFolderPath(value):
            return "Invalid destination folder path: \(value)"
        case let .missingProjectDirectory(label, url):
            return "Missing \(label) at \(url.lastPathComponent)"
        case let .invalidProjectDirectory(label, url):
            return "Invalid \(label) at \(url.lastPathComponent)"
        case let .destinationAlreadyExists(url):
            return "A project already exists at \(url.lastPathComponent)"
        }
    }
}
