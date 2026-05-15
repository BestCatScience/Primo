import Foundation
import PrimoCoreTypes
import PrimoDocumentPersistenceContracts
import PrimoDocumentDomain
import PrimoDocumentPersistenceInfrastructure
import PrimoSystemClients

extension TimelapseOperation {
    public func storedRepresentation(index: Int, dataDirectory: URL, fileClient: FileClient = .live) throws -> StoredTimelapseOperation {
        let dataFilename: String?
        switch self {
        case let .replaceLayerPixels(_, data):
            let filename = String(format: "replace-layer-%06d.rgba", index)
            try fileClient.writeData(data, dataDirectory.appendingPathComponent(filename, isDirectory: false), .atomic)
            dataFilename = "TimelapseData/\(filename)"
        case let .replaceLayerMask(_, data):
            let filename = String(format: "replace-mask-%06d.mask", index)
            try fileClient.writeData(data, dataDirectory.appendingPathComponent(filename, isDirectory: false), .atomic)
            dataFilename = "TimelapseData/\(filename)"
        default:
            dataFilename = nil
        }

        switch self {
        case let .stroke(layerIndex, brush, samples):
            return StoredTimelapseOperation(
                kind: .stroke,
                layerIndex: layerIndex,
                brush: StoredBrushRuntimeSettings(brush),
                samples: samples.map(StoredStylusSample.init),
                dataFilename: nil
            )
        case let .blurStroke(layerIndex, brush, samples):
            return StoredTimelapseOperation(
                kind: .blurStroke,
                layerIndex: layerIndex,
                brush: StoredBrushRuntimeSettings(brush),
                samples: samples.map(StoredStylusSample.init),
                dataFilename: nil
            )
        case let .fill(layerIndex, brush, sample):
            return StoredTimelapseOperation(
                kind: .fill,
                layerIndex: layerIndex,
                brush: StoredBrushRuntimeSettings(brush),
                sample: StoredStylusSample(sample),
                dataFilename: nil
            )
        case .undo:
            return StoredTimelapseOperation(kind: .undo)
        case .redo:
            return StoredTimelapseOperation(kind: .redo)
        case let .addLayer(name):
            return StoredTimelapseOperation(kind: .addLayer, name: name)
        case let .duplicateLayer(index, name):
            return StoredTimelapseOperation(kind: .duplicateLayer, layerIndex: index, name: name)
        case let .deleteLayer(index):
            return StoredTimelapseOperation(kind: .deleteLayer, layerIndex: index)
        case let .moveLayer(index, destinationIndex):
            return StoredTimelapseOperation(kind: .moveLayer, layerIndex: index, destinationIndex: destinationIndex)
        case let .mergeLayerDown(index):
            return StoredTimelapseOperation(kind: .mergeLayerDown, layerIndex: index)
        case let .createFolder(folderID, name, anchorLayerIndex):
            return StoredTimelapseOperation(
                kind: .createFolder,
                folderID: folderID,
                anchorLayerIndex: anchorLayerIndex,
                name: name
            )
        case let .deleteFolder(folderID):
            return StoredTimelapseOperation(kind: .deleteFolder, folderID: folderID)
        case let .setFolderVisibility(folderID, isVisible):
            return StoredTimelapseOperation(kind: .setFolderVisibility, folderID: folderID, isVisible: isVisible)
        case let .setFolderName(folderID, name):
            return StoredTimelapseOperation(kind: .setFolderName, folderID: folderID, name: name)
        case let .setFolderExpanded(folderID, isExpanded):
            return StoredTimelapseOperation(kind: .setFolderExpanded, folderID: folderID, isExpanded: isExpanded)
        case let .assignLayerToFolder(index, folderID):
            return StoredTimelapseOperation(kind: .assignLayerToFolder, layerIndex: index, folderID: folderID)
        case let .setLayerName(index, name):
            return StoredTimelapseOperation(kind: .setLayerName, layerIndex: index, name: name)
        case let .setLayerVisibility(index, isVisible):
            return StoredTimelapseOperation(kind: .setLayerVisibility, layerIndex: index, isVisible: isVisible)
        case let .setLayerLocked(index, isLocked):
            return StoredTimelapseOperation(kind: .setLayerLocked, layerIndex: index, isLocked: isLocked)
        case let .setLayerAlphaLocked(index, isAlphaLocked):
            return StoredTimelapseOperation(kind: .setLayerAlphaLocked, layerIndex: index, isAlphaLocked: isAlphaLocked)
        case let .setLayerClipped(index, isClipped):
            return StoredTimelapseOperation(kind: .setLayerClipped, layerIndex: index, isClipped: isClipped)
        case let .setLayerOpacity(index, opacity):
            return StoredTimelapseOperation(kind: .setLayerOpacity, layerIndex: index, opacity: opacity)
        case let .setLayerBlendMode(index, blendMode):
            return StoredTimelapseOperation(kind: .setLayerBlendMode, layerIndex: index, blendMode: blendMode.rawValue)
        case let .replaceLayerPixels(index, _):
            return StoredTimelapseOperation(kind: .replaceLayerPixels, layerIndex: index, dataFilename: dataFilename)
        case let .replaceLayerMask(index, _):
            return StoredTimelapseOperation(kind: .replaceLayerMask, layerIndex: index, dataFilename: dataFilename)
        case let .clearLayerMask(index):
            return StoredTimelapseOperation(kind: .clearLayerMask, layerIndex: index)
        case let .applyLayerMask(index):
            return StoredTimelapseOperation(kind: .applyLayerMask, layerIndex: index)
        case let .clearLayer(index):
            return StoredTimelapseOperation(kind: .clearLayer, layerIndex: index)
        case let .setPaperStyle(style):
            return StoredTimelapseOperation(kind: .setPaperStyle, paperStyle: StoredPrimoDocument.PaperStyle(
                red: Double(style.red),
                green: Double(style.green),
                blue: Double(style.blue),
                alpha: Double(style.alpha),
                isTransparent: style.isTransparent
            ))
        }
    }

    public init(
        stored: StoredTimelapseOperation,
        baseURL: URL,
        fileClient: FileClient = .live
    ) throws {
        switch stored.kind {
        case .stroke:
            guard let layerIndex = stored.layerIndex,
                  let brush = stored.brush?.runtimeSettings,
                  let samples = stored.samples?.map(\.stylusSample)
            else { throw PrimoDocumentError.invalidDocument }
            self = .stroke(layerIndex: layerIndex, brush: brush, samples: samples)
        case .blurStroke:
            guard let layerIndex = stored.layerIndex,
                  let brush = stored.brush?.runtimeSettings,
                  let samples = stored.samples?.map(\.stylusSample)
            else { throw PrimoDocumentError.invalidDocument }
            self = .blurStroke(layerIndex: layerIndex, brush: brush, samples: samples)
        case .fill:
            guard let layerIndex = stored.layerIndex,
                  let brush = stored.brush?.runtimeSettings,
                  let sample = stored.sample?.stylusSample
            else { throw PrimoDocumentError.invalidDocument }
            self = .fill(layerIndex: layerIndex, brush: brush, sample: sample)
        case .undo:
            self = .undo
        case .redo:
            self = .redo
        case .addLayer:
            guard let name = stored.name else { throw PrimoDocumentError.invalidDocument }
            self = .addLayer(name: name)
        case .duplicateLayer:
            guard let layerIndex = stored.layerIndex, let name = stored.name else { throw PrimoDocumentError.invalidDocument }
            self = .duplicateLayer(index: layerIndex, name: name)
        case .deleteLayer:
            guard let layerIndex = stored.layerIndex else { throw PrimoDocumentError.invalidDocument }
            self = .deleteLayer(index: layerIndex)
        case .moveLayer:
            guard let layerIndex = stored.layerIndex, let destinationIndex = stored.destinationIndex else {
                throw PrimoDocumentError.invalidDocument
            }
            self = .moveLayer(index: layerIndex, destinationIndex: destinationIndex)
        case .mergeLayerDown:
            guard let layerIndex = stored.layerIndex else { throw PrimoDocumentError.invalidDocument }
            self = .mergeLayerDown(index: layerIndex)
        case .createFolder:
            guard let folderID = stored.folderID, let name = stored.name else { throw PrimoDocumentError.invalidDocument }
            self = .createFolder(folderID: folderID, name: name, anchorLayerIndex: stored.anchorLayerIndex)
        case .deleteFolder:
            guard let folderID = stored.folderID else { throw PrimoDocumentError.invalidDocument }
            self = .deleteFolder(folderID: folderID)
        case .setFolderVisibility:
            guard let folderID = stored.folderID, let isVisible = stored.isVisible else { throw PrimoDocumentError.invalidDocument }
            self = .setFolderVisibility(folderID: folderID, isVisible: isVisible)
        case .setFolderName:
            guard let folderID = stored.folderID, let name = stored.name else { throw PrimoDocumentError.invalidDocument }
            self = .setFolderName(folderID: folderID, name: name)
        case .setFolderExpanded:
            guard let folderID = stored.folderID, let isExpanded = stored.isExpanded else { throw PrimoDocumentError.invalidDocument }
            self = .setFolderExpanded(folderID: folderID, isExpanded: isExpanded)
        case .assignLayerToFolder:
            guard let layerIndex = stored.layerIndex else { throw PrimoDocumentError.invalidDocument }
            self = .assignLayerToFolder(index: layerIndex, folderID: stored.folderID)
        case .setLayerName:
            guard let layerIndex = stored.layerIndex, let name = stored.name else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerName(index: layerIndex, name: name)
        case .setLayerVisibility:
            guard let layerIndex = stored.layerIndex, let isVisible = stored.isVisible else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerVisibility(index: layerIndex, isVisible: isVisible)
        case .setLayerLocked:
            guard let layerIndex = stored.layerIndex, let isLocked = stored.isLocked else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerLocked(index: layerIndex, isLocked: isLocked)
        case .setLayerAlphaLocked:
            guard let layerIndex = stored.layerIndex, let isAlphaLocked = stored.isAlphaLocked else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerAlphaLocked(index: layerIndex, isAlphaLocked: isAlphaLocked)
        case .setLayerClipped:
            guard let layerIndex = stored.layerIndex, let isClipped = stored.isClipped else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerClipped(index: layerIndex, isClipped: isClipped)
        case .setLayerOpacity:
            guard let layerIndex = stored.layerIndex, let opacity = stored.opacity else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerOpacity(index: layerIndex, opacity: opacity)
        case .setLayerBlendMode:
            guard let layerIndex = stored.layerIndex,
                  let blendModeRaw = stored.blendMode,
                  let blendMode = LayerBlendMode(rawValue: blendModeRaw)
            else { throw PrimoDocumentError.invalidDocument }
            self = .setLayerBlendMode(index: layerIndex, blendMode: blendMode)
        case .replaceLayerPixels:
            guard let layerIndex = stored.layerIndex, let dataFilename = stored.dataFilename else {
                throw PrimoDocumentError.invalidDocument
            }
            let data = try fileClient.readData(baseURL.appendingPathComponent(dataFilename, isDirectory: false))
            self = .replaceLayerPixels(index: layerIndex, data: data)
        case .replaceLayerMask:
            guard let layerIndex = stored.layerIndex, let dataFilename = stored.dataFilename else {
                throw PrimoDocumentError.invalidDocument
            }
            let data = try fileClient.readData(baseURL.appendingPathComponent(dataFilename, isDirectory: false))
            self = .replaceLayerMask(index: layerIndex, data: data)
        case .clearLayerMask:
            guard let layerIndex = stored.layerIndex else { throw PrimoDocumentError.invalidDocument }
            self = .clearLayerMask(index: layerIndex)
        case .applyLayerMask:
            guard let layerIndex = stored.layerIndex else { throw PrimoDocumentError.invalidDocument }
            self = .applyLayerMask(index: layerIndex)
        case .clearLayer:
            guard let layerIndex = stored.layerIndex else { throw PrimoDocumentError.invalidDocument }
            self = .clearLayer(index: layerIndex)
        case .setPaperStyle:
            guard let paperStyle = stored.paperStyle else { throw PrimoDocumentError.invalidDocument }
            guard let validatedPaperStyle = CanvasPaperStyle(
                validatingRed: Float(paperStyle.red),
                green: Float(paperStyle.green),
                blue: Float(paperStyle.blue),
                alpha: Float(paperStyle.alpha),
                isTransparent: paperStyle.isTransparent
            ) else {
                throw PrimoDocumentError.invalidDocument
            }
            self = .setPaperStyle(
                validatedPaperStyle
            )
        }
    }
}
