import CoreGraphics
import Foundation
import UIKit

extension PaintDocumentSession {
    func compositePNGData(paperStyle: CanvasPaperStyle) -> Data? {
        self.paperStyle = paperStyle
        return renderedCompositeImage(paperStyle: paperStyle)?.pngData()
    }

    func saveProject(to url: URL) throws {
        try persistenceService.prepareProjectDirectory(at: url)
        let directories = try persistenceService.createProjectSubdirectories(
            in: url,
            usesOperationTimelapsePersistence: usesOperationTimelapsePersistence
        )
        let layersDirectory = directories.layersDirectory
        let timelapseDirectory = directories.timelapseDirectory
        let timelapseDataDirectory = directories.timelapseDataDirectory

        let layerInfos = bridge.layerInfos()
        let folderInfos = bridge.folderInfos()

        let storedLayers = try layerInfos.enumerated().map { index, layerInfo -> StoredPrimoDocument.Layer in
            let filename = String(format: "layer-%04d.rgba", index)
            let pixelURL = layersDirectory.appendingPathComponent(filename, isDirectory: false)
            let pixelData = bridge.pixelDataForLayer(at: index) as Data
            try persistenceService.writeAtomic(pixelData, to: pixelURL)
            let maskFilename: String?
            if let maskData = bridge.layerMaskDataForLayer(at: index) {
                let filename = String(format: "layer-mask-%04d.mask", index)
                try persistenceService.writeAtomic(maskData, to: layersDirectory.appendingPathComponent(filename, isDirectory: false))
                maskFilename = "Layers/\(filename)"
            } else {
                maskFilename = nil
            }
            return StoredPrimoDocument.Layer(
                index: index,
                name: layerInfo.name,
                visible: layerInfo.visible,
                locked: layerInfo.locked,
                alphaLocked: layerInfo.alphaLocked,
                clipped: layerInfo.clipped,
                opacity: layerInfo.opacity,
                blendMode: layerInfo.blendMode,
                folderID: layerInfo.folderID >= 0 ? Int(layerInfo.folderID) : nil,
                textLayer: textLayers[index],
                pixelFilename: "Layers/\(filename)",
                maskFilename: maskFilename
            )
        }

        let storedFolders = folderInfos.map { folderInfo in
            StoredPrimoDocument.Folder(
                id: Int(folderInfo.folderID),
                name: folderInfo.name,
                visible: folderInfo.visible,
                expanded: folderInfo.expanded,
                anchorLayerIndex: folderInfo.anchorLayerIndex >= 0 ? Int(folderInfo.anchorLayerIndex) : nil
            )
        }

        let storedTimelapseFrames: [StoredPrimoDocument.TimelapseFrame]
        if !usesOperationTimelapsePersistence {
            storedTimelapseFrames = try timelapseFrames.enumerated().map { index, frame in
                let filename = String(format: "frame-%06d.jpg", index)
                let destinationURL = timelapseDirectory.appendingPathComponent(filename, isDirectory: false)
                try persistenceService.replaceItemIfNeeded(at: destinationURL, with: frame.imageURL)
                return StoredPrimoDocument.TimelapseFrame(
                    filename: "Timelapse/\(filename)",
                    width: Double(frame.size.width),
                    height: Double(frame.size.height)
                )
            }
        } else {
            storedTimelapseFrames = []
        }

        let storedTimelapseOperations = usesOperationTimelapsePersistence
            ? try timelapseEvents.enumerated().map { index, event in
                try event.storedRepresentation(index: index, dataDirectory: timelapseDataDirectory, fileClient: fileClient)
            }
            : []

        let document = StoredPrimoDocument(
            version: 5,
            canvasWidth: Int(bridge.width),
            canvasHeight: Int(bridge.height),
            activeLayerIndex: Int(bridge.activeLayerIndex),
            paperStyle: StoredPrimoDocument.PaperStyle(
                red: Double(paperStyle.red),
                green: Double(paperStyle.green),
                blue: Double(paperStyle.blue),
                alpha: Double(paperStyle.alpha),
                isTransparent: paperStyle.isTransparent
            ),
            layers: storedLayers,
            folders: storedFolders,
            timelapseFrames: storedTimelapseFrames,
            timelapseOperations: storedTimelapseOperations
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(document)
        try persistenceService.writeAtomic(manifestData, to: url.appendingPathComponent("manifest.json"))
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
        guard !document.layers.isEmpty else {
            throw PrimoDocumentError.invalidDocument
        }

        let session = PaintDocumentSession(
            width: document.canvasWidth,
            height: document.canvasHeight,
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
        session.paperStyle = CanvasPaperStyle(
            red: Float(document.paperStyle.red),
            green: Float(document.paperStyle.green),
            blue: Float(document.paperStyle.blue),
            alpha: Float(document.paperStyle.alpha),
            isTransparent: document.paperStyle.isTransparent
        )

        while Int(session.bridge.layerInfos().count) < document.layers.count {
            _ = session.bridge.addLayer(name: "Layer \(Int(session.bridge.layerInfos().count) + 1)")
        }

        for layer in document.layers.sorted(by: { $0.index < $1.index }) {
            let pixelURL = url.appendingPathComponent(layer.pixelFilename, isDirectory: false)
            let pixelData = try services.persistence.loadData(from: pixelURL)
            session.bridge.replaceLayerPixelsTransient(at: layer.index, data: pixelData)
            if let maskFilename = layer.maskFilename {
                let maskData = try services.persistence.loadData(from: url.appendingPathComponent(maskFilename, isDirectory: false))
                session.bridge.replaceLayerMask(at: layer.index, data: maskData)
            } else {
                session.bridge.clearLayerMask(at: layer.index)
            }
            session.bridge.setLayerName(layer.name, at: layer.index)
            session.bridge.setLayerVisible(layer.visible, at: layer.index)
            session.bridge.setLayerLocked(layer.locked, at: layer.index)
            session.bridge.setLayerAlphaLocked(layer.alphaLocked, at: layer.index)
            session.bridge.setLayerClipped(layer.clipped, at: layer.index)
            session.bridge.setLayerOpacity(CGFloat(layer.opacity), at: layer.index)
            session.bridge.setLayerBlendMode(layer.blendMode, at: layer.index)
            if let textLayer = layer.textLayer {
                session.textLayers[layer.index] = textLayer
            }
        }

        var folderIDMap: [Int: Int] = [:]
        for folder in document.folders {
            let newFolderID = Int(session.bridge.createFolder(name: folder.name, layerIndex: folder.anchorLayerIndex ?? -1))
            folderIDMap[folder.id] = newFolderID
            session.bridge.setFolderVisible(folder.visible, folderID: newFolderID)
            session.bridge.setFolderExpanded(folder.expanded, folderID: newFolderID)
        }

        for layer in document.layers {
            guard let storedFolderID = layer.folderID, let resolvedFolderID = folderIDMap[storedFolderID] else { continue }
            _ = session.bridge.setLayerFolder(at: layer.index, folderID: resolvedFolderID)
        }

        session.bridge.activeLayerIndex = min(max(document.activeLayerIndex, 0), document.layers.count - 1)

        session.timelapseFrames.removeAll(keepingCapacity: true)
        session.timelapseEvents.removeAll(keepingCapacity: true)
        if !document.timelapseOperations.isEmpty {
            session.usesOperationTimelapsePersistence = true
            session.timelapseEvents = try document.timelapseOperations.map {
                try TimelapseOperation(stored: $0, baseURL: url, fileClient: fileClient)
            }
        } else {
            session.usesOperationTimelapsePersistence = false
            for (index, storedFrame) in document.timelapseFrames.enumerated() {
                let sourceURL = url.appendingPathComponent(storedFrame.filename, isDirectory: false)
                let destinationURL = session.timelapseService.makeFrameURL(in: session.timelapseDirectoryURL, frameID: index)
                try services.persistence.replaceItemIfNeeded(at: destinationURL, with: sourceURL)
                session.timelapseFrames.append(
                    TimelapseFrame(
                        imageURL: destinationURL,
                        size: CGSize(width: storedFrame.width, height: storedFrame.height)
                    )
                )
            }
        }
        session.nextTimelapseFrameID = session.timelapseFrames.count
        session.layerThumbnailCache.removeAll(keepingCapacity: true)
        session.bridge.clearHistory()
        return session
    }
}
