import CoreGraphics
import Foundation
import UIKit

extension PaintDocumentSession {
    func compositePNGData(paperStyle: CanvasPaperStyle) -> Data? {
        return renderedCompositeImage(paperStyle: paperStyle)?.pngData()
    }

    func saveProject(
        to url: URL,
        paperStyle: CanvasPaperStyle? = nil
    ) throws {
        let snapshot = makePersistenceSnapshot(
            paperStyle: paperStyle ?? paperStyleValue
        )
        try persistenceService.prepareProjectDirectory(at: url)
        let directories = try persistenceService.createProjectSubdirectories(
            in: url,
            usesOperationTimelapsePersistence: snapshot.usesOperationTimelapsePersistence
        )
        try snapshot.persist(
            directories: directories,
            persistenceService: persistenceService,
            fileClient: fileClient,
            manifestURL: url.appendingPathComponent("manifest.json", isDirectory: false)
        )
    }

    static func loadProject(
        from url: URL,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) throws -> PaintDocumentSession {
        let services = PaintDocumentSessionServices(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
        let manifestURL = url.appendingPathComponent("manifest.json", isDirectory: false)
        let data = try services.persistence.loadData(from: manifestURL)
        let document = try JSONDecoder().decode(StoredPrimoDocument.self, from: data)
        let contract = try PaintDocumentPersistenceContract(validating: document)
        let restorationPlan = try PaintDocumentRestorePlan(
            document: document,
            contract: contract,
            baseURL: url,
            services: services,
            fileClient: fileClient
        )

        let session = PaintDocumentSession(
            width: contract.canvasWidth,
            height: contract.canvasHeight,
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
        try session.applyRestorationPlan(restorationPlan, persistenceService: services.persistence)
        return session
    }

    private func makePersistenceSnapshot(
        paperStyle: CanvasPaperStyle
    ) -> PaintDocumentPersistenceSnapshot {
        let layerInfos = bridgeLayerInfos()
        let folderInfos = bridgeFolderInfos()
        let layerPayloads = layerInfos.enumerated().map { index, layerInfo in
            let pixelFilename = String(format: "layer-%04d.rgba", index)
            let pixelData = pixelDataForLayer(index: index)
            let maskData = bridgeMaskDataForLayer(index: index)
            let maskFilename = maskData == nil ? nil : String(format: "layer-mask-%04d.mask", index)
            return PaintDocumentPersistenceSnapshot.LayerPayload(
                manifest: StoredPrimoDocument.Layer(
                    index: .unchecked(index),
                    name: layerInfo.name,
                    visible: layerInfo.visible,
                    locked: layerInfo.locked,
                    alphaLocked: layerInfo.alphaLocked,
                    clipped: layerInfo.clipped,
                    opacity: layerInfo.opacity,
                    blendMode: layerInfo.blendMode,
                    folderID: layerInfo.folderID >= 0 ? .unchecked(Int(layerInfo.folderID)) : nil,
                    textLayer: storedTextLayer(at: index),
                    pixelFilename: "Layers/\(pixelFilename)",
                    maskFilename: maskFilename.map { "Layers/\($0)" }
                ),
                pixelFilename: pixelFilename,
                pixelData: pixelData,
                maskFilename: maskFilename,
                maskData: maskData
            )
        }

        let storedFolders = folderInfos.map { folderInfo in
            StoredPrimoDocument.Folder(
                id: .unchecked(Int(folderInfo.folderID)),
                name: folderInfo.name,
                visible: folderInfo.visible,
                expanded: folderInfo.expanded,
                anchorLayerIndex: folderInfo.anchorLayerIndex >= 0 ? .unchecked(Int(folderInfo.anchorLayerIndex)) : nil
            )
        }

        let timelapseFramePayloads: [PaintDocumentPersistenceSnapshot.TimelapseFramePayload] = timelapseUsesOperationPersistence
            ? []
            : timelapseFramesSnapshot.enumerated().map { index, frame in
                let relativeFilename = String(format: "frame-%06d.jpg", index)
                return PaintDocumentPersistenceSnapshot.TimelapseFramePayload(
                    sourceURL: frame.imageURL,
                    relativeFilename: relativeFilename,
                    storedFrame: StoredPrimoDocument.TimelapseFrame(
                        filename: "Timelapse/\(relativeFilename)",
                        width: Double(frame.size.width),
                        height: Double(frame.size.height)
                    )
                )
            }

        return PaintDocumentPersistenceSnapshot(
            canvasWidth: bridgeCanvasWidth,
            canvasHeight: bridgeCanvasHeight,
            activeLayerIndex: .unchecked(bridgeActiveLayerIndex()),
            paperStyle: paperStyle,
            layers: layerPayloads,
            folders: storedFolders,
            timelapseFrames: timelapseFramePayloads,
            timelapseEvents: timelapseEventsSnapshot,
            usesOperationTimelapsePersistence: timelapseUsesOperationPersistence
        )
    }

    private func applyRestorationPlan(
        _ restorationPlan: PaintDocumentRestorePlan,
        persistenceService: PaintDocumentPersistenceService
    ) throws {
        setStoredPaperStyle(restorationPlan.paperStyle)
        replaceStoredTextLayers(with: [:])

        while bridgeLayerInfos().count < restorationPlan.layers.count {
            _ = bridgeAddLayer(name: "Layer \(bridgeLayerInfos().count + 1)")
        }

        for layer in restorationPlan.layers {
            bridgeReplaceLayerPixels(index: layer.index, data: layer.pixelData, transient: true)
            if let maskData = layer.maskData {
                bridgeReplaceLayerMask(index: layer.index, data: maskData)
            } else {
                bridgeClearLayerMask(index: layer.index)
            }
            bridgeSetLayerName(layer.name, index: layer.index)
            bridgeSetLayerVisible(layer.visible, index: layer.index)
            bridgeSetLayerLocked(layer.locked, index: layer.index)
            bridgeSetLayerAlphaLocked(layer.alphaLocked, index: layer.index)
            bridgeSetLayerClipped(layer.clipped, index: layer.index)
            bridgeSetLayerOpacity(CGFloat(layer.opacity), index: layer.index)
            bridgeSetLayerBlendMode(layer.blendMode, index: layer.index)
            if let textLayer = layer.textLayer {
                setStoredTextLayer(textLayer, at: layer.index)
            }
        }

        var folderIDMap: [DocumentFolderID: Int] = [:]
        for folder in restorationPlan.folders {
            let newFolderID = bridgeCreateFolder(name: folder.name, layerIndex: folder.anchorLayerIndex ?? -1)
            folderIDMap[folder.id] = newFolderID
            bridgeSetFolderVisible(folder.visible, folderID: newFolderID)
            bridgeSetFolderExpanded(folder.expanded, folderID: newFolderID)
        }

        for layer in restorationPlan.layers {
            guard let storedFolderID = layer.folderID, let resolvedFolderID = folderIDMap[storedFolderID] else { continue }
            _ = bridgeSetLayerFolder(index: layer.index, folderID: resolvedFolderID)
        }

        setBridgeActiveLayerIndex(restorationPlan.activeLayerIndex)

        switch restorationPlan.timelapse {
        case let .operations(events):
            restoreStoredTimelapseOperations(events)
        case let .frames(frames):
            let restoredFrames = try frames.enumerated().map { index, frame in
                let destinationURL = timelapseService.makeFrameURL(in: timelapseDirectoryURL, frameID: index)
                try persistenceService.replaceItemIfNeeded(at: destinationURL, with: frame.sourceURL)
                return TimelapseFrame(imageURL: destinationURL, size: frame.size)
            }
            restoreStoredTimelapseFrames(restoredFrames)
        }

        invalidateStoredThumbnailCache()
        resetTrackedEditingState()
        bridgeClearHistory()
    }
}

private struct PaintDocumentPersistenceSnapshot {
    struct LayerPayload {
        let manifest: StoredPrimoDocument.Layer
        let pixelFilename: String
        let pixelData: Data
        let maskFilename: String?
        let maskData: Data?
    }

    struct TimelapseFramePayload {
        let sourceURL: URL
        let relativeFilename: String
        let storedFrame: StoredPrimoDocument.TimelapseFrame
    }

    let canvasWidth: Int
    let canvasHeight: Int
    let activeLayerIndex: DocumentLayerIndex
    let paperStyle: CanvasPaperStyle
    let layers: [LayerPayload]
    let folders: [StoredPrimoDocument.Folder]
    let timelapseFrames: [TimelapseFramePayload]
    let timelapseEvents: [TimelapseOperation]
    let usesOperationTimelapsePersistence: Bool

    func persist(
        directories: (layersDirectory: URL, timelapseDirectory: URL, timelapseDataDirectory: URL),
        persistenceService: PaintDocumentPersistenceService,
        fileClient: FileClient,
        manifestURL: URL
    ) throws {
        for layer in layers {
            try persistenceService.writeAtomic(
                layer.pixelData,
                to: directories.layersDirectory.appendingPathComponent(layer.pixelFilename, isDirectory: false)
            )
            if let maskFilename = layer.maskFilename, let maskData = layer.maskData {
                try persistenceService.writeAtomic(
                    maskData,
                    to: directories.layersDirectory.appendingPathComponent(maskFilename, isDirectory: false)
                )
            }
        }

        if !usesOperationTimelapsePersistence {
            for frame in timelapseFrames {
                try persistenceService.replaceItemIfNeeded(
                    at: directories.timelapseDirectory.appendingPathComponent(frame.relativeFilename, isDirectory: false),
                    with: frame.sourceURL
                )
            }
        }

        let storedTimelapseOperations = usesOperationTimelapsePersistence
            ? try timelapseEvents.enumerated().map { index, event in
                try event.storedRepresentation(
                    index: index,
                    dataDirectory: directories.timelapseDataDirectory,
                    fileClient: fileClient
                )
            }
            : []

        let document = StoredPrimoDocument(
            version: 5,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            activeLayerIndex: activeLayerIndex,
            paperStyle: StoredPrimoDocument.PaperStyle(
                red: Double(paperStyle.red),
                green: Double(paperStyle.green),
                blue: Double(paperStyle.blue),
                alpha: Double(paperStyle.alpha),
                isTransparent: paperStyle.isTransparent
            ),
            layers: layers.map(\.manifest),
            folders: folders,
            timelapseFrames: usesOperationTimelapsePersistence ? [StoredPrimoDocument.TimelapseFrame]() : timelapseFrames.map(\.storedFrame),
            timelapseOperations: storedTimelapseOperations
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(document)
        try persistenceService.writeAtomic(manifestData, to: manifestURL)
    }
}

private struct PaintDocumentPersistenceContract {
    let canvasWidth: Int
    let canvasHeight: Int

    var pixelByteCount: Int {
        canvasWidth * canvasHeight * 4
    }

    var maskByteCount: Int {
        canvasWidth * canvasHeight
    }

    init(validating document: StoredPrimoDocument) throws {
        guard document.canvasWidth > 0, document.canvasHeight > 0 else {
            throw PrimoDocumentError.contractViolation("Document contract failed: canvas dimensions must be positive.")
        }
        guard !document.layers.isEmpty else {
            throw PrimoDocumentError.contractViolation("Document contract failed: at least one layer is required.")
        }

        try Self.validatePaperStyle(document.paperStyle, label: "document paper style")

        let expectedLayerIndices = Array(0..<document.layers.count)
        let actualLayerIndices = document.layers.map(\.index.rawValue).sorted()
        guard actualLayerIndices == expectedLayerIndices else {
            throw PrimoDocumentError.contractViolation("Document contract failed: layer indices must be contiguous from 0.")
        }

        guard expectedLayerIndices.contains(document.activeLayerIndex.rawValue) else {
            throw PrimoDocumentError.contractViolation("Document contract failed: active layer index is out of range.")
        }

        let folderIDs = document.folders.map(\.id.rawValue)
        guard Set(folderIDs).count == folderIDs.count else {
            throw PrimoDocumentError.contractViolation("Document contract failed: folder identifiers must be unique.")
        }

        let folderIDSet = Set(folderIDs)
        let layerFolderIDs = Set(document.layers.compactMap(\.folderID?.rawValue))
        guard layerFolderIDs.isSubset(of: folderIDSet) else {
            throw PrimoDocumentError.contractViolation("Document contract failed: all layer folder references must resolve.")
        }

        let validLayerIndexSet = Set(expectedLayerIndices)
        let anchorIndices = document.folders.compactMap(\.anchorLayerIndex?.rawValue)
        guard anchorIndices.allSatisfy(validLayerIndexSet.contains) else {
            throw PrimoDocumentError.contractViolation("Document contract failed: folder anchor indices must resolve to existing layers.")
        }

        try document.layers.forEach { layer in
            try Self.validateLayer(layer, canvasWidth: document.canvasWidth, canvasHeight: document.canvasHeight)
        }

        guard document.timelapseFrames.isEmpty || document.timelapseOperations.isEmpty else {
            throw PrimoDocumentError.contractViolation("Document contract failed: timelapse data must use either frames or operations, not both.")
        }

        guard document.timelapseFrames.allSatisfy({ $0.width > 0 && $0.height > 0 }) else {
            throw PrimoDocumentError.contractViolation("Document contract failed: timelapse frame sizes must be positive.")
        }

        try document.timelapseFrames.forEach { frame in
            try Self.validateRelativePath(frame.filename, requiredPrefix: "Timelapse/", label: "timelapse frame filename")
        }

        try document.timelapseOperations.forEach(Self.validateTimelapseOperation)

        self.canvasWidth = document.canvasWidth
        self.canvasHeight = document.canvasHeight
    }

    private static func validateLayer(
        _ layer: StoredPrimoDocument.Layer,
        canvasWidth: Int,
        canvasHeight: Int
    ) throws {
        try validateUnitInterval(layer.opacity, label: "layer \(layer.index.rawValue) opacity")
        guard LayerBlendMode(rawValue: layer.blendMode) != nil else {
            throw PrimoDocumentError.contractViolation(
                "Document contract failed: layer \(layer.index.rawValue) blend mode is invalid."
            )
        }
        try validateRelativePath(
            layer.pixelFilename,
            requiredPrefix: "Layers/",
            label: "layer \(layer.index.rawValue) pixel filename"
        )
        if let maskFilename = layer.maskFilename {
            try validateRelativePath(
                maskFilename,
                requiredPrefix: "Layers/",
                label: "layer \(layer.index.rawValue) mask filename"
            )
        }
        if let textLayer = layer.textLayer {
            try validateTextLayer(
                textLayer,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                label: "layer \(layer.index.rawValue) text layer"
            )
        }
    }

    private static func validateTimelapseOperation(_ operation: StoredTimelapseOperation) throws {
        if let opacity = operation.opacity {
            try validateUnitInterval(opacity, label: "timelapse operation opacity")
        }
        if let blendMode = operation.blendMode, LayerBlendMode(rawValue: blendMode) == nil {
            throw PrimoDocumentError.contractViolation("Document contract failed: timelapse operation blend mode is invalid.")
        }
        if let dataFilename = operation.dataFilename {
            try validateRelativePath(
                dataFilename,
                requiredPrefix: "TimelapseData/",
                label: "timelapse operation data filename"
            )
        }
        if let paperStyle = operation.paperStyle {
            try validatePaperStyle(paperStyle, label: "timelapse operation paper style")
        }
    }

    private static func validateTextLayer(
        _ textLayer: TextLayerData,
        canvasWidth: Int,
        canvasHeight: Int,
        label: String
    ) throws {
        let finiteValues: [(Double, String)] = [
            (textLayer.positionX, "\(label) positionX"),
            (textLayer.positionY, "\(label) positionY"),
            (textLayer.fontSize, "\(label) fontSize"),
            (textLayer.scale, "\(label) scale"),
            (textLayer.rotationDegrees, "\(label) rotationDegrees")
        ]
        for (value, valueLabel) in finiteValues where !value.isFinite {
            throw PrimoDocumentError.contractViolation("Document contract failed: \(valueLabel) must be finite.")
        }
        guard textLayer.fontSize > 0 else {
            throw PrimoDocumentError.contractViolation("Document contract failed: \(label) fontSize must be positive.")
        }
        guard textLayer.scale > 0 else {
            throw PrimoDocumentError.contractViolation("Document contract failed: \(label) scale must be positive.")
        }
        try validateUnitInterval(textLayer.red, label: "\(label) red")
        try validateUnitInterval(textLayer.green, label: "\(label) green")
        try validateUnitInterval(textLayer.blue, label: "\(label) blue")
        try validateUnitInterval(textLayer.alpha, label: "\(label) alpha")

        let horizontalRange = Double(-canvasWidth)...Double(canvasWidth * 2)
        let verticalRange = Double(-canvasHeight)...Double(canvasHeight * 2)
        guard horizontalRange.contains(textLayer.positionX), verticalRange.contains(textLayer.positionY) else {
            throw PrimoDocumentError.contractViolation(
                "Document contract failed: \(label) position is implausibly far outside the canvas."
            )
        }
    }

    private static func validatePaperStyle(
        _ paperStyle: StoredPrimoDocument.PaperStyle,
        label: String
    ) throws {
        try validateUnitInterval(paperStyle.red, label: "\(label) red")
        try validateUnitInterval(paperStyle.green, label: "\(label) green")
        try validateUnitInterval(paperStyle.blue, label: "\(label) blue")
        try validateUnitInterval(paperStyle.alpha, label: "\(label) alpha")
    }

    private static func validateUnitInterval(_ value: Double, label: String) throws {
        guard value.isFinite, (0...1).contains(value) else {
            throw PrimoDocumentError.contractViolation("Document contract failed: \(label) must be in 0...1.")
        }
    }

    private static func validateRelativePath(
        _ path: String,
        requiredPrefix: String,
        label: String
    ) throws {
        let components = path.split(separator: "/")
        guard
            !path.isEmpty,
            !path.hasPrefix("/"),
            path.hasPrefix(requiredPrefix),
            !components.contains("..")
        else {
            throw PrimoDocumentError.contractViolation("Document contract failed: \(label) is invalid.")
        }
    }
}

private struct PaintDocumentRestorePlan {
    struct LayerPayload {
        let index: Int
        let name: String
        let visible: Bool
        let locked: Bool
        let alphaLocked: Bool
        let clipped: Bool
        let opacity: Double
        let blendMode: String
        let folderID: DocumentFolderID?
        let textLayer: TextLayerData?
        let pixelData: Data
        let maskData: Data?
    }

    struct FolderPayload {
        let id: DocumentFolderID
        let name: String
        let visible: Bool
        let expanded: Bool
        let anchorLayerIndex: Int?
    }

    struct TimelapseFramePayload {
        let sourceURL: URL
        let size: CGSize
    }

    enum TimelapsePayload {
        case operations([TimelapseOperation])
        case frames([TimelapseFramePayload])
    }

    let paperStyle: CanvasPaperStyle
    let layers: [LayerPayload]
    let folders: [FolderPayload]
    let activeLayerIndex: Int
    let timelapse: TimelapsePayload

    init(
        document: StoredPrimoDocument,
        contract: PaintDocumentPersistenceContract,
        baseURL: URL,
        services: PaintDocumentSessionServices,
        fileClient: FileClient
    ) throws {
        paperStyle = CanvasPaperStyle(
            red: Float(document.paperStyle.red),
            green: Float(document.paperStyle.green),
            blue: Float(document.paperStyle.blue),
            alpha: Float(document.paperStyle.alpha),
            isTransparent: document.paperStyle.isTransparent
        )

        layers = try document.layers.sorted(by: { $0.index < $1.index }).map { layer in
            let pixelURL = baseURL.appendingPathComponent(layer.pixelFilename, isDirectory: false)
            let pixelData = try services.persistence.loadData(from: pixelURL)
            guard pixelData.count == contract.pixelByteCount else {
                throw PrimoDocumentError.contractViolation(
                    "Document contract failed: layer \(layer.index.rawValue) pixel payload has unexpected size."
                )
            }

            let maskData = try layer.maskFilename.map { maskFilename -> Data in
                let data = try services.persistence.loadData(from: baseURL.appendingPathComponent(maskFilename, isDirectory: false))
                guard data.count == contract.maskByteCount else {
                    throw PrimoDocumentError.contractViolation(
                        "Document contract failed: layer \(layer.index.rawValue) mask payload has unexpected size."
                    )
                }
                return data
            }

            return LayerPayload(
                index: layer.index.rawValue,
                name: layer.name,
                visible: layer.visible,
                locked: layer.locked,
                alphaLocked: layer.alphaLocked,
                clipped: layer.clipped,
                opacity: layer.opacity,
                blendMode: layer.blendMode,
                folderID: layer.folderID,
                textLayer: layer.textLayer,
                pixelData: pixelData,
                maskData: maskData
            )
        }

        folders = document.folders.map { folder in
            FolderPayload(
                id: folder.id,
                name: folder.name,
                visible: folder.visible,
                expanded: folder.expanded,
                anchorLayerIndex: folder.anchorLayerIndex?.rawValue
            )
        }

        activeLayerIndex = document.activeLayerIndex.rawValue

        if !document.timelapseOperations.isEmpty {
            timelapse = .operations(
                try document.timelapseOperations.map {
                    try TimelapseOperation(stored: $0, baseURL: baseURL, fileClient: fileClient)
                }
            )
        } else {
            timelapse = .frames(
                document.timelapseFrames.map { frame in
                    TimelapseFramePayload(
                        sourceURL: baseURL.appendingPathComponent(frame.filename, isDirectory: false),
                        size: CGSize(width: frame.width, height: frame.height)
                    )
                }
            )
        }
    }
}
