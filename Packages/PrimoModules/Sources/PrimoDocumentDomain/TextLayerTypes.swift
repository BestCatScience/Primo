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
    public var textContent: TextContent
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

    public var text: String {
        get { textContent.rawValue }
        set {
            guard let content = TextContent(newValue) else { return }
            textContent = content
        }
    }

    public var position: CGPoint {
        get { CGPoint(x: positionX, y: positionY) }
        set {
            positionX = newValue.x
            positionY = newValue.y
        }
    }

    package init(
        unsafeUncheckedText text: String,
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
        self.textContent = TextContent(text)!
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

    public init?(
        validatingText text: String,
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
        guard let text = TextContent(text),
              let positionX = FiniteDouble(positionX),
              let positionY = FiniteDouble(positionY),
              let fontSize = PositiveFiniteDouble(fontSize),
              let scale = PositiveFiniteDouble(scale),
              let rotationDegrees = FiniteDouble(rotationDegrees),
              let color = CanvasColor(red: red, green: green, blue: blue, alpha: alpha) else {
            return nil
        }
        self.init(
            text: text,
            positionX: positionX,
            positionY: positionY,
            fontPostScriptName: fontPostScriptName,
            fontDisplayName: fontDisplayName,
            fontSize: fontSize,
            scale: scale,
            rotationDegrees: rotationDegrees,
            color: color
        )
    }

    public init?(
        text: TextContent,
        positionX: FiniteDouble,
        positionY: FiniteDouble,
        fontPostScriptName: String,
        fontDisplayName: String,
        fontSize: PositiveFiniteDouble,
        scale: PositiveFiniteDouble = PositiveFiniteDouble(1.0)!,
        rotationDegrees: FiniteDouble = FiniteDouble(0)!,
        color: CanvasColor
    ) {
        self.init(
            unsafeUncheckedText: text.rawValue,
            positionX: positionX.rawValue,
            positionY: positionY.rawValue,
            fontPostScriptName: fontPostScriptName,
            fontDisplayName: fontDisplayName,
            fontSize: fontSize.rawValue,
            scale: scale.rawValue,
            rotationDegrees: rotationDegrees.rawValue,
            red: color.red.rawValue,
            green: color.green.rawValue,
            blue: color.blue.rawValue,
            alpha: color.alpha.rawValue
        )
    }

    public var validatedPositionX: FiniteDouble? { FiniteDouble(positionX) }
    public var validatedPositionY: FiniteDouble? { FiniteDouble(positionY) }
    public var validatedFontSize: PositiveFiniteDouble? { PositiveFiniteDouble(fontSize) }
    public var validatedScale: PositiveFiniteDouble? { PositiveFiniteDouble(scale) }
    public var validatedRotationDegrees: FiniteDouble? { FiniteDouble(rotationDegrees) }
    public var validatedColor: CanvasColor? {
        CanvasColor(red: red, green: green, blue: blue, alpha: alpha)
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
        let decodedText = try container.decode(String.self, forKey: .text)
        guard let textContent = TextContent(decodedText) else {
            throw DecodingError.dataCorruptedError(
                forKey: .text,
                in: container,
                debugDescription: "Text layer content exceeds \(TextContent.maxLength) characters"
            )
        }
        self.textContent = textContent
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(textContent.rawValue, forKey: .text)
        try container.encode(positionX, forKey: .positionX)
        try container.encode(positionY, forKey: .positionY)
        try container.encode(fontPostScriptName, forKey: .fontPostScriptName)
        try container.encode(fontDisplayName, forKey: .fontDisplayName)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(scale, forKey: .scale)
        try container.encode(rotationDegrees, forKey: .rotationDegrees)
        try container.encode(red, forKey: .red)
        try container.encode(green, forKey: .green)
        try container.encode(blue, forKey: .blue)
        try container.encode(alpha, forKey: .alpha)
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
