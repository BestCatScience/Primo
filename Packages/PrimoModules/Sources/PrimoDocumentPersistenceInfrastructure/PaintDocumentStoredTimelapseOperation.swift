import Foundation
import PrimoDocumentPersistenceContracts
import PrimoDocumentDomain

public struct StoredTimelapseOperation: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case stroke
        case blurStroke
        case fill
        case undo
        case redo
        case addLayer
        case duplicateLayer
        case deleteLayer
        case moveLayer
        case createFolder
        case deleteFolder
        case setFolderVisibility
        case setFolderName
        case setFolderExpanded
        case assignLayerToFolder
        case setLayerName
        case setLayerVisibility
        case setLayerLocked
        case setLayerAlphaLocked
        case setLayerClipped
        case setLayerOpacity
        case setLayerBlendMode
        case replaceLayerPixels
        case replaceLayerMask
        case clearLayerMask
        case applyLayerMask
        case clearLayer
        case setPaperStyle
    }

    public let kind: Kind
    public var layerIndex: DocumentLayerIndex?
    public var destinationIndex: DocumentLayerIndex?
    public var folderID: DocumentFolderID?
    public var anchorLayerIndex: DocumentLayerIndex?
    public var name: String?
    public var isVisible: Bool?
    public var isExpanded: Bool?
    public var isLocked: Bool?
    public var isAlphaLocked: Bool?
    public var isClipped: Bool?
    public var opacity: Double?
    public var blendMode: String?
    public var brush: StoredBrushRuntimeSettings?
    public var samples: [StoredStylusSample]?
    public var sample: StoredStylusSample?
    public var dataFilename: String?
    public var paperStyle: StoredPrimoDocument.PaperStyle?

    public init(
        kind: Kind,
        layerIndex: DocumentLayerIndex? = nil,
        destinationIndex: DocumentLayerIndex? = nil,
        folderID: DocumentFolderID? = nil,
        anchorLayerIndex: DocumentLayerIndex? = nil,
        name: String? = nil,
        isVisible: Bool? = nil,
        isExpanded: Bool? = nil,
        isLocked: Bool? = nil,
        isAlphaLocked: Bool? = nil,
        isClipped: Bool? = nil,
        opacity: Double? = nil,
        blendMode: String? = nil,
        brush: StoredBrushRuntimeSettings? = nil,
        samples: [StoredStylusSample]? = nil,
        sample: StoredStylusSample? = nil,
        dataFilename: String? = nil,
        paperStyle: StoredPrimoDocument.PaperStyle? = nil
    ) {
        self.kind = kind
        self.layerIndex = layerIndex
        self.destinationIndex = destinationIndex
        self.folderID = folderID
        self.anchorLayerIndex = anchorLayerIndex
        self.name = name
        self.isVisible = isVisible
        self.isExpanded = isExpanded
        self.isLocked = isLocked
        self.isAlphaLocked = isAlphaLocked
        self.isClipped = isClipped
        self.opacity = opacity
        self.blendMode = blendMode
        self.brush = brush
        self.samples = samples
        self.sample = sample
        self.dataFilename = dataFilename
        self.paperStyle = paperStyle
    }
}
