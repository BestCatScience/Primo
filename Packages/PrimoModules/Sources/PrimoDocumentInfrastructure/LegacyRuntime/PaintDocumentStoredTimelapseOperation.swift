import Foundation

struct StoredTimelapseOperation: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Equatable, Sendable {
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
        case assignLayerToFolder
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

    let kind: Kind
    var layerIndex: DocumentLayerIndex?
    var destinationIndex: DocumentLayerIndex?
    var folderID: DocumentFolderID?
    var anchorLayerIndex: DocumentLayerIndex?
    var name: String?
    var isVisible: Bool?
    var isLocked: Bool?
    var isAlphaLocked: Bool?
    var isClipped: Bool?
    var opacity: Double?
    var blendMode: String?
    var brush: StoredBrushRuntimeSettings?
    var samples: [StoredStylusSample]?
    var sample: StoredStylusSample?
    var dataFilename: String?
    var paperStyle: StoredPrimoDocument.PaperStyle?

    init(
        kind: Kind,
        layerIndex: DocumentLayerIndex? = nil,
        destinationIndex: DocumentLayerIndex? = nil,
        folderID: DocumentFolderID? = nil,
        anchorLayerIndex: DocumentLayerIndex? = nil,
        name: String? = nil,
        isVisible: Bool? = nil,
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
