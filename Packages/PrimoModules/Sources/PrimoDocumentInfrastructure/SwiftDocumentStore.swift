import Foundation
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentDomain

public struct SwiftDocumentLayerRecord: Equatable, Sendable {
    public var name: String
    public var visible: Bool
    public var locked: Bool
    public var alphaLocked: Bool
    public var clipped: Bool
    public var opacity: Double
    public var blendMode: LayerBlendMode
    public var folderID: Int?
    public var textLayer: TextLayerData?
    public var pixelData: Data
    public var maskData: Data?

    public init(
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

public struct SwiftDocumentFolderRecord: Equatable, Sendable {
    public var id: Int
    public var name: String
    public var visible: Bool
    public var expanded: Bool
    public var anchorLayerIndex: Int?

    public init(
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

public struct SwiftDocumentStoreSnapshot: Equatable, Sendable {
    public var canvasWidth: Int
    public var canvasHeight: Int
    public var activeLayerIndex: Int
    public var paperStyle: CanvasPaperStyle
    public var revision: Int
    public var nextFolderID: Int
    public var layers: [SwiftDocumentLayerRecord]
    public var folders: [SwiftDocumentFolderRecord]
    public var thumbnailCache: [Int: Data]
    public var timelapseFrames: [TimelapseFrame]
    public var timelapseEvents: [TimelapseOperation]
    public var timelapseUsesOperationPersistence: Bool

    public init(
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

public struct DocumentRectSnapshot: Equatable, Sendable {
    public var layerIndex: Int
    public var rect: LayerPixelRect
    public var pixelData: Data

    public init(layerIndex: Int, rect: LayerPixelRect, pixelData: Data) {
        self.layerIndex = layerIndex
        self.rect = rect
        self.pixelData = pixelData
    }
}

public struct DocumentCommandRecord: Equatable, Sendable {
    public var before: SwiftDocumentStoreSnapshot
    public var after: SwiftDocumentStoreSnapshot
    public var timelapseEvent: TimelapseOperation?

    public init(
        before: SwiftDocumentStoreSnapshot,
        after: SwiftDocumentStoreSnapshot,
        timelapseEvent: TimelapseOperation? = nil
    ) {
        self.before = before
        self.after = after
        self.timelapseEvent = timelapseEvent
    }
}

public final class SwiftDocumentStore: @unchecked Sendable {
    public var snapshot: SwiftDocumentStoreSnapshot

    public init(
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

    public func restore(_ snapshot: SwiftDocumentStoreSnapshot) {
        self.snapshot = snapshot
    }
}
