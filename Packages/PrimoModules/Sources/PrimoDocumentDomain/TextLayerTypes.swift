import CoreGraphics
import Foundation

public struct TextFontOption: Identifiable, Equatable, Sendable, Codable {
    public let postScriptName: String
    public let displayName: String
    public let sourceFilename: String?

    public init(
        postScriptName: String,
        displayName: String,
        sourceFilename: String?
    ) {
        self.postScriptName = postScriptName
        self.displayName = displayName
        self.sourceFilename = sourceFilename
    }

    public var id: String { postScriptName }
}

public struct TextLayerData: Equatable, Sendable, Codable {
    public var text: String
    public var positionX: Double
    public var positionY: Double
    public var fontPostScriptName: String
    public var fontDisplayName: String
    public var fontSize: Double
    public var scale: Double
    public var rotationDegrees: Double
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public var position: CGPoint {
        get { CGPoint(x: positionX, y: positionY) }
        set {
            positionX = newValue.x
            positionY = newValue.y
        }
    }

    public init(
        text: String,
        positionX: Double,
        positionY: Double,
        fontPostScriptName: String,
        fontDisplayName: String,
        fontSize: Double,
        scale: Double = 1.0,
        rotationDegrees: Double = 0,
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double
    ) {
        self.text = text
        self.positionX = positionX
        self.positionY = positionY
        self.fontPostScriptName = fontPostScriptName
        self.fontDisplayName = fontDisplayName
        self.fontSize = fontSize
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    enum CodingKeys: String, CodingKey {
        case text
        case positionX
        case positionY
        case fontPostScriptName
        case fontDisplayName
        case fontSize
        case scale
        case rotationDegrees
        case red
        case green
        case blue
        case alpha
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        positionX = try container.decode(Double.self, forKey: .positionX)
        positionY = try container.decode(Double.self, forKey: .positionY)
        fontPostScriptName = try container.decode(String.self, forKey: .fontPostScriptName)
        fontDisplayName = try container.decode(String.self, forKey: .fontDisplayName)
        fontSize = try container.decode(Double.self, forKey: .fontSize)
        scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1.0
        rotationDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? 0
        red = try container.decode(Double.self, forKey: .red)
        green = try container.decode(Double.self, forKey: .green)
        blue = try container.decode(Double.self, forKey: .blue)
        alpha = try container.decode(Double.self, forKey: .alpha)
    }
}

public struct TextLayerDraft: Equatable, Sendable {
    public var targetLayerIndex: Int?
    public var text: String
    public var position: CGPoint?
    public var fontPostScriptName: String?
    public var fontDisplayName: String?
    public var fontSize: Double
    public var scale: Double
    public var rotationDegrees: Double

    public init(
        targetLayerIndex: Int?,
        text: String,
        position: CGPoint?,
        fontPostScriptName: String?,
        fontDisplayName: String?,
        fontSize: Double,
        scale: Double,
        rotationDegrees: Double
    ) {
        self.targetLayerIndex = targetLayerIndex
        self.text = text
        self.position = position
        self.fontPostScriptName = fontPostScriptName
        self.fontDisplayName = fontDisplayName
        self.fontSize = fontSize
        self.scale = scale
        self.rotationDegrees = rotationDegrees
    }
}
