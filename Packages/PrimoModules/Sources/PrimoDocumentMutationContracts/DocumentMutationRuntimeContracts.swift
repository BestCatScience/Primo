import CoreGraphics
import Foundation
@_exported import PrimoBrushRuntimeContracts
import PrimoCoreTypes
import PrimoDocumentDomain
@_exported import PrimoDocumentPresentationContracts

public typealias DocumentMutationResult = Result<Void, DocumentMutationFailure>
public typealias DocumentIndexedMutationResult = Result<Int, DocumentMutationFailure>

public enum DocumentMutationFailure: Error, Equatable, Sendable, OperationFailure {
    case invalidLayerIndex(Int)
    case invalidFolderID(Int)
    case layerLocked(Int)
    case alphaLocked(Int)
    case invalidCanvasSize(width: Int, height: Int)
    case invalidOpacity(Double)
    case emptyInput
    case noUndoState
    case noRedoState
    case bridgeMutationFailed(String)
    case incompatibleLayerType(Int)
    indirect case transactionFailure(primary: DocumentMutationFailure, rollback: DocumentMutationFailure)
}

public struct HueSaturationBrightnessSettings: Equatable, Sendable {
    public var hueDegrees: Double = 0
    public var saturation: Double = 1
    public var brightness: Double = 0
    public init(hueDegrees: Double = 0, saturation: Double = 1, brightness: Double = 0) {
        self.hueDegrees = hueDegrees
        self.saturation = saturation
        self.brightness = brightness
    }
}

public struct BrightnessContrastSettings: Equatable, Sendable {
    public var brightness: Double = 0
    public var contrast: Double = 1
    public init(brightness: Double = 0, contrast: Double = 1) {
        self.brightness = brightness
        self.contrast = contrast
    }
}

public struct LevelsAdjustmentSettings: Equatable, Sendable {
    public var inputBlack: Double = 0
    public var inputWhite: Double = 1
    public var gamma: Double = 1
    public var outputBlack: Double = 0
    public var outputWhite: Double = 1
    public init(inputBlack: Double = 0, inputWhite: Double = 1, gamma: Double = 1, outputBlack: Double = 0, outputWhite: Double = 1) {
        self.inputBlack = inputBlack
        self.inputWhite = inputWhite
        self.gamma = gamma
        self.outputBlack = outputBlack
        self.outputWhite = outputWhite
    }
}

public struct ToneCurveSettings: Equatable, Sendable {
    public var shadows: Double = 0
    public var midtones: Double = 0
    public var highlights: Double = 0
    public init(shadows: Double = 0, midtones: Double = 0, highlights: Double = 0) {
        self.shadows = shadows
        self.midtones = midtones
        self.highlights = highlights
    }
}

public struct ColorBalanceSettings: Equatable, Sendable {
    public var redCyan: Double = 0
    public var greenMagenta: Double = 0
    public var blueYellow: Double = 0
    public init(redCyan: Double = 0, greenMagenta: Double = 0, blueYellow: Double = 0) {
        self.redCyan = redCyan
        self.greenMagenta = greenMagenta
        self.blueYellow = blueYellow
    }
}

public struct ThresholdSettings: Equatable, Sendable {
    public var threshold: Double = 0.5
    public init(threshold: Double = 0.5) {
        self.threshold = threshold
    }
}

public struct PosterizeSettings: Equatable, Sendable {
    public var levels: Double = 6
    public init(levels: Double = 6) {
        self.levels = levels
    }
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
    public var position: Double
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
        self.id = id
        self.position = position
        self.red = red
        self.green = green
        self.blue = blue
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
    case transform(translation: CGSize, scale: CGFloat, rotationDegrees: Double, selection: CanvasSelection?)
}

public struct DocumentMutationGateway: Sendable {
    public var resizeCanvas: @Sendable (Int, Int) -> DocumentMutationResult
    public var resizeCanvasExtent: @Sendable (Int, Int) -> DocumentMutationResult
    public var addLayer: @Sendable (String) -> DocumentIndexedMutationResult
    public var deleteLayer: @Sendable (Int) -> DocumentMutationResult
    public var setActiveLayer: @Sendable (Int) -> DocumentMutationResult
    public var setLayerName: @Sendable (Int, String) -> DocumentMutationResult
    public var setLayerVisibility: @Sendable (Int, Bool) -> DocumentMutationResult
    public var revealLayerForEditing: @Sendable (Int) -> DocumentMutationResult
    public var replaceLayerPixels: @Sendable (Int, Data) -> DocumentMutationResult
    public var replaceLayerPixelsInRect: @Sendable (Int, LayerPixelRect, Data) -> DocumentMutationResult
    public var applyLayerSurfaceMutation: @Sendable (Int, GpuLayerMutationPayload) -> DocumentMutationResult
    public var applyLayerMutation: @Sendable (Int, DocumentLayerMutationPayload) -> DocumentMutationResult
    public var applyTextLayerMutation: @Sendable (Int, TextLayerData, DocumentLayerMutationPayload) -> DocumentMutationResult
    public var replaceLayerMask: @Sendable (Int, Data) -> DocumentMutationResult
    public var clearLayerMask: @Sendable (Int) -> DocumentMutationResult
    public var applyLayerMask: @Sendable (Int) -> DocumentMutationResult
    public var clearLayer: @Sendable (Int) -> DocumentMutationResult
    public var applyLayerProcessing: @Sendable (Int, LayerProcessingRequest) -> DocumentMutationResult

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
    public var beginStroke: @Sendable (StylusSample, BrushRuntimeSettings) -> Void
    public var appendStroke: @Sendable (StylusSample) -> Void
    public var endStroke: @Sendable () -> DocumentMutationResult
    public var cancelStroke: @Sendable () -> Void
    public var blurStroke: @Sendable ([StylusSample], BrushRuntimeSettings, Int, Bool) -> DocumentMutationResult
    public var endBlurStroke: @Sendable () -> Void
    public var fill: @Sendable (StylusSample, BrushRuntimeSettings) -> DocumentMutationResult
    public var applyGpuStrokeSurface: @Sendable ([StylusSample], BrushRuntimeSettings, Int) -> DocumentMutationResult

    public init(
        beginStroke: @escaping @Sendable (StylusSample, BrushRuntimeSettings) -> Void,
        appendStroke: @escaping @Sendable (StylusSample) -> Void,
        endStroke: @escaping @Sendable () -> DocumentMutationResult,
        cancelStroke: @escaping @Sendable () -> Void,
        blurStroke: @escaping @Sendable ([StylusSample], BrushRuntimeSettings, Int, Bool) -> DocumentMutationResult,
        endBlurStroke: @escaping @Sendable () -> Void,
        fill: @escaping @Sendable (StylusSample, BrushRuntimeSettings) -> DocumentMutationResult,
        applyGpuStrokeSurface: @escaping @Sendable ([StylusSample], BrushRuntimeSettings, Int) -> DocumentMutationResult
    ) {
        self.beginStroke = beginStroke
        self.appendStroke = appendStroke
        self.endStroke = endStroke
        self.cancelStroke = cancelStroke
        self.blurStroke = blurStroke
        self.endBlurStroke = endBlurStroke
        self.fill = fill
        self.applyGpuStrokeSurface = applyGpuStrokeSurface
    }
}

public struct DocumentHistoryGateway: Sendable {
    public var canUndo: @Sendable () -> Bool
    public var canRedo: @Sendable () -> Bool
    public var undo: @Sendable () -> DocumentMutationResult
    public var redo: @Sendable () -> DocumentMutationResult

    public init(
        canUndo: @escaping @Sendable () -> Bool,
        canRedo: @escaping @Sendable () -> Bool,
        undo: @escaping @Sendable () -> DocumentMutationResult,
        redo: @escaping @Sendable () -> DocumentMutationResult
    ) {
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.undo = undo
        self.redo = redo
    }
}

public struct TextLayerGateway: Sendable {
    public var textLayerData: @Sendable (Int) -> TextLayerData?
    public var setTextLayer: @Sendable (Int, TextLayerData) -> DocumentMutationResult
    public var clearTextLayerData: @Sendable (Int) -> Void

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
    public var mergeLayerDown: @Sendable (Int) -> DocumentMutationResult

    public init(
        mergeLayerDown: @escaping @Sendable (Int) -> DocumentMutationResult
    ) {
        self.mergeLayerDown = mergeLayerDown
    }
}
