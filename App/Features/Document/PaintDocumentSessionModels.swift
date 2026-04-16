import Foundation

struct StoredPrimoDocument: Codable {
    struct PaperStyle: Codable, Equatable, Sendable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
        let isTransparent: Bool
    }

    struct Layer: Codable {
        let index: Int
        let name: String
        let visible: Bool
        let locked: Bool
        let alphaLocked: Bool
        let clipped: Bool
        let opacity: Double
        let blendMode: String
        let folderID: Int?
        let textLayer: TextLayerData?
        let pixelFilename: String
        let maskFilename: String?

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

        init(
            index: Int,
            name: String,
            visible: Bool,
            locked: Bool,
            alphaLocked: Bool,
            clipped: Bool,
            opacity: Double,
            blendMode: String,
            folderID: Int?,
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

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            index = try container.decode(Int.self, forKey: .index)
            name = try container.decode(String.self, forKey: .name)
            visible = try container.decode(Bool.self, forKey: .visible)
            locked = try container.decodeIfPresent(Bool.self, forKey: .locked) ?? false
            alphaLocked = try container.decodeIfPresent(Bool.self, forKey: .alphaLocked) ?? false
            clipped = try container.decodeIfPresent(Bool.self, forKey: .clipped) ?? false
            opacity = try container.decode(Double.self, forKey: .opacity)
            blendMode = try container.decode(String.self, forKey: .blendMode)
            folderID = try container.decodeIfPresent(Int.self, forKey: .folderID)
            textLayer = try container.decodeIfPresent(TextLayerData.self, forKey: .textLayer)
            pixelFilename = try container.decode(String.self, forKey: .pixelFilename)
            maskFilename = try container.decodeIfPresent(String.self, forKey: .maskFilename)
        }
    }

    struct Folder: Codable {
        let id: Int
        let name: String
        let visible: Bool
        let expanded: Bool
        let anchorLayerIndex: Int?
    }

    struct TimelapseFrame: Codable {
        let filename: String
        let width: Double
        let height: Double
    }

    let version: Int
    let canvasWidth: Int
    let canvasHeight: Int
    let activeLayerIndex: Int
    let paperStyle: PaperStyle
    let layers: [Layer]
    let folders: [Folder]
    let timelapseFrames: [TimelapseFrame]
    let timelapseOperations: [StoredTimelapseOperation]

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

    init(
        version: Int,
        canvasWidth: Int,
        canvasHeight: Int,
        activeLayerIndex: Int,
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        canvasWidth = try container.decode(Int.self, forKey: .canvasWidth)
        canvasHeight = try container.decode(Int.self, forKey: .canvasHeight)
        activeLayerIndex = try container.decode(Int.self, forKey: .activeLayerIndex)
        paperStyle = try container.decode(PaperStyle.self, forKey: .paperStyle)
        layers = try container.decode([Layer].self, forKey: .layers)
        folders = try container.decodeIfPresent([Folder].self, forKey: .folders) ?? []
        timelapseFrames = try container.decodeIfPresent([TimelapseFrame].self, forKey: .timelapseFrames) ?? []
        timelapseOperations = try container.decodeIfPresent([StoredTimelapseOperation].self, forKey: .timelapseOperations) ?? []
    }
}
