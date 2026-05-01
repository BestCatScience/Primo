import Foundation
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentDomain

struct SwiftDocumentLayerRecord: Equatable, Sendable {
    var name: String
    var visible: Bool
    var locked: Bool
    var alphaLocked: Bool
    var clipped: Bool
    var opacity: Double
    var blendMode: LayerBlendMode
    var folderID: Int?
    var textLayer: TextLayerData?
    var pixelData: Data
    var maskData: Data?

    init(
        name: String,
        visible: Bool,
        locked: Bool,
        alphaLocked: Bool,
        clipped: Bool,
        opacity: Double,
        blendMode: LayerBlendMode,
        folderID: Int?,
        textLayer: TextLayerData?,
        pixelData: Data,
        maskData: Data?
    ) {
        self.name = name
        self.visible = visible
        self.locked = locked
        self.alphaLocked = alphaLocked
        self.clipped = clipped
        self.opacity = opacity
        self.blendMode = blendMode
        self.folderID = folderID
        self.textLayer = textLayer
        self.pixelData = pixelData
        self.maskData = maskData
    }
}

struct SwiftDocumentFolderRecord: Equatable, Sendable {
    var id: Int
    var name: String
    var visible: Bool
    var expanded: Bool
    var anchorLayerIndex: Int?

    init(
        id: Int,
        name: String,
        visible: Bool,
        expanded: Bool,
        anchorLayerIndex: Int?
    ) {
        self.id = id
        self.name = name
        self.visible = visible
        self.expanded = expanded
        self.anchorLayerIndex = anchorLayerIndex
    }
}

struct SwiftDocumentStoreSnapshot: Equatable, Sendable {
    var canvasWidth: Int
    var canvasHeight: Int
    var activeLayerIndex: Int
    var paperStyle: CanvasPaperStyle
    var revision: Int
    var nextFolderID: Int
    var layers: [SwiftDocumentLayerRecord]
    var folders: [SwiftDocumentFolderRecord]
    var thumbnailCache: [Int: Data]
    var timelapseFrames: [TimelapseFrame]
    var timelapseEvents: [TimelapseOperation]
    var timelapseUsesOperationPersistence: Bool

    init(
        canvasWidth: Int,
        canvasHeight: Int,
        activeLayerIndex: Int,
        paperStyle: CanvasPaperStyle,
        revision: Int,
        nextFolderID: Int,
        layers: [SwiftDocumentLayerRecord],
        folders: [SwiftDocumentFolderRecord],
        thumbnailCache: [Int: Data],
        timelapseFrames: [TimelapseFrame],
        timelapseEvents: [TimelapseOperation],
        timelapseUsesOperationPersistence: Bool
    ) {
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.activeLayerIndex = activeLayerIndex
        self.paperStyle = paperStyle
        self.revision = revision
        self.nextFolderID = nextFolderID
        self.layers = layers
        self.folders = folders
        self.thumbnailCache = thumbnailCache
        self.timelapseFrames = timelapseFrames
        self.timelapseEvents = timelapseEvents
        self.timelapseUsesOperationPersistence = timelapseUsesOperationPersistence
    }
}

struct DocumentRectSnapshot: Equatable, Sendable {
    var layerIndex: Int
    var rect: LayerPixelRect
    var pixelData: Data

    init(layerIndex: Int, rect: LayerPixelRect, pixelData: Data) {
        self.layerIndex = layerIndex
        self.rect = rect
        self.pixelData = pixelData
    }
}

struct DocumentCommandRecord: Equatable, Sendable {
    var before: SwiftDocumentStoreSnapshot
    var after: SwiftDocumentStoreSnapshot
    var timelapseEvent: TimelapseOperation?

    init(
        before: SwiftDocumentStoreSnapshot,
        after: SwiftDocumentStoreSnapshot,
        timelapseEvent: TimelapseOperation? = nil
    ) {
        self.before = before
        self.after = after
        self.timelapseEvent = timelapseEvent
    }
}

final class SwiftDocumentStore: @unchecked Sendable {
    var snapshot: SwiftDocumentStoreSnapshot

    init(
        width: Int,
        height: Int,
        paperStyle: CanvasPaperStyle = .default
    ) {
        let clampedWidth = max(width, 1)
        let clampedHeight = max(height, 1)
        let pixelData = Data(count: clampedWidth * clampedHeight * 4)
        self.snapshot = SwiftDocumentStoreSnapshot(
            canvasWidth: clampedWidth,
            canvasHeight: clampedHeight,
            activeLayerIndex: 0,
            paperStyle: paperStyle,
            revision: 0,
            nextFolderID: 1,
            layers: [
                SwiftDocumentLayerRecord(
                    name: "Layer 1",
                    visible: true,
                    locked: false,
                    alphaLocked: false,
                    clipped: false,
                    opacity: 1.0,
                    blendMode: .normal,
                    folderID: nil,
                    textLayer: nil,
                    pixelData: pixelData,
                    maskData: nil
                )
            ],
            folders: [],
            thumbnailCache: [:],
            timelapseFrames: [],
            timelapseEvents: [],
            timelapseUsesOperationPersistence: true
        )
    }

    func restore(_ snapshot: SwiftDocumentStoreSnapshot) {
        self.snapshot = snapshot
    }
}
