import CoreGraphics
import Foundation
import PrimoBrushDomain
import PrimoBrushFileFormats
import PrimoCoreTypes
import PrimoDocumentDomain

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

public enum FillThresholdMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case opacity
    case color

    public var id: String { rawValue }
}

public struct BrushRuntimeSettings: Equatable, Sendable {
    public var tipKind: BrushTipKind
    public var radius: Double
    public var sizeSpeedSensitivity: Double = 0.0
    public var taperIn: Double = 0.0
    public var taperOut: Double = 0.0
    public var opacity: Double
    public var hardness: Double
    public var roundness: Double
    public var roundnessPressureSensitivity: Double = 0.0
    public var roundnessTiltSensitivity: Double = 0.0
    public var angle: Double
    public var anglePressureSensitivity: Double = 0.0
    public var angleTiltSensitivity: Double = 0.0
    public var angleMode: BrushAngleMode
    public var stampSpacing: Double
    public var spacingJitter: Double
    public var scatterEnabled: Bool = false
    public var scatterMode: BrushScatterMode = .directional
    public var scatterLateral: Double
    public var scatterLinear: Double
    public var count: Int
    public var countJitter: Double
    public var countSizeJitter: Double = 0.0
    public var countOpacityJitter: Double = 0.0
    public var angleJitter: Double
    public var roundnessJitter: Double
    public var textureMode: BrushTextureMode
    public var textureStrength: Double
    public var flow: Double = 1.0
    public var flowPressureSensitivity: Double = 0.0
    public var flowJitter: Double = 0.0
    public var velocityInfluence: Double = 0.0
    public var colorMixingMode: BrushColorMixingMode = .off
    public var wetness: Double = 0.0
    public var wetnessPressureSensitivity: Double = 0.0
    public var opacityPressureSensitivity: Double = 0.0
    public var colorMixStrength: Double = 0.0
    public var smudgeBlurEnabled: Bool = false
    public var smudgeBleed: Double = 0.0
    public var smudgeRadius: Double = 0.0
    public var paintLoad: Double = 1.0
    public var loadPressureSensitivity: Double = 0.0
    public var dualBrushEnabled: Bool = false
    public var dualTipKind: BrushTipKind = .ink
    public var dualScale: Double = 0.72
    public var dualSpacing: Double = 0.26
    public var dualScatter: Double = 0.18
    public var dualAngle: Double = 0.0
    public var dualBlendMode: BrushDualBlendMode = .multiply
    public var grainScale: Double = 1.35
    public var grainContrast: Double = 1.7
    public var paperScale: Double = 0.12
    public var paperStrength: Double = 0.32
    public var paperThreshold: Double = 0.42
    public var flipX: Bool = false
    public var flipY: Bool = false
    public var customTip: BrushTipRaster? = nil
    public var pressureSensitivity: Double
    public var stabilization: Double = 0.0
    public var fillThresholdMode: FillThresholdMode = .opacity
    public var fillOpacityTolerance: Double = 0.0
    public var fillColorTolerance: Double = 0.12
    public var fillExpansion: Int = 0
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var isEraser: Bool = false

    public init(
        tipKind: BrushTipKind,
        radius: Double,
        sizeSpeedSensitivity: Double = 0.0,
        taperIn: Double = 0.0,
        taperOut: Double = 0.0,
        opacity: Double,
        hardness: Double,
        roundness: Double,
        roundnessPressureSensitivity: Double = 0.0,
        roundnessTiltSensitivity: Double = 0.0,
        angle: Double,
        anglePressureSensitivity: Double = 0.0,
        angleTiltSensitivity: Double = 0.0,
        angleMode: BrushAngleMode,
        stampSpacing: Double,
        spacingJitter: Double,
        scatterEnabled: Bool = false,
        scatterMode: BrushScatterMode = .directional,
        scatterLateral: Double,
        scatterLinear: Double,
        count: Int,
        countJitter: Double,
        countSizeJitter: Double = 0.0,
        countOpacityJitter: Double = 0.0,
        angleJitter: Double,
        roundnessJitter: Double,
        textureMode: BrushTextureMode,
        textureStrength: Double,
        flow: Double = 1.0,
        flowPressureSensitivity: Double = 0.0,
        flowJitter: Double = 0.0,
        velocityInfluence: Double = 0.0,
        colorMixingMode: BrushColorMixingMode = .off,
        wetness: Double = 0.0,
        wetnessPressureSensitivity: Double = 0.0,
        opacityPressureSensitivity: Double = 0.0,
        colorMixStrength: Double = 0.0,
        smudgeBlurEnabled: Bool = false,
        smudgeBleed: Double = 0.0,
        smudgeRadius: Double = 0.0,
        paintLoad: Double = 1.0,
        loadPressureSensitivity: Double = 0.0,
        dualBrushEnabled: Bool = false,
        dualTipKind: BrushTipKind = .ink,
        dualScale: Double = 0.72,
        dualSpacing: Double = 0.26,
        dualScatter: Double = 0.18,
        dualAngle: Double = 0.0,
        dualBlendMode: BrushDualBlendMode = .multiply,
        grainScale: Double = 1.35,
        grainContrast: Double = 1.7,
        paperScale: Double = 0.12,
        paperStrength: Double = 0.32,
        paperThreshold: Double = 0.42,
        flipX: Bool = false,
        flipY: Bool = false,
        customTip: BrushTipRaster? = nil,
        pressureSensitivity: Double,
        stabilization: Double = 0.0,
        fillThresholdMode: FillThresholdMode = .opacity,
        fillOpacityTolerance: Double = 0.0,
        fillColorTolerance: Double = 0.12,
        fillExpansion: Int = 0,
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        isEraser: Bool = false
    ) {
        self.tipKind = tipKind
        self.radius = radius
        self.sizeSpeedSensitivity = sizeSpeedSensitivity
        self.taperIn = taperIn
        self.taperOut = taperOut
        self.opacity = opacity
        self.hardness = hardness
        self.roundness = roundness
        self.roundnessPressureSensitivity = roundnessPressureSensitivity
        self.roundnessTiltSensitivity = roundnessTiltSensitivity
        self.angle = angle
        self.anglePressureSensitivity = anglePressureSensitivity
        self.angleTiltSensitivity = angleTiltSensitivity
        self.angleMode = angleMode
        self.stampSpacing = stampSpacing
        self.spacingJitter = spacingJitter
        self.scatterEnabled = scatterEnabled
        self.scatterMode = scatterMode
        self.scatterLateral = scatterLateral
        self.scatterLinear = scatterLinear
        self.count = count
        self.countJitter = countJitter
        self.countSizeJitter = countSizeJitter
        self.countOpacityJitter = countOpacityJitter
        self.angleJitter = angleJitter
        self.roundnessJitter = roundnessJitter
        self.textureMode = textureMode
        self.textureStrength = textureStrength
        self.flow = flow
        self.flowPressureSensitivity = flowPressureSensitivity
        self.flowJitter = flowJitter
        self.velocityInfluence = velocityInfluence
        self.colorMixingMode = colorMixingMode
        self.wetness = wetness
        self.wetnessPressureSensitivity = wetnessPressureSensitivity
        self.opacityPressureSensitivity = opacityPressureSensitivity
        self.colorMixStrength = colorMixStrength
        self.smudgeBlurEnabled = smudgeBlurEnabled
        self.smudgeBleed = smudgeBleed
        self.smudgeRadius = smudgeRadius
        self.paintLoad = paintLoad
        self.loadPressureSensitivity = loadPressureSensitivity
        self.dualBrushEnabled = dualBrushEnabled
        self.dualTipKind = dualTipKind
        self.dualScale = dualScale
        self.dualSpacing = dualSpacing
        self.dualScatter = dualScatter
        self.dualAngle = dualAngle
        self.dualBlendMode = dualBlendMode
        self.grainScale = grainScale
        self.grainContrast = grainContrast
        self.paperScale = paperScale
        self.paperStrength = paperStrength
        self.paperThreshold = paperThreshold
        self.flipX = flipX
        self.flipY = flipY
        self.customTip = customTip
        self.pressureSensitivity = pressureSensitivity
        self.stabilization = stabilization
        self.fillThresholdMode = fillThresholdMode
        self.fillOpacityTolerance = fillOpacityTolerance
        self.fillColorTolerance = fillColorTolerance
        self.fillExpansion = fillExpansion
        self.red = red
        self.green = green
        self.blue = blue
        self.isEraser = isEraser
    }
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

public struct CanvasSelection: Equatable, Sendable {
    public let bounds: CGRect
    public let maskWidth: Int
    public let maskHeight: Int
    public let maskData: Data
    public let mode: SelectionToolMode

    public init(bounds: CGRect, maskWidth: Int, maskHeight: Int, maskData: Data, mode: SelectionToolMode) {
        self.bounds = bounds
        self.maskWidth = maskWidth
        self.maskHeight = maskHeight
        self.maskData = maskData
        self.mode = mode
    }

    public var isEmpty: Bool {
        maskWidth <= 0 || maskHeight <= 0 || maskData.isEmpty || bounds.isNull || bounds.isEmpty
    }
}

public enum LayerProcessingRequest: Equatable, Sendable {
    case gradientMap(GradientMapPreset)
    case hueSaturationBrightness(HueSaturationBrightnessSettings)
    case brightnessContrast(BrightnessContrastSettings)
    case levels(LevelsAdjustmentSettings)
    case toneCurve(ToneCurveSettings)
    case colorBalance(ColorBalanceSettings)
    case threshold(ThresholdSettings)
    case posterize(PosterizeSettings)
    case transform(translation: CGSize, scale: CGFloat, rotationDegrees: Double, selection: CanvasSelection?)
}

public struct TimelapseFrame: Equatable, Sendable {
    public let imageURL: URL
    public let size: CGSize

    public init(imageURL: URL, size: CGSize) {
        self.imageURL = imageURL
        self.size = size
    }
}

public struct LayerPixelRect: Equatable, Sendable {
    public let originX: Int
    public let originY: Int
    public let width: Int
    public let height: Int

    public init(originX: Int, originY: Int, width: Int, height: Int) {
        self.originX = originX
        self.originY = originY
        self.width = width
        self.height = height
    }

    public var isEmpty: Bool { width <= 0 || height <= 0 }
}

public enum TimelapseOperation: Equatable, Sendable {
    case stroke(layerIndex: DocumentLayerIndex, brush: BrushRuntimeSettings, samples: [StylusSample])
    case blurStroke(layerIndex: DocumentLayerIndex, brush: BrushRuntimeSettings, samples: [StylusSample])
    case fill(layerIndex: DocumentLayerIndex, brush: BrushRuntimeSettings, sample: StylusSample)
    case undo
    case redo
    case addLayer(name: String)
    case duplicateLayer(index: DocumentLayerIndex, name: String)
    case deleteLayer(index: DocumentLayerIndex)
    case moveLayer(index: DocumentLayerIndex, destinationIndex: DocumentLayerIndex)
    case createFolder(folderID: DocumentFolderID, name: String, anchorLayerIndex: DocumentLayerIndex?)
    case deleteFolder(folderID: DocumentFolderID)
    case setFolderVisibility(folderID: DocumentFolderID, isVisible: Bool)
    case assignLayerToFolder(index: DocumentLayerIndex, folderID: DocumentFolderID?)
    case setLayerVisibility(index: DocumentLayerIndex, isVisible: Bool)
    case setLayerLocked(index: DocumentLayerIndex, isLocked: Bool)
    case setLayerAlphaLocked(index: DocumentLayerIndex, isAlphaLocked: Bool)
    case setLayerClipped(index: DocumentLayerIndex, isClipped: Bool)
    case setLayerOpacity(index: DocumentLayerIndex, opacity: Double)
    case setLayerBlendMode(index: DocumentLayerIndex, blendMode: LayerBlendMode)
    case replaceLayerPixels(index: DocumentLayerIndex, data: Data)
    case replaceLayerMask(index: DocumentLayerIndex, data: Data)
    case clearLayerMask(index: DocumentLayerIndex)
    case applyLayerMask(index: DocumentLayerIndex)
    case clearLayer(index: DocumentLayerIndex)
    case setPaperStyle(CanvasPaperStyle)
}

public enum TimelapseCaptureSource: Equatable, Sendable {
    case frames([TimelapseFrame])
    case operations([TimelapseOperation])
}

public struct TimelapseCapture: Equatable, Sendable {
    public let canvasSize: CGSize
    public let paperStyle: CanvasPaperStyle
    public let previewImageData: Data?
    public let source: TimelapseCaptureSource
    public let framesPerSecond: Int

    public init(
        canvasSize: CGSize,
        paperStyle: CanvasPaperStyle,
        previewImageData: Data?,
        source: TimelapseCaptureSource,
        framesPerSecond: Int
    ) {
        self.canvasSize = canvasSize
        self.paperStyle = paperStyle
        self.previewImageData = previewImageData
        self.source = source
        self.framesPerSecond = framesPerSecond
    }
}

public struct DocumentQueryGateway: Sendable {
    public var lightweightPresentation: @Sendable () -> PaintDocumentPresentation
    public var presentation: @Sendable () -> PaintDocumentPresentation
    public var compositePixelData: @Sendable () -> Data
    public var pixelDataForLayer: @Sendable (Int) -> Data
    public var consumeDirtyUpdate: @Sendable () -> IncrementalLayerUpdate?

    public init(
        lightweightPresentation: @escaping @Sendable () -> PaintDocumentPresentation,
        presentation: @escaping @Sendable () -> PaintDocumentPresentation,
        compositePixelData: @escaping @Sendable () -> Data,
        pixelDataForLayer: @escaping @Sendable (Int) -> Data,
        consumeDirtyUpdate: @escaping @Sendable () -> IncrementalLayerUpdate?
    ) {
        self.lightweightPresentation = lightweightPresentation
        self.presentation = presentation
        self.compositePixelData = compositePixelData
        self.pixelDataForLayer = pixelDataForLayer
        self.consumeDirtyUpdate = consumeDirtyUpdate
    }
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
    public var endStroke: @Sendable () -> Void
    public var cancelStroke: @Sendable () -> Void
    public var blurStroke: @Sendable ([StylusSample], BrushRuntimeSettings, Int, Bool) -> DocumentMutationResult
    public var endBlurStroke: @Sendable () -> Void
    public var fill: @Sendable (StylusSample, BrushRuntimeSettings) -> DocumentMutationResult
    public var applySoftwareStroke: @Sendable ([StylusSample], BrushRuntimeSettings, Int) -> DocumentMutationResult

    public init(
        beginStroke: @escaping @Sendable (StylusSample, BrushRuntimeSettings) -> Void,
        appendStroke: @escaping @Sendable (StylusSample) -> Void,
        endStroke: @escaping @Sendable () -> Void,
        cancelStroke: @escaping @Sendable () -> Void,
        blurStroke: @escaping @Sendable ([StylusSample], BrushRuntimeSettings, Int, Bool) -> DocumentMutationResult,
        endBlurStroke: @escaping @Sendable () -> Void,
        fill: @escaping @Sendable (StylusSample, BrushRuntimeSettings) -> DocumentMutationResult,
        applySoftwareStroke: @escaping @Sendable ([StylusSample], BrushRuntimeSettings, Int) -> DocumentMutationResult
    ) {
        self.beginStroke = beginStroke
        self.appendStroke = appendStroke
        self.endStroke = endStroke
        self.cancelStroke = cancelStroke
        self.blurStroke = blurStroke
        self.endBlurStroke = endBlurStroke
        self.fill = fill
        self.applySoftwareStroke = applySoftwareStroke
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

public struct DocumentPersistenceGateway: Sendable {
    public var saveProject: @Sendable (URL, CanvasPaperStyle) throws -> Void
    public var loadProject: @Sendable (URL) throws -> LoadedPaintProject
    public var setPaperStyle: @Sendable (CanvasPaperStyle) -> Void
    public var newCanvas: @Sendable (Int, Int) -> Void
    public var prewarmDrawingResources: @Sendable () -> Void

    public init(
        saveProject: @escaping @Sendable (URL, CanvasPaperStyle) throws -> Void,
        loadProject: @escaping @Sendable (URL) throws -> LoadedPaintProject,
        setPaperStyle: @escaping @Sendable (CanvasPaperStyle) -> Void,
        newCanvas: @escaping @Sendable (Int, Int) -> Void,
        prewarmDrawingResources: @escaping @Sendable () -> Void
    ) {
        self.saveProject = saveProject
        self.loadProject = loadProject
        self.setPaperStyle = setPaperStyle
        self.newCanvas = newCanvas
        self.prewarmDrawingResources = prewarmDrawingResources
    }
}

public struct DocumentExportGateway: Sendable {
    public var compositePNGData: @Sendable (CanvasPaperStyle) -> Data?
    public var timelapseCapture: @Sendable () -> TimelapseCapture?

    public init(
        compositePNGData: @escaping @Sendable (CanvasPaperStyle) -> Data?,
        timelapseCapture: @escaping @Sendable () -> TimelapseCapture?
    ) {
        self.compositePNGData = compositePNGData
        self.timelapseCapture = timelapseCapture
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
