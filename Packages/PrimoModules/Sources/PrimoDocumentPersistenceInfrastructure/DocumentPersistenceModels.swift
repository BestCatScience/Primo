import Foundation
import PrimoDocumentPersistenceContracts
import PrimoDocumentDomain

public struct StoredPrimoDocument: Codable {
    public struct PaperStyle: Codable, Equatable, Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double
        public let alpha: Double
        public let isTransparent: Bool

        public init(red: Double, green: Double, blue: Double, alpha: Double, isTransparent: Bool) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
            self.isTransparent = isTransparent
        }
    }

    public struct Layer: Codable {
        public let index: DocumentLayerIndex
        public let name: String
        public let visible: Bool
        public let locked: Bool
        public let alphaLocked: Bool
        public let clipped: Bool
        public let opacity: Double
        public let blendMode: String
        public let folderID: DocumentFolderID?
        public let textLayer: TextLayerData?
        public let pixelFilename: String
        public let maskFilename: String?

        enum CodingKeys: String, CodingKey {
            case index
            case name
            case visible
            case locked
            case alphaLocked
            case clipped
            case opacity
            case blendMode
            case folderID
            case textLayer
            case pixelFilename
            case maskFilename
        }

        public init(
            index: DocumentLayerIndex,
            name: String,
            visible: Bool,
            locked: Bool,
            alphaLocked: Bool,
            clipped: Bool,
            opacity: Double,
            blendMode: String,
            folderID: DocumentFolderID?,
            textLayer: TextLayerData?,
            pixelFilename: String,
            maskFilename: String?
        ) {
            self.index = index
            self.name = name
            self.visible = visible
            self.locked = locked
            self.alphaLocked = alphaLocked
            self.clipped = clipped
            self.opacity = opacity
            self.blendMode = blendMode
            self.folderID = folderID
            self.textLayer = textLayer
            self.pixelFilename = pixelFilename
            self.maskFilename = maskFilename
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            index = try container.decode(DocumentLayerIndex.self, forKey: .index)
            name = try container.decode(String.self, forKey: .name)
            visible = try container.decode(Bool.self, forKey: .visible)
            locked = try container.decodeIfPresent(Bool.self, forKey: .locked) ?? false
            alphaLocked = try container.decodeIfPresent(Bool.self, forKey: .alphaLocked) ?? false
            clipped = try container.decodeIfPresent(Bool.self, forKey: .clipped) ?? false
            opacity = try container.decode(Double.self, forKey: .opacity)
            blendMode = try container.decode(String.self, forKey: .blendMode)
            folderID = try container.decodeIfPresent(DocumentFolderID.self, forKey: .folderID)
            textLayer = try container.decodeIfPresent(TextLayerData.self, forKey: .textLayer)
            pixelFilename = try container.decode(String.self, forKey: .pixelFilename)
            maskFilename = try container.decodeIfPresent(String.self, forKey: .maskFilename)
        }
    }

    public struct Folder: Codable {
        public let id: DocumentFolderID
        public let name: String
        public let visible: Bool
        public let expanded: Bool
        public let anchorLayerIndex: DocumentLayerIndex?

        public init(id: DocumentFolderID, name: String, visible: Bool, expanded: Bool, anchorLayerIndex: DocumentLayerIndex?) {
            self.id = id
            self.name = name
            self.visible = visible
            self.expanded = expanded
            self.anchorLayerIndex = anchorLayerIndex
        }
    }

    public struct TimelapseFrame: Codable {
        public let filename: String
        public let width: Double
        public let height: Double

        public init(filename: String, width: Double, height: Double) {
            self.filename = filename
            self.width = width
            self.height = height
        }
    }

    public let version: Int
    public let canvasWidth: Int
    public let canvasHeight: Int
    public let activeLayerIndex: DocumentLayerIndex
    public let paperStyle: PaperStyle
    public let layers: [Layer]
    public let folders: [Folder]
    public let timelapseFrames: [TimelapseFrame]
    public let timelapseOperations: [StoredTimelapseOperation]

    enum CodingKeys: String, CodingKey {
        case version
        case canvasWidth
        case canvasHeight
        case activeLayerIndex
        case paperStyle
        case layers
        case folders
        case timelapseFrames
        case timelapseOperations
    }

    public init(
        version: Int,
        canvasWidth: Int,
        canvasHeight: Int,
        activeLayerIndex: DocumentLayerIndex,
        paperStyle: PaperStyle,
        layers: [Layer],
        folders: [Folder],
        timelapseFrames: [TimelapseFrame],
        timelapseOperations: [StoredTimelapseOperation]
    ) {
        self.version = version
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.activeLayerIndex = activeLayerIndex
        self.paperStyle = paperStyle
        self.layers = layers
        self.folders = folders
        self.timelapseFrames = timelapseFrames
        self.timelapseOperations = timelapseOperations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        canvasWidth = try container.decode(Int.self, forKey: .canvasWidth)
        canvasHeight = try container.decode(Int.self, forKey: .canvasHeight)
        activeLayerIndex = try container.decode(DocumentLayerIndex.self, forKey: .activeLayerIndex)
        paperStyle = try container.decode(PaperStyle.self, forKey: .paperStyle)
        layers = try container.decode([Layer].self, forKey: .layers)
        folders = try container.decodeIfPresent([Folder].self, forKey: .folders) ?? []
        timelapseFrames = try container.decodeIfPresent([TimelapseFrame].self, forKey: .timelapseFrames) ?? []
        timelapseOperations = try container.decodeIfPresent([StoredTimelapseOperation].self, forKey: .timelapseOperations) ?? []
    }
}
