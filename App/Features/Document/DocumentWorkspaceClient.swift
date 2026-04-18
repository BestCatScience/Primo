import ComposableArchitecture
import CryptoKit
import Foundation

enum WorkspaceCatalogFailure: LocalizedError, Equatable, OperationFailure {
    case projectLoadFailed(String)
    case metadataReadFailed(String)
    case metadataDecodeFailed(String)
    case resourceLookupFailed(String)
    case invalidRelativeFolderPath(String)
    case invalidWorkspaceEntry(String)

    var errorDescription: String? {
        switch self {
        case let .projectLoadFailed(message),
             let .metadataReadFailed(message),
             let .metadataDecodeFailed(message),
             let .resourceLookupFailed(message),
             let .invalidRelativeFolderPath(message),
             let .invalidWorkspaceEntry(message):
            return message
        }
    }
}

struct DocumentWorkspaceClient: Sendable {
    var createTabBackingStoreURL: @Sendable (UUID) throws -> DocumentProjectPath
    var createProjectURL: @Sendable () throws -> DocumentProjectPath
    var writePNGToTemporaryDirectory: @Sendable (Data) throws -> URL
    var timelapseTemporaryDirectory: @Sendable () -> URL
    var loadSavedProjects: @Sendable () throws -> [SavedProjectSummary]
    var moveSavedProject: @Sendable (DocumentProjectPath, RelativeProjectFolderPath?) throws -> DocumentProjectPath
    var loadAutosaveRecoveryItems: @Sendable () throws -> [AutosaveRecoveryItem]
    var discardAutosaveEntry: @Sendable (WorkspaceItemID) throws -> Void
    var discardAutosaveSnapshot: @Sendable (OpenDocumentTab) throws -> Void
    var persistAutosaveSnapshot: @Sendable (DocumentProjectPath, OpenDocumentTab) throws -> Void
    var persistProjectSnapshot: @Sendable (DocumentProjectPath, DocumentProjectPath?) throws -> DocumentProjectPath
    var loadSaveHistoryEntries: @Sendable (OpenDocumentTab) throws -> [SaveHistoryEntry]
    var persistSaveHistorySnapshot: @Sendable (DocumentProjectPath, OpenDocumentTab, SaveHistoryTrigger) throws -> Void
    var removeWorkspaceItem: @Sendable (DocumentProjectPath) throws -> Void

    static func live(
        fileClient: FileClient,
        dateClient: DateClient,
        uuidClient: UUIDClient
    ) -> DocumentWorkspaceClient {
        let storage = DocumentWorkspaceStorage(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
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
    }
}

private enum DocumentWorkspaceClientKey: DependencyKey {
    static var liveValue: DocumentWorkspaceClient {
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.dateClient) var dateClient
        @Dependency(\.uuidClient) var uuidClient
        return .live(fileClient: fileClient, dateClient: dateClient, uuidClient: uuidClient)
    }
}

extension DependencyValues {
    var documentWorkspaceClient: DocumentWorkspaceClient {
        get { self[DocumentWorkspaceClientKey.self] }
        set { self[DocumentWorkspaceClientKey.self] = newValue }
    }
}

private struct DocumentWorkspaceStorage: Sendable {
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

    private let fileClient: FileClient
    private let dateClient: DateClient
    private let uuidClient: UUIDClient

    init(
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) {
        self.fileClient = fileClient
        self.dateClient = dateClient
        self.uuidClient = uuidClient
    }

    func createTabBackingStoreURL(for tabID: UUID) throws -> DocumentProjectPath {
        DocumentProjectPath(try tabProjectsDirectory().appendingPathComponent(tabID.uuidString, isDirectory: true))
    }

    func createProjectURL() throws -> DocumentProjectPath {
        DocumentProjectPath(
            try appProjectsDirectory().appendingPathComponent(projectFilename(for: dateClient.now()), isDirectory: true)
        )
    }

    func writePNGToTemporaryDirectory(data: Data) throws -> URL {
        let directory = fileClient.temporaryDirectory()
            .appendingPathComponent(Self.exportDirectoryName, isDirectory: true)
        try fileClient.createDirectory(directory, true)
        let url = directory.appendingPathComponent(exportFilename(for: dateClient.now()), isDirectory: false)
        try fileClient.writeData(data, url, .atomic)
        return url
    }

    func timelapseTemporaryDirectory() -> URL {
        fileClient.temporaryDirectory()
            .appendingPathComponent(Self.exportDirectoryName, isDirectory: true)
            .appendingPathComponent(Self.timelapseDirectoryName, isDirectory: true)
    }

    func loadSavedProjects() throws -> [SavedProjectSummary] {
        let rootDirectory = try appProjectsDirectory()
        let projectURLs = try discoverProjectDirectories(in: rootDirectory)

        var summaries: [SavedProjectSummary] = []
        for projectURL in projectURLs {
            let loaded = try loadProjectSession(
                from: projectURL,
                label: "saved project"
            )
            let presentation = loaded.presentation()
            let previewData = loaded.compositePNGData(paperStyle: loaded.currentPaperStyle)
            summaries.append(
                SavedProjectSummary(
                    url: DocumentProjectPath(projectURL),
                    name: DocumentProjectPath(projectURL).displayName,
                    relativeFolderPath: try relativeFolderPath(for: projectURL, rootDirectory: rootDirectory),
                    modifiedAt: try contentModificationDate(for: projectURL),
                    canvasSize: presentation.canvasSize,
                    layerCount: presentation.layerRows.count,
                    previewImageData: previewData
                )
            )
        }
        return summaries.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func moveSavedProject(at url: DocumentProjectPath, toRelativeFolderPath relativeFolderPath: RelativeProjectFolderPath?) throws -> DocumentProjectPath {
        try requireProjectDirectory(at: url.fileURL, label: "saved project")
        let rootDirectory = try appProjectsDirectory()
        let relativePath = relativeFolderPath ?? RelativeProjectFolderPath(components: [])
        let destinationDirectory = relativePath.appending(to: rootDirectory)
        try fileClient.createDirectory(destinationDirectory, true)

        let destinationURL = destinationDirectory.appendingPathComponent(url.fileURL.lastPathComponent, isDirectory: true)
        guard destinationURL.standardizedFileURL != url.fileURL.standardizedFileURL else {
            return url
        }
        if fileClient.fileExists(destinationURL.path) {
            throw DocumentWorkspaceError.destinationAlreadyExists(destinationURL)
        }
        try fileClient.moveItem(url.fileURL, destinationURL)
        try relocateWorkspaceArtifacts(from: url.fileURL, to: destinationURL)
        return DocumentProjectPath(destinationURL)
    }

    func loadAutosaveRecoveryItems() throws -> [AutosaveRecoveryItem] {
        let directory = try autosavesDirectory()
        let entryURLs = try fileClient.contentsOfDirectory(
            directory,
            [.isDirectoryKey],
            [.skipsHiddenFiles]
        )

        return try entryURLs.compactMap { entryURL -> AutosaveRecoveryItem? in
            guard try isDirectory(entryURL) else { return nil }

            let metadataURL = metadataURL(in: entryURL)
            let data = try readMetadataData(
                at: metadataURL,
                label: "autosave metadata"
            )
            let metadata: StoredAutosaveMetadata = try decodeMetadata(
                StoredAutosaveMetadata.self,
                from: data,
                label: "autosave metadata"
            )
            let identifier = try workspaceItemID(
                validating: metadata.id,
                label: "autosave metadata"
            )
            let projectURL = projectURL(in: entryURL)
            guard fileClient.fileExists(projectURL.path) else {
                throw WorkspaceCatalogFailure.invalidWorkspaceEntry(
                    "Missing autosave project at \(projectURL.lastPathComponent)"
                )
            }

            let session = try loadProjectSession(
                from: projectURL,
                label: "autosave preview"
            )
            let previewImageData = session.compositePNGData(paperStyle: session.currentPaperStyle)

            return AutosaveRecoveryItem(
                id: identifier,
                title: metadata.title,
                sourceProjectURL: metadata.sourceProjectPath.map { DocumentProjectPath(URL(fileURLWithPath: $0)) },
                autosaveProjectURL: DocumentProjectPath(projectURL),
                updatedAt: metadata.updatedAt,
                previewImageData: previewImageData
            )
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    func discardAutosaveEntry(id: WorkspaceItemID) throws {
        let identifier = id
        let directory = try autosavesDirectory().appendingPathComponent(identifier.rawValue, isDirectory: true)
        try removeItemIfExists(at: directory)
    }

    func discardAutosaveSnapshot(for tab: OpenDocumentTab) throws {
        try discardAutosaveEntry(id: autosaveIdentifier(for: tab))
    }

    func persistAutosaveSnapshot(from backingStoreURL: DocumentProjectPath, tab: OpenDocumentTab) throws {
        let identifier = autosaveIdentifier(for: tab)
        let entryDirectory = try autosaveEntryDirectory(for: identifier)
        let destinationProjectURL = projectURL(in: entryDirectory)
        try replaceProjectDirectory(from: backingStoreURL.fileURL, to: destinationProjectURL)

        let metadata = StoredAutosaveMetadata(
            id: identifier.rawValue,
            title: tab.title,
            sourceProjectPath: tab.sourceProjectURL?.path,
            updatedAt: dateClient.now()
        )
        try writeMetadata(metadata, to: metadataURL(in: entryDirectory))
    }

    func persistProjectSnapshot(
        from sourceProjectURL: DocumentProjectPath,
        to preferredDestinationURL: DocumentProjectPath?
    ) throws -> DocumentProjectPath {
        let destinationURL = try preferredDestinationURL ?? createProjectURL()
        try replaceProjectDirectory(from: sourceProjectURL.fileURL, to: destinationURL.fileURL)
        return destinationURL
    }

    func loadSaveHistoryEntries(for tab: OpenDocumentTab) throws -> [SaveHistoryEntry] {
        let directory = try saveHistoryEntriesDirectory(for: historyIdentifier(for: tab))
        let entryURLs = try fileClient.contentsOfDirectory(
            directory,
            [.isDirectoryKey],
            [.skipsHiddenFiles]
        )

        return try entryURLs.compactMap { entryURL -> SaveHistoryEntry? in
            guard try isDirectory(entryURL) else { return nil }

            let metadataURL = metadataURL(in: entryURL)
            let data = try readMetadataData(
                at: metadataURL,
                label: "save history metadata"
            )
            let metadata: StoredSaveHistoryMetadata = try decodeMetadata(
                StoredSaveHistoryMetadata.self,
                from: data,
                label: "save history metadata"
            )
            let identifier = try workspaceItemID(
                validating: metadata.id,
                label: "save history metadata"
            )
            let projectURL = projectURL(in: entryURL)
            guard fileClient.fileExists(projectURL.path) else {
                throw WorkspaceCatalogFailure.invalidWorkspaceEntry(
                    "Missing save history project at \(projectURL.lastPathComponent)"
                )
            }

            let session = try loadProjectSession(
                from: projectURL,
                label: "save history preview"
            )
            let previewImageData = session.compositePNGData(paperStyle: session.currentPaperStyle)

            return SaveHistoryEntry(
                id: identifier,
                title: metadata.title,
                projectURL: DocumentProjectPath(projectURL),
                createdAt: metadata.createdAt,
                trigger: metadata.trigger,
                previewImageData: previewImageData
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    func persistSaveHistorySnapshot(
        from backingStoreURL: DocumentProjectPath,
        tab: OpenDocumentTab,
        trigger: SaveHistoryTrigger
    ) throws {
        let historyID = historyIdentifier(for: tab)
        let entryID = WorkspaceItemID(unchecked: uuidClient.generate().uuidString.lowercased())
        let entryDirectory = try saveHistoryEntryDirectory(for: historyID, entryID: entryID)
        let destinationProjectURL = projectURL(in: entryDirectory)
        try replaceProjectDirectory(from: backingStoreURL.fileURL, to: destinationProjectURL)

        let title = (tab.sourceProjectURL ?? tab.backingStoreURL).displayName
        let metadata = StoredSaveHistoryMetadata(
            id: entryID.rawValue,
            title: title,
            createdAt: dateClient.now(),
            trigger: trigger
        )
        try writeMetadata(metadata, to: metadataURL(in: entryDirectory))
        try trimSaveHistoryEntries(for: historyID, limit: Self.saveHistoryLimit)
    }

    func removeWorkspaceItem(at url: DocumentProjectPath) throws {
        try removeItemIfExists(at: url.fileURL)
    }

    private func tabProjectsDirectory() throws -> URL {
        let directory = fileClient.temporaryDirectory()
            .appendingPathComponent(Self.tabProjectsDirectoryName, isDirectory: true)
        try fileClient.createDirectory(directory, true)
        return directory
    }

    private func autosavesDirectory() throws -> URL {
        let directory = try appProjectsDirectory()
            .appendingPathComponent(Self.autosavesDirectoryName, isDirectory: true)
        try fileClient.createDirectory(directory, true)
        return directory
    }

    private func autosaveEntryDirectory(for identifier: WorkspaceItemID) throws -> URL {
        let directory = try autosavesDirectory()
            .appendingPathComponent(identifier.rawValue, isDirectory: true)
        try fileClient.createDirectory(directory, true)
        return directory
    }

    private func saveHistoryDirectory() throws -> URL {
        let directory = try appProjectsDirectory()
            .appendingPathComponent(Self.saveHistoryDirectoryName, isDirectory: true)
        try fileClient.createDirectory(directory, true)
        return directory
    }

    private func saveHistoryEntriesDirectory(for identifier: WorkspaceItemID) throws -> URL {
        let directory = try saveHistoryDirectory()
            .appendingPathComponent(identifier.rawValue, isDirectory: true)
        try fileClient.createDirectory(directory, true)
        return directory
    }

    private func saveHistoryEntryDirectory(for identifier: WorkspaceItemID, entryID: WorkspaceItemID) throws -> URL {
        let directory = try saveHistoryEntriesDirectory(for: identifier)
            .appendingPathComponent(entryID.rawValue, isDirectory: true)
        try fileClient.createDirectory(directory, true)
        return directory
    }

    private func appProjectsDirectory() throws -> URL {
        let documentsDirectory = fileClient.urls(.documentDirectory, .userDomainMask)[0]
        let directory = documentsDirectory
            .appendingPathComponent(Self.appProjectsDirectoryName, isDirectory: true)
        try fileClient.createDirectory(directory, true)
        return directory
    }

    private func autosaveIdentifier(for tab: OpenDocumentTab) -> WorkspaceItemID {
        storageIdentifier(for: tab)
    }

    private func historyIdentifier(for tab: OpenDocumentTab) -> WorkspaceItemID {
        storageIdentifier(for: tab)
    }

    private func storageIdentifier(for sourceProjectURL: URL) -> WorkspaceItemID {
        let digest = SHA256.hash(data: Data(sourceProjectURL.standardizedFileURL.path.utf8))
        let stableIdentifier = digest.map { String(format: "%02x", $0) }.joined()
        return WorkspaceItemID(unchecked: "saved-\(stableIdentifier)")
    }

    private func storageIdentifier(for tab: OpenDocumentTab) -> WorkspaceItemID {
        if let sourceProjectURL = tab.sourceProjectURL?.fileURL {
            return storageIdentifier(for: sourceProjectURL)
        }
        return WorkspaceItemID(unchecked: "untitled-\(tab.id.uuidString.lowercased())")
    }

    private func discoverProjectDirectories(in rootDirectory: URL) throws -> [URL] {
        var projectURLs: [URL] = []
        for url in fileClient.enumerateURLs(rootDirectory, [.isDirectoryKey], [.skipsHiddenFiles]) {
            guard try isDirectory(url) else { continue }
            if try containsProjectManifest(at: url) {
                projectURLs.append(url)
            }
        }
        return projectURLs
    }

    private func relativeFolderPath(
        for projectURL: URL,
        rootDirectory: URL
    ) throws -> RelativeProjectFolderPath? {
        let parentPath = projectURL.deletingLastPathComponent().standardizedFileURL.path
        let rootPath = rootDirectory.standardizedFileURL.path
        guard parentPath != rootPath else { return nil }
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard parentPath.hasPrefix(prefix) else { return nil }
        let relativePath = String(parentPath.dropFirst(prefix.count))
        guard !relativePath.isEmpty else { return nil }
        do {
            return try RelativeProjectFolderPath(validating: relativePath)
        } catch {
            throw WorkspaceCatalogFailure.invalidRelativeFolderPath(
                "Invalid saved project folder path '\(relativePath)': \(error.localizedDescription)"
            )
        }
    }

    private func trimSaveHistoryEntries(for identifier: WorkspaceItemID, limit: Int) throws {
        guard limit > 0 else { return }
        let directory = try saveHistoryEntriesDirectory(for: identifier)
        let entryURLs = try fileClient.contentsOfDirectory(
            directory,
            [.isDirectoryKey, .contentModificationDateKey],
            [.skipsHiddenFiles]
        )
        let sortedEntryURLs = try entryURLs
            .map { entryURL in
                (entryURL, try contentModificationDate(for: entryURL))
            }
            .sorted { lhs, rhs in
                lhs.1 > rhs.1
            }
            .map(\.0)
        guard sortedEntryURLs.count > limit else { return }
        for entryURL in sortedEntryURLs.dropFirst(limit) {
            try removeItemIfExists(at: entryURL)
        }
    }

    private func loadProjectSession(
        from projectURL: URL,
        label: String
    ) throws -> PaintDocumentSession {
        do {
            return try PaintDocumentSession.loadProject(
                from: projectURL,
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        } catch {
            throw WorkspaceCatalogFailure.projectLoadFailed(
                "Could not load \(label) at \(projectURL.lastPathComponent): \(error.localizedDescription)"
            )
        }
    }

    private func readMetadataData(
        at metadataURL: URL,
        label: String
    ) throws -> Data {
        do {
            return try fileClient.readData(metadataURL)
        } catch {
            throw WorkspaceCatalogFailure.metadataReadFailed(
                "Could not read \(label) at \(metadataURL.lastPathComponent): \(error.localizedDescription)"
            )
        }
    }

    private func decodeMetadata<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        label: String
    ) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw WorkspaceCatalogFailure.metadataDecodeFailed(
                "Could not decode \(label): \(error.localizedDescription)"
            )
        }
    }

    private func workspaceItemID(
        validating rawValue: String,
        label: String
    ) throws -> WorkspaceItemID {
        do {
            return try WorkspaceItemID(validating: rawValue)
        } catch {
            throw WorkspaceCatalogFailure.invalidWorkspaceEntry(
                "Invalid \(label) identifier '\(rawValue)': \(error.localizedDescription)"
            )
        }
    }

    private func contentModificationDate(for url: URL) throws -> Date {
        do {
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
            return values.contentModificationDate ?? .distantPast
        } catch {
            throw WorkspaceCatalogFailure.resourceLookupFailed(
                "Could not read modification date for \(url.lastPathComponent): \(error.localizedDescription)"
            )
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
        try fileClient.writeData(data, url, .atomic)
    }

    private func replaceProjectDirectory(from sourceURL: URL, to destinationURL: URL) throws {
        try requireProjectDirectory(at: sourceURL, label: "project snapshot")
        guard sourceURL.standardizedFileURL != destinationURL.standardizedFileURL else {
            return
        }
        try fileClient.createDirectory(destinationURL.deletingLastPathComponent(), true)
        try removeItemIfExists(at: destinationURL)
        try fileClient.copyItem(sourceURL, destinationURL)
    }

    private func requireProjectDirectory(at url: URL, label: String) throws {
        guard fileClient.fileExists(url.path) else {
            throw DocumentWorkspaceError.missingProjectDirectory(label, url)
        }
        guard try isDirectory(url), try containsProjectManifest(at: url) else {
            throw DocumentWorkspaceError.invalidProjectDirectory(label, url)
        }
    }

    private func containsProjectManifest(at url: URL) throws -> Bool {
        let manifestURL = url.appendingPathComponent(Self.manifestFilename, isDirectory: false)
        return fileClient.fileExists(manifestURL.path)
    }

    private func isDirectory(_ url: URL) throws -> Bool {
        try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
    }

    private func removeItemIfExists(at url: URL) throws {
        if fileClient.fileExists(url.path) {
            try fileClient.removeItem(url)
        }
    }

    private func moveDirectoryIfPresent(from sourceURL: URL, to destinationURL: URL) throws {
        guard fileClient.fileExists(sourceURL.path) else { return }
        guard !fileClient.fileExists(destinationURL.path) else { return }
        try fileClient.moveItem(sourceURL, destinationURL)
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
