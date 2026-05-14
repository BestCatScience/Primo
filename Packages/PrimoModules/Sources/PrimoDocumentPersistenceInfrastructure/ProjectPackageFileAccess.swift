import Foundation
import PrimoCoreTypes
import PrimoDocumentDomain

public struct ProjectPackagePath: Hashable, Sendable {
    public let projectPath: DocumentProjectPath

    public init(_ projectPath: DocumentProjectPath) {
        self.projectPath = projectPath
    }

    public var fileURL: URL { projectPath.fileURL }
}

public struct ProjectPackageFile: Hashable, Sendable {
    public let package: ProjectPackagePath
    public let relativePath: String

    public init?(package: ProjectPackagePath, relativePath: String) {
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.split(separator: "/").contains("..")
        else { return nil }
        self.package = package
        self.relativePath = relativePath
    }

    public var fileURL: URL {
        package.fileURL.appendingPathComponent(relativePath, isDirectory: false)
    }
}

public struct StagedProjectPackage: Hashable, Sendable {
    public let path: ProjectPackagePath

    public init(_ path: ProjectPackagePath) {
        self.path = path
    }
}

public struct SavedProjectPackage: Hashable, Sendable {
    public let path: ProjectPackagePath

    public init(_ path: ProjectPackagePath) {
        self.path = path
    }
}

public struct TemporaryProjectPath: Hashable, Sendable {
    public let fileURL: URL

    public init(_ fileURL: URL) {
        self.fileURL = fileURL.standardizedFileURL
    }
}

public struct ProjectPackageReader: Sendable {
    public let fileExists: @Sendable (ProjectPackagePath) -> Bool
    public let readData: @Sendable (ProjectPackageFile) throws -> Data
    public let enumerateFiles: @Sendable (ProjectPackagePath) throws -> [ProjectPackageFile]

    public init(
        fileExists: @escaping @Sendable (ProjectPackagePath) -> Bool,
        readData: @escaping @Sendable (ProjectPackageFile) throws -> Data,
        enumerateFiles: @escaping @Sendable (ProjectPackagePath) throws -> [ProjectPackageFile]
    ) {
        self.fileExists = fileExists
        self.readData = readData
        self.enumerateFiles = enumerateFiles
    }

    public static func live(fileClient: FileClient) -> Self {
        Self(
            fileExists: { package in
                fileClient.fileExists(package.fileURL.path)
            },
            readData: { file in
                try fileClient.readData(file.fileURL)
            },
            enumerateFiles: { package in
                try fileClient.enumerateURLs(
                    package.fileURL,
                    [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey],
                    []
                )
                .compactMap { url in
                    try validatedPackageFileIfRegular(url, in: package)
                }
            }
        )
    }
}

private func validatedPackageFileIfRegular(_ url: URL, in package: ProjectPackagePath) throws -> ProjectPackageFile? {
    let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
    guard values.isSymbolicLink != true else {
        throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid symbolic link in package entry")
    }
    guard values.isRegularFile == true else {
        return nil
    }

    let rootURL = package.fileURL.resolvingSymlinksInPath().standardizedFileURL
    let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL
    guard resolvedURL.path.hasPrefix(rootURL.path + "/") else {
        throw PaintDocumentPersistenceError.invalidProjectPackage("Escaping package entry")
    }

    let standardizedURL = url.standardizedFileURL
    let rootPath = package.fileURL.standardizedFileURL.path
    guard standardizedURL.path.hasPrefix(rootPath + "/") else {
        throw PaintDocumentPersistenceError.invalidProjectPackage("Escaping package entry")
    }
    let relativePath = String(standardizedURL.path.dropFirst(rootPath.count + 1))
    guard let file = ProjectPackageFile(package: package, relativePath: relativePath) else {
        throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid package entry path \(relativePath)")
    }
    return file
}

public struct ProjectPackageWriter: Sendable {
    public let writeDataAtomically: @Sendable (Data, ProjectPackageFile) throws -> Void
    public let replacePackage: @Sendable (StagedProjectPackage, SavedProjectPackage) throws -> Void
    public let copyFile: @Sendable (ProjectPackageFile, ProjectPackageFile) throws -> Void

    public init(
        writeDataAtomically: @escaping @Sendable (Data, ProjectPackageFile) throws -> Void,
        replacePackage: @escaping @Sendable (StagedProjectPackage, SavedProjectPackage) throws -> Void,
        copyFile: @escaping @Sendable (ProjectPackageFile, ProjectPackageFile) throws -> Void
    ) {
        self.writeDataAtomically = writeDataAtomically
        self.replacePackage = replacePackage
        self.copyFile = copyFile
    }

    public static func live(fileClient: FileClient, backupName: @escaping @Sendable () -> String?) -> Self {
        Self(
            writeDataAtomically: { data, file in
                try fileClient.writeData(data, file.fileURL, .atomic)
            },
            replacePackage: { staged, saved in
                try fileClient.createDirectory(saved.path.fileURL.deletingLastPathComponent(), true)
                if fileClient.fileExists(saved.path.fileURL.path) {
                    try fileClient.replaceItem(saved.path.fileURL, staged.path.fileURL, backupName())
                } else {
                    try fileClient.moveItem(staged.path.fileURL, saved.path.fileURL)
                }
            },
            copyFile: { source, destination in
                if fileClient.fileExists(destination.fileURL.path) {
                    try fileClient.removeItem(destination.fileURL)
                }
                try fileClient.copyItem(source.fileURL, destination.fileURL)
            }
        )
    }
}

public struct TemporaryStagingStore: Sendable {
    public let createStagingDirectory: @Sendable () throws -> StagedProjectPackage
    public let discard: @Sendable (StagedProjectPackage) throws -> Void

    public init(
        createStagingDirectory: @escaping @Sendable () throws -> StagedProjectPackage,
        discard: @escaping @Sendable (StagedProjectPackage) throws -> Void
    ) {
        self.createStagingDirectory = createStagingDirectory
        self.discard = discard
    }

    public static func live(fileClient: FileClient, destinationURL: URL, id: UUID) -> Self {
        let stagingRoot = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(".primo-staging", isDirectory: true)
        let stagedProjectURL = stagingRoot
            .appendingPathComponent("\(destinationURL.lastPathComponent).\(id.uuidString)", isDirectory: true)
        return Self(
            createStagingDirectory: {
                try fileClient.createDirectory(stagingRoot, true)
                if fileClient.fileExists(stagedProjectURL.path) {
                    try fileClient.removeItem(stagedProjectURL)
                }
                try fileClient.createDirectory(stagedProjectURL, true)
                return StagedProjectPackage(ProjectPackagePath(DocumentProjectPath(stagedProjectURL)))
            },
            discard: { staged in
                if fileClient.fileExists(staged.path.fileURL.path) {
                    try fileClient.removeItem(staged.path.fileURL)
                }
                if let children = try? fileClient.contentsOfDirectory(stagingRoot, [], []),
                   children.isEmpty,
                   fileClient.fileExists(stagingRoot.path) {
                    try fileClient.removeItem(stagingRoot)
                }
            }
        )
    }
}
