import Foundation
import PrimoCoreTypes
import PrimoDocumentDomain
import PrimoSystemClients

public struct PaintDocumentPersistenceService {
    private static let maxPackageByteCount = 2 * 1024 * 1024 * 1024
    private static let maxPackageFileCount = 300_000
    private static let maxSingleFileByteCount = 512 * 1024 * 1024
    private static let maxTimelapsePayloadTotalByteCount = 1024 * 1024 * 1024

    let fileClient: FileClient
    let uuidClient: UUIDClient
    private let packageReader: ProjectPackageReader

    public init(fileClient: FileClient, uuidClient: UUIDClient = .live) {
        self.fileClient = fileClient
        self.uuidClient = uuidClient
        self.packageReader = .live(fileClient: fileClient)
    }

    public func prepareProjectDirectory(at url: URL) throws {
        if fileClient.fileExists(url.path) {
            try fileClient.removeItem(url)
        }
        try fileClient.createDirectory(url, true)
    }

    public func createStagedProjectDirectory(for destinationURL: URL, id: UUID) throws -> URL {
        try TemporaryStagingStore.live(
            fileClient: fileClient,
            destinationURL: destinationURL,
            id: id
        )
        .createStagingDirectory()
        .path
        .fileURL
    }

    public func cleanupStagedProjectDirectory(_ stagedProjectURL: URL) throws {
        let staged = StagedProjectPackage(ProjectPackagePath(DocumentProjectPath(stagedProjectURL)))
        let stagingRoot = stagedProjectURL.deletingLastPathComponent()
        let fileClient = fileClient
        let stagingStore = TemporaryStagingStore(
            createStagingDirectory: { staged },
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
        try stagingStore.discard(staged)
    }

    public func validateProjectPackage(at projectURL: URL) throws {
        let package = ProjectPackagePath(DocumentProjectPath(projectURL))
        guard packageReader.fileExists(package) else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Missing project package at \(projectURL.path)")
        }
        try validatePackageFootprint(at: projectURL)
        guard let manifestFile = ProjectPackageFile(package: package, relativePath: "manifest.json") else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid manifest path")
        }
        let manifestData = try packageReader.readData(manifestFile)
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
        try validateManifestSemantics(document)
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

    private func validateManifestSemantics(_ document: StoredPrimoDocument) throws {
        guard document.layers.indices.contains(document.activeLayerIndex.rawValue) else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid active layer index")
        }
        for (expectedIndex, layer) in document.layers.enumerated() {
            guard layer.index.rawValue == expectedIndex else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid layer index ordering")
            }
            guard UnitInterval(layer.opacity) != nil,
                  LayerBlendMode(rawValue: layer.blendMode) != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid layer attributes")
            }
            if let textLayer = layer.textLayer {
                try validateTextLayer(textLayer)
            }
        }

        let folderIDs = Set(document.folders.map(\.id))
        guard folderIDs.count == document.folders.count else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Duplicate folder identifiers")
        }
        for layer in document.layers {
            if let folderID = layer.folderID, !folderIDs.contains(folderID) {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid layer folder reference")
            }
        }
        for folder in document.folders {
            if let anchorLayerIndex = folder.anchorLayerIndex,
               !document.layers.indices.contains(anchorLayerIndex.rawValue) {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid folder anchor layer index")
            }
        }

        try validatePaperStyle(document.paperStyle)
        for frame in document.timelapseFrames {
            guard frame.width.isFinite,
                  frame.height.isFinite,
                  frame.width > 0,
                  frame.height > 0,
                  frame.width <= Double(CanvasSizePolicy.maxVideoDimension),
                  frame.height <= Double(CanvasSizePolicy.maxVideoDimension) else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse frame dimensions")
            }
        }
        for operation in document.timelapseOperations {
            try validateTimelapseOperationSemantics(operation)
        }
    }

    private func validateTextLayer(_ textLayer: TextLayerData) throws {
        guard textLayer.validatedPositionX != nil,
              textLayer.validatedPositionY != nil,
              textLayer.validatedFontSize != nil,
              textLayer.validatedScale != nil,
              textLayer.validatedRotationDegrees != nil,
              textLayer.validatedColor != nil else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid text layer attributes")
        }
    }

    private func validatePaperStyle(_ paperStyle: StoredPrimoDocument.PaperStyle) throws {
        guard CanvasColor(
            red: paperStyle.red,
            green: paperStyle.green,
            blue: paperStyle.blue,
            alpha: paperStyle.alpha
        ) != nil else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid paper style")
        }
    }

    private func validateTimelapseOperationSemantics(_ operation: StoredTimelapseOperation) throws {
        switch operation.kind {
        case .stroke, .blurStroke:
            guard operation.layerIndex != nil,
                  operation.brush != nil,
                  operation.samples != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
        case .fill:
            guard operation.layerIndex != nil,
                  operation.brush != nil,
                  operation.sample != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
        case .undo, .redo:
            break
        case .addLayer:
            try validateOperationName(operation.name)
        case .duplicateLayer, .setLayerName:
            guard operation.layerIndex != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
            try validateOperationName(operation.name)
        case .deleteLayer, .mergeLayerDown, .clearLayerMask, .applyLayerMask, .clearLayer:
            guard operation.layerIndex != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
        case .moveLayer:
            guard operation.layerIndex != nil,
                  operation.destinationIndex != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
        case .createFolder:
            guard operation.folderID != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
            try validateOperationName(operation.name)
        case .deleteFolder:
            guard operation.folderID != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
        case .setFolderVisibility:
            guard operation.folderID != nil,
                  operation.isVisible != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
        case .setFolderName:
            guard operation.folderID != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
            try validateOperationName(operation.name)
        case .setFolderExpanded:
            guard operation.folderID != nil,
                  operation.isExpanded != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
        case .assignLayerToFolder:
            guard operation.layerIndex != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
        case .setLayerVisibility:
            guard operation.layerIndex != nil,
                  operation.isVisible != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
        case .setLayerLocked:
            guard operation.layerIndex != nil,
                  operation.isLocked != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
        case .setLayerAlphaLocked:
            guard operation.layerIndex != nil,
                  operation.isAlphaLocked != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
        case .setLayerClipped:
            guard operation.layerIndex != nil,
                  operation.isClipped != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
        case .setLayerOpacity:
            guard operation.layerIndex != nil,
                  let opacity = operation.opacity,
                  UnitInterval(opacity) != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
        case .setLayerBlendMode:
            guard operation.layerIndex != nil,
                  let blendMode = operation.blendMode,
                  LayerBlendMode(rawValue: blendMode) != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
        case .replaceLayerPixels, .replaceLayerMask:
            guard operation.layerIndex != nil,
                  operation.dataFilename != nil else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
        case .setPaperStyle:
            guard let paperStyle = operation.paperStyle else {
                throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
            }
            try validatePaperStyle(paperStyle)
        }
    }

    private func validateOperationName(_ name: String?) throws {
        guard let name,
              name.count <= CanvasSizePolicy.maxLayerNameLength else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid timelapse operation")
        }
    }

    public func publishStagedProjectDirectory(_ stagedProjectURL: URL, to destinationURL: URL) throws {
        try validateProjectPackage(at: stagedProjectURL)
        let staged = StagedProjectPackage(ProjectPackagePath(DocumentProjectPath(stagedProjectURL)))
        let saved = SavedProjectPackage(ProjectPackagePath(DocumentProjectPath(destinationURL)))

        if fileClient.fileExists(destinationURL.path) {
            let backupName = ".\(destinationURL.lastPathComponent).backup-\(uuidClient.generate().uuidString)"
            let backupURL = destinationURL.deletingLastPathComponent().appendingPathComponent(backupName, isDirectory: true)
            let packageWriter = ProjectPackageWriter.live(fileClient: fileClient, backupName: { backupName })
            do {
                try packageWriter.replacePackage(staged, saved)
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
            let packageWriter = ProjectPackageWriter.live(fileClient: fileClient, backupName: { nil })
            try packageWriter.replacePackage(staged, saved)
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
        let package = ProjectPackagePath(DocumentProjectPath(projectURL))
        guard let packageFile = ProjectPackageFile(package: package, relativePath: relativePath) else {
            throw PaintDocumentPersistenceError.invalidProjectPackage("Invalid \(label) path \(relativePath)")
        }
        let data = try packageReader.readData(packageFile)
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
        let package = ProjectPackagePath(DocumentProjectPath(projectURL))
        let urls = try packageReader.enumerateFiles(package).map(\.fileURL)
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
