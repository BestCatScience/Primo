import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoCoreTypes
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts

public typealias DocumentMutationResult = Result<Void, DocumentMutationFailure>
public typealias DocumentIndexedMutationResult = Result<Int, DocumentMutationFailure>

public struct EditableLayerIndex: Equatable, Sendable {
    public let rawValue: Int
    public let revision: DocumentRevision

    public static func validated(
        _ rawValue: Int,
        revision: DocumentRevision = .initial,
        layerCount: Int,
        isLayerLocked: (Int) -> Bool
    ) -> EditableLayerIndex? {
        EditableLayerIndex(
            validating: rawValue,
            revision: revision,
            layerCount: layerCount,
            isLayerLocked: isLayerLocked
        )
    }

    package init?(
        validating rawValue: Int,
        revision: DocumentRevision = .initial,
        layerCount: Int,
        isLayerLocked: (Int) -> Bool
    ) {
        guard (0..<layerCount).contains(rawValue), !isLayerLocked(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
        self.revision = revision
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
    case layerLocked(Int)
    case alphaLocked(Int)
    case invalidCanvasSize(width: Int, height: Int)
    case invalidOpacity(Double)
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
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

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
            red: red,
            green: green,
            blue: blue
        )
    }

    public init(
        id: UUID = UUID(),
        position: GradientStopPosition,
        red: UInt8,
        green: UInt8,
        blue: UInt8
    ) {
        self.id = id
        self.positionValue = position
        self.red = red
        self.green = green
        self.blue = blue
    }

    public var position: Double { positionValue.rawValue }
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
    case transform(translation: CGSize, scale: CGFloat, rotationDegrees: Double, selection: CanvasSelection?)
}

public struct DocumentMutationGateway: Sendable {
    package let resizeCanvas: @Sendable (Int, Int) -> DocumentMutationResult
    package let resizeCanvasExtent: @Sendable (Int, Int) -> DocumentMutationResult
    package let addLayer: @Sendable (String) -> DocumentIndexedMutationResult
    package let deleteLayer: @Sendable (Int) -> DocumentMutationResult
    package let setActiveLayer: @Sendable (Int) -> DocumentMutationResult
    package let setLayerName: @Sendable (Int, String) -> DocumentMutationResult
    package let setLayerVisibility: @Sendable (Int, Bool) -> DocumentMutationResult
    package let revealLayerForEditing: @Sendable (Int) -> DocumentMutationResult
    package let replaceLayerPixels: @Sendable (Int, Data) -> DocumentMutationResult
    package let replaceLayerPixelsInRect: @Sendable (Int, LayerPixelRect, Data) -> DocumentMutationResult
    package let applyLayerSurfaceMutation: @Sendable (Int, GpuLayerMutationPayload) -> DocumentMutationResult
    package let applyLayerMutation: @Sendable (Int, DocumentLayerMutationPayload) -> DocumentMutationResult
    package let applyTextLayerMutation: @Sendable (Int, TextLayerData, DocumentLayerMutationPayload) -> DocumentMutationResult
    package let replaceLayerMask: @Sendable (Int, Data) -> DocumentMutationResult
    package let clearLayerMask: @Sendable (Int) -> DocumentMutationResult
    package let applyLayerMask: @Sendable (Int) -> DocumentMutationResult
    package let clearLayer: @Sendable (Int) -> DocumentMutationResult
    package let applyLayerProcessing: @Sendable (Int, LayerProcessingRequest) -> DocumentMutationResult

    public init(
        resizeCanvas: @escaping @Sendable (Int, Int) -> DocumentMutationResult,
        resizeCanvasExtent: @escaping @Sendable (Int, Int) -> DocumentMutationResult,
        addLayer: @escaping @Sendable (String) -> DocumentIndexedMutationResult,
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
        self.resizeCanvas = resizeCanvas
        self.resizeCanvasExtent = resizeCanvasExtent
        self.addLayer = addLayer
        self.deleteLayer = deleteLayer
        self.setActiveLayer = setActiveLayer
        self.setLayerName = setLayerName
        self.setLayerVisibility = setLayerVisibility
        self.revealLayerForEditing = revealLayerForEditing
        self.replaceLayerPixels = replaceLayerPixels
        self.replaceLayerPixelsInRect = replaceLayerPixelsInRect
        self.applyLayerSurfaceMutation = applyLayerSurfaceMutation
        self.applyLayerMutation = applyLayerMutation
        self.applyTextLayerMutation = applyTextLayerMutation
        self.replaceLayerMask = replaceLayerMask
        self.clearLayerMask = clearLayerMask
        self.applyLayerMask = applyLayerMask
        self.clearLayer = clearLayer
        self.applyLayerProcessing = applyLayerProcessing
    }
}

public struct StrokeInputGateway: Sendable {
    package let beginStroke: @Sendable (StylusSample, BrushRuntimeSettings) -> Void
    package let appendStroke: @Sendable (StylusSample) -> Void
    package let endStroke: @Sendable () -> DocumentMutationResult
    package let cancelStroke: @Sendable () -> Void
    package let blurStroke: @Sendable ([StylusSample], BrushRuntimeSettings, Int, Bool) -> DocumentMutationResult
    package let endBlurStroke: @Sendable () -> DocumentMutationResult
    package let cancelBlurStroke: @Sendable () -> Void
    package let fill: @Sendable (StylusSample, BrushRuntimeSettings) -> DocumentMutationResult
    package let applyGpuStrokeSurface: @Sendable ([StylusSample], BrushRuntimeSettings, Int) -> DocumentMutationResult

    public init(
        beginStroke: @escaping @Sendable (StylusSample, BrushRuntimeSettings) -> Void,
        appendStroke: @escaping @Sendable (StylusSample) -> Void,
        endStroke: @escaping @Sendable () -> DocumentMutationResult,
        cancelStroke: @escaping @Sendable () -> Void,
        blurStroke: @escaping @Sendable ([StylusSample], BrushRuntimeSettings, Int, Bool) -> DocumentMutationResult,
        endBlurStroke: @escaping @Sendable () -> DocumentMutationResult,
        cancelBlurStroke: @escaping @Sendable () -> Void,
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
    package let canUndo: @Sendable () -> Bool
    package let canRedo: @Sendable () -> Bool
    package let undo: @Sendable () -> DocumentMutationResult
    package let redo: @Sendable () -> DocumentMutationResult
    package let trimForMemoryPressure: @Sendable () -> Void

    public init(
        canUndo: @escaping @Sendable () -> Bool,
        canRedo: @escaping @Sendable () -> Bool,
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
    package let textLayerData: @Sendable (Int) -> TextLayerData?
    package let setTextLayer: @Sendable (Int, TextLayerData) -> DocumentMutationResult
    package let clearTextLayerData: @Sendable (Int) -> Void

    public init(
        textLayerData: @escaping @Sendable (Int) -> TextLayerData?,
        setTextLayer: @escaping @Sendable (Int, TextLayerData) -> DocumentMutationResult,
        clearTextLayerData: @escaping @Sendable (Int) -> Void
    ) {
        self.textLayerData = textLayerData
        self.setTextLayer = setTextLayer
        self.clearTextLayerData = clearTextLayerData
    }
}

public struct DocumentLayerEffectsGateway: Sendable {
    package let mergeLayerDown: @Sendable (Int) -> DocumentMutationResult

    public init(
        mergeLayerDown: @escaping @Sendable (Int) -> DocumentMutationResult
    ) {
        self.mergeLayerDown = mergeLayerDown
    }
}
