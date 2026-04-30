import Foundation
import PrimoCoreTypes
import PrimoDocumentDomain

public struct PaintDocumentPersistenceService {
    private static let maxPackageByteCount = 2 * 1024 * 1024 * 1024
    private static let maxPackageFileCount = 300_000
    private static let maxSingleFileByteCount = 512 * 1024 * 1024
    private static let maxTimelapsePayloadTotalByteCount = 1024 * 1024 * 1024

    let fileClient: FileClient

    public init(fileClient: FileClient) {
        self.fileClient = fileClient
    }

    public func prepareProjectDirectory(at url: URL) throws {
        if fileClient.fileExists(url.path) {
            try fileClient.removeItem(url)
        }
        try fileClient.createDirectory(url, true)
    }

    public func createStagedProjectDirectory(for destinationURL: URL, id: UUID) throws -> URL {
        let stagingRoot = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(".primo-staging", isDirectory: true)
        let stagedProjectURL = stagingRoot
            .appendingPathComponent("\(destinationURL.lastPathComponent).\(id.uuidString)", isDirectory: true)
        try fileClient.createDirectory(stagingRoot, true)
        if fileClient.fileExists(stagedProjectURL.path) {
            try fileClient.removeItem(stagedProjectURL)
        }
        try fileClient.createDirectory(stagedProjectURL, true)
        return stagedProjectURL
    }

    public func cleanupStagedProjectDirectory(_ stagedProjectURL: URL) throws {
        if fileClient.fileExists(stagedProjectURL.path) {
            try fileClient.removeItem(stagedProjectURL)
        }
        let stagingRoot = stagedProjectURL.deletingLastPathComponent()
        if let children = try? fileClient.contentsOfDirectory(stagingRoot, [], []),
           children.isEmpty,
           fileClient.fileExists(stagingRoot.path) {
            try fileClient.removeItem(stagingRoot)
        }
    }

    public func validateProjectPackage(at projectURL: URL) throws {
        guard fileClient.fileExists(projectURL.path) else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Missing project package at \(projectURL.path)")
        }
        try validatePackageFootprint(at: projectURL)
        let manifestURL = projectURL.appendingPathComponent("manifest.json", isDirectory: false)
        let manifestData = try fileClient.readData(manifestURL)
        let document = try JSONDecoder().decode(StoredPrimoDocument.self, from: manifestData)
        guard PixelGeometry(width: document.canvasWidth, height: document.canvasHeight) != nil,
              !document.layers.isEmpty,
              document.folders.count <= CanvasSizePolicy.maxFolderCount,
              document.timelapseOperations.count <= CanvasSizePolicy.maxTimelapseOperationCount else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid project manifest dimensions or layers")
        }
        guard document.layers.allSatisfy({ $0.name.count <= CanvasSizePolicy.maxLayerNameLength }),
              document.folders.allSatisfy({ $0.name.count <= CanvasSizePolicy.maxLayerNameLength }) else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid project manifest name length")
        }

        guard let geometry = PixelGeometry(width: document.canvasWidth, height: document.canvasHeight) else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid project manifest dimensions")
        }
        guard document.layers.count <= CanvasSizePolicy.maxLayerCountForCanvas(geometry),
              CanvasSizePolicy.layerPixelBytesFitDocumentBudget(
                canvasRGBAByteCount: geometry.rgbaByteCount,
                layerCount: document.layers.count
              ) else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Project manifest exceeds layer memory budget")
        }
        let expectedLayerBytes = geometry.rgbaByteCount
        let expectedMaskBytes = geometry.maskByteCount
        for layer in document.layers {
            try validateRelativeFile(
                layer.pixelFilename,
                in: projectURL,
                expectedByteCount: expectedLayerBytes,
                label: "layer pixels"
            )
            if let maskFilename = layer.maskFilename {
                try validateRelativeFile(
                    maskFilename,
                    in: projectURL,
                    expectedByteCount: expectedMaskBytes,
                    label: "layer mask"
                )
            }
        }

        for frame in document.timelapseFrames {
            _ = try validateReferencedAsset(
                frame.filename,
                in: projectURL,
                maxByteCount: Self.maxSingleFileByteCount,
                label: "timelapse frame"
            )
        }

        var timelapsePayloadBytes = 0
        for operation in document.timelapseOperations {
            if let dataFilename = operation.dataFilename {
                let payloadBytes = try validateReferencedAsset(
                    dataFilename,
                    in: projectURL,
                    maxByteCount: Self.maxSingleFileByteCount,
                    label: "timelapse payload"
                )
                let newTotal = timelapsePayloadBytes.addingReportingOverflow(payloadBytes)
                guard !newTotal.overflow,
                      newTotal.partialValue <= Self.maxTimelapsePayloadTotalByteCount else {
                    throw PaintDocumentPersistenceError.invalidProjectPackage("Timelapse payloads are too large")
                }
                timelapsePayloadBytes = newTotal.partialValue
            }
        }
    }

    public func publishStagedProjectDirectory(_ stagedProjectURL: URL, to destinationURL: URL) throws {
        try validateProjectPackage(at: stagedProjectURL)
        try fileClient.createDirectory(destinationURL.deletingLastPathComponent(), true)

        if fileClient.fileExists(destinationURL.path) {
            let backupName = ".\(destinationURL.lastPathComponent).backup-\(UUID().uuidString)"
            let backupURL = destinationURL.deletingLastPathComponent().appendingPathComponent(backupName, isDirectory: true)
            do {
                try fileClient.replaceItem(destinationURL, stagedProjectURL, backupName)
                do {
                    try validateProjectPackage(at: destinationURL)
                    if fileClient.fileExists(backupURL.path) {
                        try fileClient.removeItem(backupURL)
                    }
                } catch {
                    try restoreBackupIfAvailable(backupURL: backupURL, destinationURL: destinationURL)
                    throw error
                }
            } catch {
                if fileClient.fileExists(backupURL.path) {
                    try? restoreBackupIfAvailable(backupURL: backupURL, destinationURL: destinationURL)
                }
                throw error
            }
        } else {
            try fileClient.moveItem(stagedProjectURL, destinationURL)
            try validateProjectPackage(at: destinationURL)
        }
    }

    public func createProjectSubdirectories(
        in projectURL: URL,
        usesOperationTimelapsePersistence: Bool
    ) throws -> (layersDirectory: URL, timelapseDirectory: URL, timelapseDataDirectory: URL) {
        let layersDirectory = projectURL.appendingPathComponent("Layers", isDirectory: true)
        let timelapseDirectory = projectURL.appendingPathComponent("Timelapse", isDirectory: true)
        let timelapseDataDirectory = projectURL.appendingPathComponent("TimelapseData", isDirectory: true)
        try fileClient.createDirectory(layersDirectory, true)
        if usesOperationTimelapsePersistence {
            try fileClient.createDirectory(timelapseDataDirectory, true)
        } else {
            try fileClient.createDirectory(timelapseDirectory, true)
        }
        return (layersDirectory, timelapseDirectory, timelapseDataDirectory)
    }

    public func writeAtomic(_ data: Data, to url: URL) throws {
        try fileClient.writeData(data, url, Data.WritingOptions.atomic)
    }

    public func loadData(from url: URL) throws -> Data {
        try fileClient.readData(url)
    }

    public func replaceItemIfNeeded(at destinationURL: URL, with sourceURL: URL) throws {
        if fileClient.fileExists(destinationURL.path) {
            try fileClient.removeItem(destinationURL)
        }
        try fileClient.copyItem(sourceURL, destinationURL)
    }

    private func validateRelativeFile(
        _ relativePath: String,
        in projectURL: URL,
        expectedByteCount: Int,
        label: String
    ) throws {
        let fileURL = try validatedRelativeURL(relativePath, in: projectURL, label: label)
        try validateNonSymlink(fileURL, packageRoot: projectURL, label: label)
        let data = try fileClient.readData(fileURL)
        guard data.count == expectedByteCount else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid byte count for \(label) \(relativePath)")
        }
    }

    private func validateReferencedAsset(
        _ relativePath: String,
        in projectURL: URL,
        maxByteCount: Int,
        label: String
    ) throws -> Int {
        let fileURL = try validatedRelativeURL(relativePath, in: projectURL, label: label)
        guard fileClient.fileExists(fileURL.path) else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Missing \(label) \(relativePath)")
        }
        try validateNonSymlink(fileURL, packageRoot: projectURL, label: label)
        let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid \(label) file")
        }
        let fileSize = values.fileSize ?? 0
        guard fileSize <= maxByteCount else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Oversized \(label)")
        }
        return fileSize
    }

    private func validatedRelativeURL(_ relativePath: String, in projectURL: URL, label: String) throws -> URL {
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.split(separator: "/").contains("..")
        else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid \(label) path \(relativePath)")
        }
        let fileURL = projectURL.appendingPathComponent(relativePath, isDirectory: false).standardizedFileURL
        let rootURL = projectURL.standardizedFileURL
        guard fileURL.path == rootURL.path || fileURL.path.hasPrefix(rootURL.path + "/") else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Escaping \(label) path \(relativePath)")
        }
        return fileURL
    }

    private func validatePackageFootprint(at projectURL: URL) throws {
        let urls = fileClient.enumerateURLs(
            projectURL,
            [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey],
            []
        )
        guard urls.count <= Self.maxPackageFileCount else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Project package contains too many files")
        }
        var totalBytes = 0
        for url in urls {
            try validateNonSymlink(url, packageRoot: projectURL, label: "package entry")
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values?.isRegularFile == true else { continue }
            let fileSize = values?.fileSize ?? 0
            guard fileSize <= Self.maxSingleFileByteCount else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Project package contains an oversized file")
            }
            let newTotal = totalBytes.addingReportingOverflow(fileSize)
            guard !newTotal.overflow, newTotal.partialValue <= Self.maxPackageByteCount else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Project package is too large")
            }
            totalBytes = newTotal.partialValue
        }
    }

    private func validateNonSymlink(_ fileURL: URL, packageRoot: URL, label: String) throws {
        let values = try? fileURL.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard values?.isSymbolicLink != true else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid symbolic link in \(label)")
        }
        let resolved = fileURL.resolvingSymlinksInPath().standardizedFileURL
        let root = packageRoot.resolvingSymlinksInPath().standardizedFileURL
        guard resolved.path == root.path || resolved.path.hasPrefix(root.path + "/") else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Escaping symbolic link in \(label)")
        }
    }

    private func restoreBackupIfAvailable(backupURL: URL, destinationURL: URL) throws {
        guard fileClient.fileExists(backupURL.path) else { return }
        if fileClient.fileExists(destinationURL.path) {
            try fileClient.removeItem(destinationURL)
        }
        try fileClient.moveItem(backupURL, destinationURL)
    }
}

public enum PaintDocumentPersistenceError: LocalizedError, Equatable {
    case invalidProjectPackage(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidProjectPackage(message):
            return message
        }
    }
}
