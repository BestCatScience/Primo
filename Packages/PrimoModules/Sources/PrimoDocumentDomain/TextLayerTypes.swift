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
    public let textContent: TextContent
    public let positionXValue: FiniteDouble
    public let positionYValue: FiniteDouble
    public let fontPostScriptName: String
    public let fontDisplayName: String
    public let fontSizeValue: PositiveFiniteDouble
    public let scaleValue: PositiveFiniteDouble
    public let rotationDegreesValue: FiniteDouble
    public let color: CanvasColor

    public var text: String {
        textContent.rawValue
    }

    public var positionX: Double { positionXValue.rawValue }
    public var positionY: Double { positionYValue.rawValue }
    public var fontSize: Double { fontSizeValue.rawValue }
    public var scale: Double { scaleValue.rawValue }
    public var rotationDegrees: Double { rotationDegreesValue.rawValue }
    public var red: Double { color.red.rawValue }
    public var green: Double { color.green.rawValue }
    public var blue: Double { color.blue.rawValue }
    public var alpha: Double { color.alpha.rawValue }

    public var position: CGPoint {
        get { CGPoint(x: positionX, y: positionY) }
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
        self.positionXValue = FiniteDouble(positionX)!
        self.positionYValue = FiniteDouble(positionY)!
        self.fontPostScriptName = fontPostScriptName
        self.fontDisplayName = fontDisplayName
        self.fontSizeValue = PositiveFiniteDouble(fontSize)!
        self.scaleValue = PositiveFiniteDouble(scale)!
        self.rotationDegreesValue = FiniteDouble(rotationDegrees)!
        self.color = CanvasColor(red: red, green: green, blue: blue, alpha: alpha)!
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

    public init(
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
        self.textContent = text
        self.positionXValue = positionX
        self.positionYValue = positionY
        self.fontPostScriptName = fontPostScriptName
        self.fontDisplayName = fontDisplayName
        self.fontSizeValue = fontSize
        self.scaleValue = scale
        self.rotationDegreesValue = rotationDegrees
        self.color = color
    }

    public var validatedPositionX: FiniteDouble? { positionXValue }
    public var validatedPositionY: FiniteDouble? { positionYValue }
    public var validatedFontSize: PositiveFiniteDouble? { fontSizeValue }
    public var validatedScale: PositiveFiniteDouble? { scaleValue }
    public var validatedRotationDegrees: FiniteDouble? { rotationDegreesValue }
    public var validatedColor: CanvasColor? { color }

    public func transformed(
        translation: CGSize,
        scaleFactor: PositiveFiniteDouble,
        rotationDeltaDegrees: FiniteDouble
    ) -> Self? {
        Self(
            validatingText: text,
            positionX: positionX + translation.width,
            positionY: positionY + translation.height,
            fontPostScriptName: fontPostScriptName,
            fontDisplayName: fontDisplayName,
            fontSize: fontSize,
            scale: min(max(scale * scaleFactor.rawValue, 0.2), 6.0),
            rotationDegrees: rotationDegrees + rotationDeltaDegrees.rawValue,
            red: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
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
        let positionX = try container.decode(Double.self, forKey: .positionX)
        let positionY = try container.decode(Double.self, forKey: .positionY)
        let fontPostScriptName = try container.decode(String.self, forKey: .fontPostScriptName)
        let fontDisplayName = try container.decode(String.self, forKey: .fontDisplayName)
        let fontSize = try container.decode(Double.self, forKey: .fontSize)
        let scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1.0
        let rotationDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? 0
        let red = try container.decode(Double.self, forKey: .red)
        let green = try container.decode(Double.self, forKey: .green)
        let blue = try container.decode(Double.self, forKey: .blue)
        let alpha = try container.decode(Double.self, forKey: .alpha)
        guard let decoded = Self(
            validatingText: textContent.rawValue,
            positionX: positionX,
            positionY: positionY,
            fontPostScriptName: fontPostScriptName,
            fontDisplayName: fontDisplayName,
            fontSize: fontSize,
            scale: scale,
            rotationDegrees: rotationDegrees,
            red: red,
            green: green,
            blue: blue,
            alpha: alpha
        ) else {
            throw DecodingError.dataCorruptedError(
                forKey: .text,
                in: container,
                debugDescription: "Invalid text layer attributes"
            )
        }
        self = decoded
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
    public var textContent: TextContent
    public var position: CGPoint?
    public var fontPostScriptName: String?
    public var fontDisplayName: String?
    public var fontSizeValue: PositiveFiniteDouble
    public var scaleValue: PositiveFiniteDouble
    public var rotationDegreesValue: FiniteDouble

    public var text: String { textContent.rawValue }
    public var fontSize: Double { fontSizeValue.rawValue }
    public var scale: Double { scaleValue.rawValue }
    public var rotationDegrees: Double { rotationDegreesValue.rawValue }

    public init?(
        targetLayerIndex: Int?,
        text: String,
        position: CGPoint?,
        fontPostScriptName: String?,
        fontDisplayName: String?,
        fontSize: Double,
        scale: Double,
        rotationDegrees: Double
    ) {
        guard let textContent = TextContent(text),
              let fontSizeValue = PositiveFiniteDouble(fontSize),
              let scaleValue = PositiveFiniteDouble(scale),
              let rotationDegreesValue = FiniteDouble(rotationDegrees) else {
            return nil
        }
        if let position {
            guard FiniteDouble(Double(position.x)) != nil,
                  FiniteDouble(Double(position.y)) != nil else {
                return nil
            }
        }
        self.targetLayerIndex = targetLayerIndex
        self.textContent = textContent
        self.position = position
        self.fontPostScriptName = fontPostScriptName
        self.fontDisplayName = fontDisplayName
        self.fontSizeValue = fontSizeValue
        self.scaleValue = scaleValue
        self.rotationDegreesValue = rotationDegreesValue
    }
}
