import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoCoreTypes
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts

public typealias DocumentMutationResult = Result<Void, DocumentMutationFailure>
public typealias DocumentCreatedLayerMutationResult = Result<DocumentCreatedLayerIndex, DocumentMutationFailure>
public typealias DocumentCreatedFolderMutationResult = Result<DocumentCreatedFolderID, DocumentMutationFailure>

public struct DocumentCreatedLayerIndex: Equatable, Sendable {
    public let rawValue: Int

    package init(_ rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct DocumentCreatedFolderID: Equatable, Sendable {
    public let rawValue: Int

    package init(_ rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct LayerIndexSet: Equatable, Sendable {
    public let rawValues: Set<Int>

    public init(_ rawValues: Set<Int>) {
        self.rawValues = rawValues
    }

    public init<S: Sequence>(_ rawValues: S) where S.Element == Int {
        self.rawValues = Set(rawValues)
    }

    public static func contiguous(count: Int) -> LayerIndexSet {
        LayerIndexSet(Set(0..<max(0, count)))
    }

    public var count: Int {
        rawValues.count
    }

    public func contains(_ rawValue: Int) -> Bool {
        rawValues.contains(rawValue)
    }
}

public struct EditableLayerIndex: Equatable, Sendable {
    public let rawValue: Int
    public let revision: DocumentRevision

    package static func validated(
        _ rawValue: Int,
        revision: DocumentRevision = .initial,
        layerIndexes: LayerIndexSet,
        isLayerLocked: (Int) -> Bool
    ) -> EditableLayerIndex? {
        EditableLayerIndex(
            validating: rawValue,
            revision: revision,
            layerIndexes: layerIndexes,
            isLayerLocked: isLayerLocked
        )
    }

    package static func validated(
        _ rawValue: Int,
        revision: DocumentRevision = .initial,
        layerCount: Int,
        isLayerLocked: (Int) -> Bool
    ) -> EditableLayerIndex? {
        validated(
            rawValue,
            revision: revision,
            layerIndexes: .contiguous(count: layerCount),
            isLayerLocked: isLayerLocked
        )
    }

    package init?(
        validating rawValue: Int,
        revision: DocumentRevision = .initial,
        layerIndexes: LayerIndexSet,
        isLayerLocked: (Int) -> Bool
    ) {
        guard layerIndexes.contains(rawValue), !isLayerLocked(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
        self.revision = revision
    }

    package init?(
        validating rawValue: Int,
        revision: DocumentRevision = .initial,
        layerCount: Int,
        isLayerLocked: (Int) -> Bool
    ) {
        self.init(
            validating: rawValue,
            revision: revision,
            layerIndexes: .contiguous(count: layerCount),
            isLayerLocked: isLayerLocked
        )
    }

    package init(_ rawValue: Int) {
        self.init(rawValue, revision: .initial)
    }

    package init(_ rawValue: Int, revision: DocumentRevision) {
        self.rawValue = rawValue
        self.revision = revision
    }
}

public enum DocumentGpuMutationFailure: Error, Equatable, Sendable {
    case gpuUnavailable
    case staleSnapshot(operation: String)
    case invalidPayloadSize(operation: String, expected: Int, actual: Int)
    case invalidDirtyRect(operation: String)
    case resourceHandleInvalid
    case kernelFailed(operation: String)

    public var displayMessage: String {
        switch self {
        case .gpuUnavailable:
            return "GPU unavailable"
        case let .staleSnapshot(operation):
            return "\(operation): stale snapshot"
        case let .invalidPayloadSize(operation, expected, actual):
            return "\(operation): invalid payload size, expected \(expected), got \(actual)"
        case let .invalidDirtyRect(operation):
            return "\(operation): invalid dirty rect"
        case .resourceHandleInvalid:
            return "GPU resource handle invalid"
        case let .kernelFailed(operation):
            return "\(operation): GPU kernel failed"
        }
    }
}

public enum DocumentMutationFailure: Error, Equatable, Sendable, OperationFailure {
    case invalidLayerIndex(Int)
    case staleLayerIndex(index: Int, validationRevision: DocumentRevision, currentRevision: DocumentRevision)
    case invalidFolderID(Int)
    case staleFolderID(folderID: Int, validationRevision: DocumentRevision, currentRevision: DocumentRevision)
    case staleLayerAnchor(anchorLayerIndex: Int?, validationRevision: DocumentRevision, currentRevision: DocumentRevision)
    case layerLocked(Int)
    case alphaLocked(Int)
    case invalidCanvasSize(width: Int, height: Int)
    case invalidOpacity(Double)
    case invalidLayerProcessingRequest(String)
    case emptyInput
    case noUndoState
    case noRedoState
    case gpu(DocumentGpuMutationFailure)
    case bridgeMutationFailed(String)
    case incompatibleLayerType(Int)
    indirect case transactionFailure(primary: DocumentMutationFailure, rollback: DocumentMutationFailure)
}

public struct HueAdjustmentDegrees: Equatable, Sendable {
    public let rawValue: Double

    public init?(_ rawValue: Double) {
        guard rawValue.isFinite, (-180...180).contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init(clamping rawValue: Double) {
        guard rawValue.isFinite else {
            self.rawValue = 0
            return
        }
        self.rawValue = min(max(rawValue, -180), 180)
    }
}

public struct AdjustmentScale: Equatable, Sendable {
    public let rawValue: Double

    public init?(_ rawValue: Double) {
        guard rawValue.isFinite, (0...2).contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init(clamping rawValue: Double) {
        guard rawValue.isFinite else {
            self.rawValue = 1
            return
        }
        self.rawValue = min(max(rawValue, 0), 2)
    }
}

public struct FiniteTranslation: Equatable, Sendable {
    public let rawValue: CGSize

    public init?(_ rawValue: CGSize) {
        guard rawValue.width.isFinite, rawValue.height.isFinite else { return nil }
        self.rawValue = rawValue
    }
}

public struct TransformScale: Equatable, Sendable {
    public let rawValue: CGFloat

    public init?(_ rawValue: CGFloat) {
        guard rawValue.isFinite, rawValue > 0 else { return nil }
        self.rawValue = rawValue
    }
}

public struct RotationDegrees: Equatable, Sendable {
    public let rawValue: Double

    public init?(_ rawValue: Double) {
        guard rawValue.isFinite else { return nil }
        self.rawValue = rawValue
    }
}

public struct LayerTransformProcessingRequest: Equatable, Sendable {
    public let translation: FiniteTranslation
    public let scale: TransformScale
    public let rotationDegrees: RotationDegrees
    public let selection: CanvasSelection?

    public init(
        translation: FiniteTranslation,
        scale: TransformScale,
        rotationDegrees: RotationDegrees,
        selection: CanvasSelection?
    ) {
        self.translation = translation
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.selection = selection
    }
}

public struct AdjustmentOffset: Equatable, Sendable {
    public let rawValue: Double

    public init?(_ rawValue: Double) {
        guard rawValue.isFinite, (-1...1).contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init(clamping rawValue: Double) {
        guard rawValue.isFinite else {
            self.rawValue = 0
            return
        }
        self.rawValue = min(max(rawValue, -1), 1)
    }
}

public struct ThresholdValue: Equatable, Sendable {
    public let rawValue: Double

    public init?(_ rawValue: Double) {
        guard rawValue.isFinite, (0...1).contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init(clamping rawValue: Double) {
        guard rawValue.isFinite else {
            self.rawValue = 0.5
            return
        }
        self.rawValue = min(max(rawValue, 0), 1)
    }
}

public struct PosterizeLevels: Equatable, Sendable {
    public static let allowedRange = 2...256

    public let rawValue: Int

    public init?(_ rawValue: Int) {
        guard Self.allowedRange.contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init?(rounding rawValue: Double) {
        guard rawValue.isFinite else { return nil }
        self.init(Int(rawValue.rounded()))
    }

    public init(clamping rawValue: Double) {
        guard rawValue.isFinite else {
            self.rawValue = 6
            return
        }
        let roundedValue = Int(rawValue.rounded())
        self.rawValue = min(max(roundedValue, Self.allowedRange.lowerBound), Self.allowedRange.upperBound)
    }
}

public typealias PosterizeLevelCount = PosterizeLevels

public struct GradientStopPosition: Equatable, Sendable {
    public let rawValue: Double

    public init?(_ rawValue: Double) {
        guard rawValue.isFinite, (0...1).contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init(clamping rawValue: Double) {
        guard rawValue.isFinite else {
            self.rawValue = 0
            return
        }
        self.rawValue = min(max(rawValue, 0), 1)
    }
}

public struct HueSaturationBrightnessSettings: Equatable, Sendable {
    public let hueDegreesValue: HueAdjustmentDegrees
    public let saturationValue: AdjustmentScale
    public let brightnessValue: AdjustmentOffset

    public init(hueDegrees: Double = 0, saturation: Double = 1, brightness: Double = 0) {
        self.init(
            hueDegrees: HueAdjustmentDegrees(clamping: hueDegrees),
            saturation: AdjustmentScale(clamping: saturation),
            brightness: AdjustmentOffset(clamping: brightness)
        )
    }

    public init(
        hueDegrees: HueAdjustmentDegrees,
        saturation: AdjustmentScale,
        brightness: AdjustmentOffset
    ) {
        self.hueDegreesValue = hueDegrees
        self.saturationValue = saturation
        self.brightnessValue = brightness
    }

    public var hueDegrees: Double { hueDegreesValue.rawValue }
    public var saturation: Double { saturationValue.rawValue }
    public var brightness: Double { brightnessValue.rawValue }
}

public struct BrightnessContrastSettings: Equatable, Sendable {
    public let brightnessValue: AdjustmentOffset
    public let contrastValue: AdjustmentScale

    public init(brightness: Double = 0, contrast: Double = 1) {
        self.init(
            brightness: AdjustmentOffset(clamping: brightness),
            contrast: AdjustmentScale(clamping: contrast)
        )
    }

    public init(brightness: AdjustmentOffset, contrast: AdjustmentScale) {
        self.brightnessValue = brightness
        self.contrastValue = contrast
    }

    public var brightness: Double { brightnessValue.rawValue }
    public var contrast: Double { contrastValue.rawValue }
}

public struct LevelsAdjustmentSettings: Equatable, Sendable {
    public let inputBlackValue: UnitInterval
    public let inputWhiteValue: UnitInterval
    public let gammaValue: PositiveFiniteDouble
    public let outputBlackValue: UnitInterval
    public let outputWhiteValue: UnitInterval

    public init(
        inputBlack: Double = 0,
        inputWhite: Double = 1,
        gamma: Double = 1,
        outputBlack: Double = 0,
        outputWhite: Double = 1
    ) {
        self.init(
            inputBlack: Self.clampedUnitInterval(inputBlack, fallback: 0),
            inputWhite: Self.clampedUnitInterval(inputWhite, fallback: 1),
            gamma: PositiveFiniteDouble(gamma) ?? PositiveFiniteDouble(1)!,
            outputBlack: Self.clampedUnitInterval(outputBlack, fallback: 0),
            outputWhite: Self.clampedUnitInterval(outputWhite, fallback: 1)
        )
    }

    public init(
        inputBlack: UnitInterval,
        inputWhite: UnitInterval,
        gamma: PositiveFiniteDouble,
        outputBlack: UnitInterval,
        outputWhite: UnitInterval
    ) {
        self.inputBlackValue = inputBlack
        self.inputWhiteValue = inputWhite
        self.gammaValue = gamma
        self.outputBlackValue = outputBlack
        self.outputWhiteValue = outputWhite
    }

    public var inputBlack: Double { inputBlackValue.rawValue }
    public var inputWhite: Double { inputWhiteValue.rawValue }
    public var gamma: Double { gammaValue.rawValue }
    public var outputBlack: Double { outputBlackValue.rawValue }
    public var outputWhite: Double { outputWhiteValue.rawValue }

    private static func clampedUnitInterval(_ value: Double, fallback: Double) -> UnitInterval {
        guard value.isFinite else { return UnitInterval(fallback)! }
        return UnitInterval(min(max(value, 0), 1))!
    }
}

public struct ToneCurveSettings: Equatable, Sendable {
    public let shadowsValue: AdjustmentOffset
    public let midtonesValue: AdjustmentOffset
    public let highlightsValue: AdjustmentOffset

    public init(shadows: Double = 0, midtones: Double = 0, highlights: Double = 0) {
        self.init(
            shadows: AdjustmentOffset(clamping: shadows),
            midtones: AdjustmentOffset(clamping: midtones),
            highlights: AdjustmentOffset(clamping: highlights)
        )
    }

    public init(shadows: AdjustmentOffset, midtones: AdjustmentOffset, highlights: AdjustmentOffset) {
        self.shadowsValue = shadows
        self.midtonesValue = midtones
        self.highlightsValue = highlights
    }

    public var shadows: Double { shadowsValue.rawValue }
    public var midtones: Double { midtonesValue.rawValue }
    public var highlights: Double { highlightsValue.rawValue }
}

public struct ColorBalanceSettings: Equatable, Sendable {
    public let redCyanValue: AdjustmentOffset
    public let greenMagentaValue: AdjustmentOffset
    public let blueYellowValue: AdjustmentOffset

    public init(redCyan: Double = 0, greenMagenta: Double = 0, blueYellow: Double = 0) {
        self.init(
            redCyan: AdjustmentOffset(clamping: redCyan),
            greenMagenta: AdjustmentOffset(clamping: greenMagenta),
            blueYellow: AdjustmentOffset(clamping: blueYellow)
        )
    }

    public init(redCyan: AdjustmentOffset, greenMagenta: AdjustmentOffset, blueYellow: AdjustmentOffset) {
        self.redCyanValue = redCyan
        self.greenMagentaValue = greenMagenta
        self.blueYellowValue = blueYellow
    }

    public var redCyan: Double { redCyanValue.rawValue }
    public var greenMagenta: Double { greenMagentaValue.rawValue }
    public var blueYellow: Double { blueYellowValue.rawValue }
}

public struct ThresholdSettings: Equatable, Sendable {
    public let thresholdValue: ThresholdValue

    public init(threshold: Double = 0.5) {
        self.init(threshold: ThresholdValue(clamping: threshold))
    }

    public init(threshold: ThresholdValue) {
        self.thresholdValue = threshold
    }

    public var threshold: Double { thresholdValue.rawValue }
}

public struct PosterizeSettings: Equatable, Sendable {
    public let levelsValue: PosterizeLevels

    public init(levels: Double = 6) {
        self.init(levels: PosterizeLevels(clamping: levels))
    }

    public init(levels: Int) {
        self.init(levels: PosterizeLevels(levels) ?? PosterizeLevels(clamping: Double(levels)))
    }

    public init(levels: PosterizeLevels) {
        self.levelsValue = levels
    }

    public var levels: Double { Double(levelsValue.rawValue) }
}

public enum GradientMapPreset: String, CaseIterable, Equatable, Sendable, Identifiable {
    case graphite
    case sepia
    case ocean
    case sunset
    case toxic

    public var id: String { rawValue }
}

public struct GradientMapStopSettings: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let positionValue: GradientStopPosition
    public let colorValue: CanvasColor

    public init(
        id: UUID = UUID(),
        position: Double,
        red: UInt8,
        green: UInt8,
        blue: UInt8
    ) {
        self.init(
            id: id,
            position: GradientStopPosition(clamping: position),
            color: CanvasColor(
                red: Self.unitInterval(from: red),
                green: Self.unitInterval(from: green),
                blue: Self.unitInterval(from: blue),
                alpha: UnitInterval(1)!
            )
        )
    }

    public init(
        id: UUID = UUID(),
        position: GradientStopPosition,
        red: UInt8,
        green: UInt8,
        blue: UInt8
    ) {
        self.init(
            id: id,
            position: position,
            color: CanvasColor(
                red: Self.unitInterval(from: red),
                green: Self.unitInterval(from: green),
                blue: Self.unitInterval(from: blue),
                alpha: UnitInterval(1)!
            )
        )
    }

    public init(
        id: UUID = UUID(),
        position: Double,
        color: CanvasColor
    ) {
        self.init(
            id: id,
            position: GradientStopPosition(clamping: position),
            color: color
        )
    }

    public init(
        id: UUID = UUID(),
        position: Double,
        red: UnitInterval,
        green: UnitInterval,
        blue: UnitInterval
    ) {
        self.init(
            id: id,
            position: position,
            color: CanvasColor(red: red, green: green, blue: blue, alpha: UnitInterval(1)!)
        )
    }

    public init(
        id: UUID = UUID(),
        position: GradientStopPosition,
        color: CanvasColor
    ) {
        self.id = id
        self.positionValue = position
        self.colorValue = CanvasColor(
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: UnitInterval(1)!
        )
    }

    public var position: Double { positionValue.rawValue }
    public var red: UInt8 { Self.byte(from: colorValue.red) }
    public var green: UInt8 { Self.byte(from: colorValue.green) }
    public var blue: UInt8 { Self.byte(from: colorValue.blue) }

    public func withPosition(_ position: Double) -> Self {
        Self(id: id, position: position, color: colorValue)
    }

    public func withPosition(_ position: GradientStopPosition) -> Self {
        Self(id: id, position: position, color: colorValue)
    }

    public func withColor(_ color: CanvasColor) -> Self {
        Self(id: id, position: positionValue, color: color)
    }

    private static func unitInterval(from component: UInt8) -> UnitInterval {
        UnitInterval(Double(component) / 255.0)!
    }

    private static func byte(from component: UnitInterval) -> UInt8 {
        UInt8(min(max((component.rawValue * 255.0).rounded(), 0), 255))
    }
}

public struct GradientMapSettings: Equatable, Sendable {
    public var stops: [GradientMapStopSettings] = [
        GradientMapStopSettings(position: 0.0, red: 17, green: 21, blue: 27),
        GradientMapStopSettings(position: 0.5, red: 84, green: 93, blue: 108),
        GradientMapStopSettings(position: 1.0, red: 243, green: 244, blue: 246)
    ]

    public init(stops: [GradientMapStopSettings] = [
        GradientMapStopSettings(position: 0.0, red: 17, green: 21, blue: 27),
        GradientMapStopSettings(position: 0.5, red: 84, green: 93, blue: 108),
        GradientMapStopSettings(position: 1.0, red: 243, green: 244, blue: 246)
    ]) {
        self.stops = stops
    }
}

public enum LayerProcessingRequest: Equatable, Sendable {
    case gradientMap(GradientMapPreset)
    case gradientMapSettings(GradientMapSettings)
    case hueSaturationBrightness(HueSaturationBrightnessSettings)
    case brightnessContrast(BrightnessContrastSettings)
    case levels(LevelsAdjustmentSettings)
    case toneCurve(ToneCurveSettings)
    case colorBalance(ColorBalanceSettings)
    case threshold(ThresholdSettings)
    case posterize(PosterizeSettings)
    case luminanceToAlpha
    case transform(LayerTransformProcessingRequest)
}

package struct DocumentMutationGateway: Sendable {
    private let resizeCanvasHandler: @Sendable (Int, Int) -> DocumentMutationResult
    private let resizeCanvasExtentHandler: @Sendable (Int, Int) -> DocumentMutationResult
    private let addLayerHandler: @Sendable (String) -> DocumentCreatedLayerMutationResult
    private let deleteLayerHandler: @Sendable (Int) -> DocumentMutationResult
    private let setActiveLayerHandler: @Sendable (Int) -> DocumentMutationResult
    private let setLayerNameHandler: @Sendable (Int, String) -> DocumentMutationResult
    private let setLayerVisibilityHandler: @Sendable (Int, Bool) -> DocumentMutationResult
    private let revealLayerForEditingHandler: @Sendable (Int) -> DocumentMutationResult
    private let replaceLayerPixelsHandler: @Sendable (Int, Data) -> DocumentMutationResult
    private let replaceLayerPixelsInRectHandler: @Sendable (Int, LayerPixelRect, Data) -> DocumentMutationResult
    private let applyLayerSurfaceMutationHandler: @Sendable (Int, GpuLayerMutationPayload) -> DocumentMutationResult
    private let applyLayerMutationHandler: @Sendable (Int, DocumentLayerMutationPayload) -> DocumentMutationResult
    private let applyTextLayerMutationHandler: @Sendable (Int, TextLayerData, DocumentLayerMutationPayload) -> DocumentMutationResult
    private let replaceLayerMaskHandler: @Sendable (Int, Data) -> DocumentMutationResult
    private let clearLayerMaskHandler: @Sendable (Int) -> DocumentMutationResult
    private let applyLayerMaskHandler: @Sendable (Int) -> DocumentMutationResult
    private let clearLayerHandler: @Sendable (Int) -> DocumentMutationResult
    private let applyLayerProcessingHandler: @Sendable (Int, LayerProcessingRequest) -> DocumentMutationResult

    package init(
        resizeCanvas: @escaping @Sendable (Int, Int) -> DocumentMutationResult,
        resizeCanvasExtent: @escaping @Sendable (Int, Int) -> DocumentMutationResult,
        addLayer: @escaping @Sendable (String) -> DocumentCreatedLayerMutationResult,
        deleteLayer: @escaping @Sendable (Int) -> DocumentMutationResult,
        setActiveLayer: @escaping @Sendable (Int) -> DocumentMutationResult,
        setLayerName: @escaping @Sendable (Int, String) -> DocumentMutationResult,
        setLayerVisibility: @escaping @Sendable (Int, Bool) -> DocumentMutationResult,
        revealLayerForEditing: @escaping @Sendable (Int) -> DocumentMutationResult,
        replaceLayerPixels: @escaping @Sendable (Int, Data) -> DocumentMutationResult,
        replaceLayerPixelsInRect: @escaping @Sendable (Int, LayerPixelRect, Data) -> DocumentMutationResult,
        applyLayerSurfaceMutation: @escaping @Sendable (Int, GpuLayerMutationPayload) -> DocumentMutationResult,
        applyLayerMutation: @escaping @Sendable (Int, DocumentLayerMutationPayload) -> DocumentMutationResult,
        applyTextLayerMutation: @escaping @Sendable (Int, TextLayerData, DocumentLayerMutationPayload) -> DocumentMutationResult,
        replaceLayerMask: @escaping @Sendable (Int, Data) -> DocumentMutationResult,
        clearLayerMask: @escaping @Sendable (Int) -> DocumentMutationResult,
        applyLayerMask: @escaping @Sendable (Int) -> DocumentMutationResult,
        clearLayer: @escaping @Sendable (Int) -> DocumentMutationResult,
        applyLayerProcessing: @escaping @Sendable (Int, LayerProcessingRequest) -> DocumentMutationResult
    ) {
        self.resizeCanvasHandler = resizeCanvas
        self.resizeCanvasExtentHandler = resizeCanvasExtent
        self.addLayerHandler = addLayer
        self.deleteLayerHandler = deleteLayer
        self.setActiveLayerHandler = setActiveLayer
        self.setLayerNameHandler = setLayerName
        self.setLayerVisibilityHandler = setLayerVisibility
        self.revealLayerForEditingHandler = revealLayerForEditing
        self.replaceLayerPixelsHandler = replaceLayerPixels
        self.replaceLayerPixelsInRectHandler = replaceLayerPixelsInRect
        self.applyLayerSurfaceMutationHandler = applyLayerSurfaceMutation
        self.applyLayerMutationHandler = applyLayerMutation
        self.applyTextLayerMutationHandler = applyTextLayerMutation
        self.replaceLayerMaskHandler = replaceLayerMask
        self.clearLayerMaskHandler = clearLayerMask
        self.applyLayerMaskHandler = applyLayerMask
        self.clearLayerHandler = clearLayer
        self.applyLayerProcessingHandler = applyLayerProcessing
    }

    package func resizeCanvas(_ width: Int, _ height: Int) -> DocumentMutationResult {
        resizeCanvasHandler(width, height)
    }

    package func resizeCanvasExtent(_ width: Int, _ height: Int) -> DocumentMutationResult {
        resizeCanvasExtentHandler(width, height)
    }

    package func addLayer(_ name: String) -> DocumentCreatedLayerMutationResult {
        addLayerHandler(name)
    }

    package func deleteLayer(_ index: Int) -> DocumentMutationResult {
        deleteLayerHandler(index)
    }

    package func setActiveLayer(_ index: Int) -> DocumentMutationResult {
        setActiveLayerHandler(index)
    }

    package func setLayerName(_ index: Int, _ name: String) -> DocumentMutationResult {
        setLayerNameHandler(index, name)
    }

    package func setLayerVisibility(_ index: Int, _ visible: Bool) -> DocumentMutationResult {
        setLayerVisibilityHandler(index, visible)
    }

    package func revealLayerForEditing(_ index: Int) -> DocumentMutationResult {
        revealLayerForEditingHandler(index)
    }

    package func replaceLayerPixels(_ index: Int, _ pixelData: Data) -> DocumentMutationResult {
        replaceLayerPixelsHandler(index, pixelData)
    }

    package func replaceLayerPixelsInRect(_ index: Int, _ rect: LayerPixelRect, _ pixelData: Data) -> DocumentMutationResult {
        replaceLayerPixelsInRectHandler(index, rect, pixelData)
    }

    package func applyLayerSurfaceMutation(_ index: Int, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult {
        applyLayerSurfaceMutationHandler(index, payload)
    }

    package func applyLayerMutation(_ index: Int, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult {
        applyLayerMutationHandler(index, payload)
    }

    package func applyTextLayerMutation(_ index: Int, _ textLayer: TextLayerData, _ payload: DocumentLayerMutationPayload) -> DocumentMutationResult {
        applyTextLayerMutationHandler(index, textLayer, payload)
    }

    package func replaceLayerMask(_ index: Int, _ mask: Data) -> DocumentMutationResult {
        replaceLayerMaskHandler(index, mask)
    }

    package func clearLayerMask(_ index: Int) -> DocumentMutationResult {
        clearLayerMaskHandler(index)
    }

    package func applyLayerMask(_ index: Int) -> DocumentMutationResult {
        applyLayerMaskHandler(index)
    }

    package func clearLayer(_ index: Int) -> DocumentMutationResult {
        clearLayerHandler(index)
    }

    package func applyLayerProcessing(_ index: Int, _ request: LayerProcessingRequest) -> DocumentMutationResult {
        applyLayerProcessingHandler(index, request)
    }
}

public struct StrokeInputGateway: Sendable {
    package let beginStroke: @Sendable (StylusSample, BrushRuntimeSettings) -> DocumentMutationResult
    package let appendStroke: @Sendable (StylusSample) -> DocumentMutationResult
    package let endStroke: @Sendable () -> DocumentMutationResult
    package let cancelStroke: @Sendable () -> DocumentMutationResult
    package let blurStroke: @Sendable ([StylusSample], BrushRuntimeSettings, Int, Bool) -> DocumentMutationResult
    package let endBlurStroke: @Sendable () -> DocumentMutationResult
    package let cancelBlurStroke: @Sendable () -> DocumentMutationResult
    package let fill: @Sendable (StylusSample, BrushRuntimeSettings) -> DocumentMutationResult
    package let applyGpuStrokeSurface: @Sendable ([StylusSample], BrushRuntimeSettings, Int) -> DocumentMutationResult

    public init(
        beginStroke: @escaping @Sendable (StylusSample, BrushRuntimeSettings) -> DocumentMutationResult,
        appendStroke: @escaping @Sendable (StylusSample) -> DocumentMutationResult,
        endStroke: @escaping @Sendable () -> DocumentMutationResult,
        cancelStroke: @escaping @Sendable () -> DocumentMutationResult,
        blurStroke: @escaping @Sendable ([StylusSample], BrushRuntimeSettings, Int, Bool) -> DocumentMutationResult,
        endBlurStroke: @escaping @Sendable () -> DocumentMutationResult,
        cancelBlurStroke: @escaping @Sendable () -> DocumentMutationResult,
        fill: @escaping @Sendable (StylusSample, BrushRuntimeSettings) -> DocumentMutationResult,
        applyGpuStrokeSurface: @escaping @Sendable ([StylusSample], BrushRuntimeSettings, Int) -> DocumentMutationResult
    ) {
        self.beginStroke = beginStroke
        self.appendStroke = appendStroke
        self.endStroke = endStroke
        self.cancelStroke = cancelStroke
        self.blurStroke = blurStroke
        self.endBlurStroke = endBlurStroke
        self.cancelBlurStroke = cancelBlurStroke
        self.fill = fill
        self.applyGpuStrokeSurface = applyGpuStrokeSurface
    }
}

public struct DocumentHistoryGateway: Sendable {
    package let canUndo: @Sendable () -> Result<Bool, DocumentMutationFailure>
    package let canRedo: @Sendable () -> Result<Bool, DocumentMutationFailure>
    package let undo: @Sendable () -> DocumentMutationResult
    package let redo: @Sendable () -> DocumentMutationResult
    package let trimForMemoryPressure: @Sendable () -> Void

    public init(
        canUndo: @escaping @Sendable () -> Result<Bool, DocumentMutationFailure>,
        canRedo: @escaping @Sendable () -> Result<Bool, DocumentMutationFailure>,
        undo: @escaping @Sendable () -> DocumentMutationResult,
        redo: @escaping @Sendable () -> DocumentMutationResult,
        trimForMemoryPressure: @escaping @Sendable () -> Void = {}
    ) {
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.undo = undo
        self.redo = redo
        self.trimForMemoryPressure = trimForMemoryPressure
    }
}

public struct TextLayerGateway: Sendable {
    package let textLayerData: @Sendable (Int) -> Result<TextLayerData?, DocumentMutationFailure>
    package let setTextLayer: @Sendable (Int, TextLayerData) -> DocumentMutationResult
    package let clearTextLayerData: @Sendable (Int) -> DocumentMutationResult

    public init(
        textLayerData: @escaping @Sendable (Int) -> Result<TextLayerData?, DocumentMutationFailure>,
        setTextLayer: @escaping @Sendable (Int, TextLayerData) -> DocumentMutationResult,
        clearTextLayerData: @escaping @Sendable (Int) -> DocumentMutationResult
    ) {
        self.textLayerData = textLayerData
        self.setTextLayer = setTextLayer
        self.clearTextLayerData = clearTextLayerData
    }

}

public struct DocumentLayerEffectsGateway: Sendable {
    private let mergeLayerDownImpl: @Sendable (Int) -> DocumentMutationResult

    public init(
        mergeLayerDown: @escaping @Sendable (Int) -> DocumentMutationResult
    ) {
        self.mergeLayerDownImpl = mergeLayerDown
    }

    package func mergeLayerDown(_ index: Int) -> DocumentMutationResult {
        mergeLayerDownImpl(index)
    }
}
