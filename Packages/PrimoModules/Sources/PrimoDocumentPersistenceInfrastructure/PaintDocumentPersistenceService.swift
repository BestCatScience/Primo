import Foundation
import PrimoCoreTypes

public struct PaintDocumentPersistenceService {
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
        let manifestURL = projectURL.appendingPathComponent("manifest.json", isDirectory: false)
        let manifestData = try fileClient.readData(manifestURL)
        let document = try JSONDecoder().decode(StoredPrimoDocument.self, from: manifestData)
        guard document.canvasWidth > 0, document.canvasHeight > 0, !document.layers.isEmpty else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid project manifest dimensions or layers")
        }

        let expectedLayerBytes = document.canvasWidth * document.canvasHeight * 4
        let expectedMaskBytes = document.canvasWidth * document.canvasHeight
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
            _ = try validatedRelativeURL(frame.filename, in: projectURL, label: "timelapse frame")
            guard fileClient.fileExists(projectURL.appendingPathComponent(frame.filename, isDirectory: false).path) else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Missing timelapse frame \(frame.filename)")
            }
        }

        for operation in document.timelapseOperations {
            if let dataFilename = operation.dataFilename {
                _ = try validatedRelativeURL(dataFilename, in: projectURL, label: "timelapse payload")
                guard fileClient.fileExists(projectURL.appendingPathComponent(dataFilename, isDirectory: false).path) else {
                    throw PaintDocumentPersistenceError.invalidProjectPackage("Missing timelapse payload \(dataFilename)")
                }
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
        let data = try fileClient.readData(fileURL)
        guard data.count == expectedByteCount else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid byte count for \(label) \(relativePath)")
        }
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
