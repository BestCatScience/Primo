import CoreGraphics
import Foundation
import Metal
import os
import PrimoBrushDomain
import PrimoBrushFileFormats
import PrimoDocumentContracts
import PrimoDocumentDomain

private struct PrimoMetalCompositeLayerDescriptor {
    let documentIndex: Int32
    let opacity: Float
    let visible: UInt32
    let isClipped: UInt32
    let blendMode: Int32
}

private struct PrimoMetalCompositeRequestDescriptor {
    let canvasWidth: UInt32
    let canvasHeight: UInt32
    let originX: UInt32
    let originY: UInt32
    let outputWidth: UInt32
    let outputHeight: UInt32
    let layerCount: UInt32
    let activeLayerIndex: Int32
    let hasActiveLayerOverride: UInt32
    let includeActiveLayerWhenHidden: UInt32
}

struct PrimoMetalMaskKernelDescriptor {
    let width: UInt32
    let height: UInt32
    let radius: UInt32
}

private struct PrimoMetalColorRangeSelectionDescriptor {
    let width: UInt32
    let height: UInt32
    let red: UInt32
    let green: UInt32
    let blue: UInt32
    let tolerance: Float
    let minimumAlpha: Float
}

struct PrimoMetalAutoSelectionDescriptor {
    let width: UInt32
    let height: UInt32
    let seedX: UInt32
    let seedY: UInt32
    let thresholdMode: UInt32
    let expansion: UInt32
    let tolerance: Float
    let seedRed: Float
    let seedGreen: Float
    let seedBlue: Float
    let seedAlpha: Float
}

struct PrimoMetalLassoSelectionDescriptor {
    let width: UInt32
    let height: UInt32
    let pointCount: UInt32
    let padding0: UInt32
}

struct PrimoMetalSelectionPlacementDescriptor {
    let canvasWidth: UInt32
    let canvasHeight: UInt32
    let maskWidth: UInt32
    let maskHeight: UInt32
    let originX: Int32
    let originY: Int32
}

struct PrimoMetalSelectionCombineDescriptor {
    let width: UInt32
    let height: UInt32
    let mode: UInt32
    let padding0: UInt32
}

struct PrimoMetalSelectionCropDescriptor {
    let sourceWidth: UInt32
    let sourceHeight: UInt32
    let originX: UInt32
    let originY: UInt32
    let cropWidth: UInt32
    let cropHeight: UInt32
    let padding0: UInt32
    let padding1: UInt32
}

struct PrimoMetalAlphaPreserveDescriptor {
    let width: UInt32
    let height: UInt32
}

private struct PrimoMetalSelectionOverlayDescriptor {
    let width: UInt32
    let height: UInt32
    let red: UInt32
    let green: UInt32
    let blue: UInt32
    let maximumAlpha: Float
}

private struct PrimoMetalEyedropperLoupeDescriptor {
    let sourceWidth: UInt32
    let sourceHeight: UInt32
    let centerX: Int32
    let centerY: Int32
    let gridSize: UInt32
    let blendWithPaper: UInt32
    let paperRed: Float
    let paperGreen: Float
    let paperBlue: Float
}

private struct PrimoMetalPaperCompositeDescriptor {
    let width: UInt32
    let height: UInt32
    let paperRed: Float
    let paperGreen: Float
    let paperBlue: Float
    let paperAlpha: Float
    let checkerboard: UInt32
}

private struct PrimoMetalLayerMaskApplyDescriptor {
    let width: UInt32
    let height: UInt32
}

struct PrimoMetalInpaintCompositeDescriptor {
    let canvasWidth: UInt32
    let canvasHeight: UInt32
    let cropWidth: UInt32
    let cropHeight: UInt32
    let originX: Int32
    let originY: Int32
}

struct PrimoMetalInpaintCropDescriptor {
    let canvasWidth: UInt32
    let canvasHeight: UInt32
    let cropWidth: UInt32
    let cropHeight: UInt32
    let originX: Int32
    let originY: Int32
}

public struct PrimoMetalInpaintCropPayload: Sendable, Equatable {
    public let pixelData: Data
    public let width: Int
    public let height: Int
    public let originX: Int
    public let originY: Int
    public let selectionMask: [UInt8]

    public init(
        pixelData: Data,
        width: Int,
        height: Int,
        originX: Int,
        originY: Int,
        selectionMask: [UInt8]
    ) {
        self.pixelData = pixelData
        self.width = width
        self.height = height
        self.originX = originX
        self.originY = originY
        self.selectionMask = selectionMask
    }
}

public enum PrimoMetalSelectionCombineMode: Sendable {
    case add
    case subtract
}

public struct PrimoMetalCroppedSelectionMask: Sendable, Equatable {
    public let bounds: CGRect
    public let maskData: Data
    public let maskWidth: Int
    public let maskHeight: Int

    public init(bounds: CGRect, maskData: Data, maskWidth: Int, maskHeight: Int) {
        self.bounds = bounds
        self.maskData = maskData
        self.maskWidth = maskWidth
        self.maskHeight = maskHeight
    }
}

struct PrimoMetalStrokeSampleDescriptor: Equatable {
    let x: Float
    let y: Float
    let pressure: Float
    let progress: Float
}

private struct PrimoMetalRawStrokeSample {
    let x: Float
    let y: Float
    let pressure: Float
    let altitude: Float
    let azimuth: Float
    let timestamp: Float
}

private struct PrimoMetalStrokeBrushDescriptor {
    let radius: Float
    let pressureSensitivity: Float
    let taperIn: Float
    let taperOut: Float
    let opacity: Float
    let flow: Float
    let hardness: Float
    let opacityPressureSensitivity: Float
    let flowPressureSensitivity: Float
    let grainScale: Float
    let grainContrast: Float
    let paperScale: Float
    let paperStrength: Float
    let paperThreshold: Float
    let textureStrength: Float
    let wetness: Float
    let colorMixStrength: Float
    let smudgeBleed: Float
    let smudgeRadius: Float
    let paintLoad: Float
    let loadPressureSensitivity: Float
    let smudgeLength: Float
    let colorRate: Float
    let red: Float
    let green: Float
    let blue: Float
    let scatterLateral: Float
    let scatterLinear: Float
    let count: Float
    let countJitter: Float
    let countSizeJitter: Float
    let countOpacityJitter: Float
    let dualScale: Float
    let dualSpacing: Float
    let dualScatter: Float
    let customTipWidth: UInt32
    let customTipHeight: UInt32
    let isEraser: UInt32
    let isPencil: UInt32
    let isOil: UInt32
    let isAirbrush: UInt32
    let dualBrushEnabled: UInt32
    let customTipEnabled: UInt32
    let scatterMode: UInt32
    let textureMode: UInt32
    let dualBlendMode: UInt32
    let colorMixingMode: UInt32
    let smudgeMode: UInt32
}

private struct PrimoMetalColorSmudgeDabDescriptor {
    let canvasWidth: UInt32
    let canvasHeight: UInt32
    let rectOriginX: UInt32
    let rectOriginY: UInt32
    let rectWidth: UInt32
    let rectHeight: UInt32
    let centerX: Float
    let centerY: Float
    let previousCenterX: Float
    let previousCenterY: Float
    let pressure: Float
    let progress: Float
    let radius: Float
}

private struct PrimoMetalStrokePreprocessDescriptor {
    let sampleCount: UInt32
    let canvasWidth: UInt32
    let canvasHeight: UInt32
    let radius: Float
    let pressureSensitivity: Float
    let taperIn: Float
    let taperOut: Float
    let hardness: Float
    let scatterLateral: Float
    let scatterLinear: Float
    let scatterEnabled: UInt32
    let isAirbrush: UInt32
}

private struct PrimoMetalStrokePreprocessSummary {
    let effectiveSampleCount: UInt32
    let dirtyOriginX: Int32
    let dirtyOriginY: Int32
    let dirtyWidth: UInt32
    let dirtyHeight: UInt32
}

private struct PrimoMetalSmudgeDabGenerationDescriptor {
    let sampleCount: UInt32
    let canvasWidth: UInt32
    let canvasHeight: UInt32
    let stampSpacing: Float
}

private struct PrimoMetalSmudgeDabCountSummary {
    let dabCount: UInt32
}

private struct PrimoMetalSmudgeDabGenerationSummary {
    let dabCount: UInt32
    let dirtyOriginX: Int32
    let dirtyOriginY: Int32
    let dirtyWidth: UInt32
    let dirtyHeight: UInt32
}

private struct PrimoMetalColorSmudgeDab {
    let center: CGPoint
    let radius: CGFloat
    let progress: CGFloat
    let sample: StylusSample
    let destinationRect: CGRect
}

private struct PrimoMetalStrokeRasterRequestDescriptor {
    let canvasWidth: UInt32
    let canvasHeight: UInt32
    let originX: UInt32
    let originY: UInt32
    let rectWidth: UInt32
    let rectHeight: UInt32
    let sampleCount: UInt32
    let inputSampleCount: UInt32
    let tileSize: UInt32
    let tileColumns: UInt32
    let tileRows: UInt32
    let tileCount: UInt32
    let maxPrimitiveIndexCount: UInt32
    let prefixBlockSize: UInt32
}

private struct PrimoMetalStrokePrimitiveDescriptor {
    let startX: Float
    let startY: Float
    let endX: Float
    let endY: Float
    let startPressure: Float
    let endPressure: Float
    let startProgress: Float
    let endProgress: Float
    let maxRadius: Float
    let isSegment: UInt32
    let padding0: UInt32
    let padding1: UInt32
}

private struct PrimoMetalStrokeTileRangeDescriptor {
    let startIndex: UInt32
    let primitiveCount: UInt32
}

private struct PrimoMetalStrokeRectCopyDescriptor {
    let canvasWidth: UInt32
    let canvasHeight: UInt32
    let originX: UInt32
    let originY: UInt32
    let rectWidth: UInt32
    let rectHeight: UInt32
}

private struct PrimoMetalStrokePrefixDescriptor {
    let elementCount: UInt32
    let blockSize: UInt32
}

public enum PrimoMetalStrokeExecutionMode: Equatable, Sendable {
    case interactive
    case commit
    case previewAdopt
}

public struct PrimoMetalStrokeExecutionRequest: Sendable {
    public let basePixelData: Data
    public let baseBufferHandle: MetalBufferHandle?
    public let canvasWidth: Int
    public let canvasHeight: Int
    public let samples: [StylusSample]
    public let brush: BrushRuntimeSettings
    public let mode: PrimoMetalStrokeExecutionMode
    public let snapshotRevision: Int?
    public let activeLayerIndex: Int?

    public init(
        basePixelData: Data,
        baseBufferHandle: MetalBufferHandle? = nil,
        canvasWidth: Int,
        canvasHeight: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        mode: PrimoMetalStrokeExecutionMode,
        snapshotRevision: Int?,
        activeLayerIndex: Int?
    ) {
        self.basePixelData = basePixelData
        self.baseBufferHandle = baseBufferHandle
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.samples = samples
        self.brush = brush
        self.mode = mode
        self.snapshotRevision = snapshotRevision
        self.activeLayerIndex = activeLayerIndex
    }
}

public struct PrimoMetalStrokeExecutionResult: Sendable {
    public let pixelData: Data
    public let dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    public let gpuBufferHandle: MetalBufferHandle?
    public let rectPixelData: Data?

    public init(
        pixelData: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int),
        gpuBufferHandle: MetalBufferHandle? = nil,
        rectPixelData: Data?
    ) {
        self.pixelData = pixelData
        self.dirtyRect = dirtyRect
        self.gpuBufferHandle = gpuBufferHandle
        self.rectPixelData = rectPixelData
    }
}

public struct PrimoMetalStrokeMutationResult: Sendable {
    public let dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    public let gpuBufferHandle: MetalBufferHandle?
    public let rectPixelData: Data?

    public init(
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int),
        gpuBufferHandle: MetalBufferHandle? = nil,
        rectPixelData: Data?
    ) {
        self.dirtyRect = dirtyRect
        self.gpuBufferHandle = gpuBufferHandle
        self.rectPixelData = rectPixelData
    }
}

struct PrimoMetalStrokeBinningDebugSummary: Sendable, Equatable {
    let primitiveCount: Int
    let tileCount: Int
    let totalPrimitiveReferences: Int
    let monotonicTileOffsets: Bool
    let primitiveIndexBoundsValid: Bool
}

private struct PrimoMetalStrokeDirtyRect: Equatable {
    let originX: Int
    let originY: Int
    let width: Int
    let height: Int
}

private struct PrimoMetalBufferPair {
    var current: MTLBuffer
    var scratch: MTLBuffer
}

public final class PrimoMetalDocumentProcessingClient: @unchecked Sendable {
    public static let shared = PrimoMetalDocumentProcessingClient()

    private struct SnapshotLayerSignature: Equatable {
        let index: Int
        let opacity: Float
        let visible: Bool
        let isClipped: Bool
        let blendMode: LayerBlendMode
        let gpuHandleID: UUID?
        let pixelStorageIdentity: UInt
    }

    private struct SnapshotTextureSignature: Equatable {
        let revision: Int
        let width: Int
        let height: Int
        let transferKind: MetalSnapshotTransferKind
        let compositeStorageIdentity: UInt
        let layers: [SnapshotLayerSignature]
    }

    private struct CachedBufferResource {
        let width: Int
        let height: Int
        let bytesPerRow: Int
        let buffer: MTLBuffer
    }

    private struct BrushTipCacheKey: Hashable {
        let width: Int
        let height: Int
        let digest: Int
    }

    private struct StrokeExecutionCache {
        let width: Int
        let height: Int
        let baseSnapshotRevision: Int?
        let activeLayerIndex: Int?
        let brush: BrushRuntimeSettings
        let previewSamples: [PrimoMetalStrokeSampleDescriptor]
        let committableSamples: [PrimoMetalStrokeSampleDescriptor]
        let dirtyRect: PrimoMetalStrokeDirtyRect?
        let rectPixelData: Data?
        var buffers: PrimoMetalBufferPair
        var lastOutputValid: Bool
    }

    private struct StrokeBinningResources {
        let primitiveBuffer: MTLBuffer
        let tileRangeBuffer: MTLBuffer
        let primitiveIndexBuffer: MTLBuffer
        let requestDescriptor: PrimoMetalStrokeRasterRequestDescriptor
    }

    private struct StrokeExecutionContext {
        let buffers: PrimoMetalBufferPair
        let shouldAdoptCachedOutput: Bool
        let cachedDirtyRect: PrimoMetalStrokeDirtyRect?
        let cachedRectPixelData: Data?
    }

    private static let logger = Logger(subsystem: "com.primo.modules", category: "MetalRuntime")
    private static let strokeTileSize = 32
    private static let strokePrefixBlockSize = 256

    private let cacheLock = NSRecursiveLock()
    let device: MTLDevice?
    let commandQueue: MTLCommandQueue?
    let library: MTLLibrary?
    let compositePipeline: MTLComputePipelineState?
    let invertMaskPipeline: MTLComputePipelineState?
    let dilateMaskPipeline: MTLComputePipelineState?
    let erodeMaskPipeline: MTLComputePipelineState?
    let featherHorizontalPipeline: MTLComputePipelineState?
    let featherVerticalPipeline: MTLComputePipelineState?
    let colorRangePipeline: MTLComputePipelineState?
    let autoSelectionEligibilityPipeline: MTLComputePipelineState?
    let lassoSelectionPipeline: MTLComputePipelineState?
    let selectionPlacementPipeline: MTLComputePipelineState?
    let selectionCombinePipeline: MTLComputePipelineState?
    let selectionBoundsPipeline: MTLComputePipelineState?
    let selectionCropPipeline: MTLComputePipelineState?
    let selectionOverlayPipeline: MTLComputePipelineState?
    let eyedropperLoupePipeline: MTLComputePipelineState?
    let paperCompositePipeline: MTLComputePipelineState?
    let applyLayerMaskPipeline: MTLComputePipelineState?
    let alphaMaskPipeline: MTLComputePipelineState?
    let layerProcessingPipeline: MTLComputePipelineState?
    let layerTransformPipeline: MTLComputePipelineState?
    let quadLayerTransformPipeline: MTLComputePipelineState?
    let quadMaskTransformPipeline: MTLComputePipelineState?
    let fillEligibilityPipeline: MTLComputePipelineState?
    let fillPropagationPipeline: MTLComputePipelineState?
    let fillExpansionPipeline: MTLComputePipelineState?
    let fillComposePipeline: MTLComputePipelineState?
    let blurHorizontalPipeline: MTLComputePipelineState?
    let blurVerticalPipeline: MTLComputePipelineState?
    let blurBlendPipeline: MTLComputePipelineState?
    let textMaskComposePipeline: MTLComputePipelineState?
    let scaleRGBAPipeline: MTLComputePipelineState?
    let scaleMaskPipeline: MTLComputePipelineState?
    let translateRGBAPipeline: MTLComputePipelineState?
    let translateMaskPipeline: MTLComputePipelineState?
    let inpaintCropRGBAPipeline: MTLComputePipelineState?
    let inpaintCropMaskPipeline: MTLComputePipelineState?
    let inpaintCompositePipeline: MTLComputePipelineState?
    let alphaPreservePipeline: MTLComputePipelineState?
    let strokePreprocessPipeline: MTLComputePipelineState?
    let smudgeDabCountPipeline: MTLComputePipelineState?
    let smudgeDabGenerationPipeline: MTLComputePipelineState?
    let strokePrimitiveGenerationPipeline: MTLComputePipelineState?
    let strokeTileCountPipeline: MTLComputePipelineState?
    let strokePrefixScanPipeline: MTLComputePipelineState?
    let strokePrefixBlockScanPipeline: MTLComputePipelineState?
    let strokePrefixAddPipeline: MTLComputePipelineState?
    let strokeTileRangePipeline: MTLComputePipelineState?
    let strokeCursorInitPipeline: MTLComputePipelineState?
    let strokePrimitiveScatterPipeline: MTLComputePipelineState?
    let strokeRasterPipeline: MTLComputePipelineState?
    let strokeColorSmudgePipeline: MTLComputePipelineState?
    let copyStrokeRectPipeline: MTLComputePipelineState?

    private var cachedSignature: SnapshotTextureSignature?
    private var cachedLayerTexture: MTLTexture?
    private var cachedStrokeExecution: StrokeExecutionCache?
    private var cachedBuffers: [UUID: CachedBufferResource] = [:]
    private var cachedScaledBrushTips: [BrushTipCacheKey: BrushTipRaster] = [:]

    public init() {
        let device = MTLCreateSystemDefaultDevice()
        self.device = device
        self.commandQueue = device?.makeCommandQueue()
        self.library = device?.makeDefaultLibrary()
        self.compositePipeline = Self.makePipeline(device: device, library: library, functionName: "compositePreviewKernel")
        self.invertMaskPipeline = Self.makePipeline(device: device, library: library, functionName: "invertMaskKernel")
        self.dilateMaskPipeline = Self.makePipeline(device: device, library: library, functionName: "dilateMaskKernel")
        self.erodeMaskPipeline = Self.makePipeline(device: device, library: library, functionName: "erodeMaskKernel")
        self.featherHorizontalPipeline = Self.makePipeline(device: device, library: library, functionName: "featherHorizontalKernel")
        self.featherVerticalPipeline = Self.makePipeline(device: device, library: library, functionName: "featherVerticalKernel")
        self.colorRangePipeline = Self.makePipeline(device: device, library: library, functionName: "colorRangeSelectionKernel")
        self.autoSelectionEligibilityPipeline = Self.makePipeline(device: device, library: library, functionName: "autoSelectionEligibilityKernel")
        self.lassoSelectionPipeline = Self.makePipeline(device: device, library: library, functionName: "lassoSelectionKernel")
        self.selectionPlacementPipeline = Self.makePipeline(device: device, library: library, functionName: "selectionPlacementKernel")
        self.selectionCombinePipeline = Self.makePipeline(device: device, library: library, functionName: "selectionCombineKernel")
        self.selectionBoundsPipeline = Self.makePipeline(device: device, library: library, functionName: "selectionBoundsKernel")
        self.selectionCropPipeline = Self.makePipeline(device: device, library: library, functionName: "selectionCropKernel")
        self.selectionOverlayPipeline = Self.makePipeline(device: device, library: library, functionName: "selectionOverlayKernel")
        self.eyedropperLoupePipeline = Self.makePipeline(device: device, library: library, functionName: "eyedropperLoupeKernel")
        self.paperCompositePipeline = Self.makePipeline(device: device, library: library, functionName: "paperCompositeKernel")
        self.applyLayerMaskPipeline = Self.makePipeline(device: device, library: library, functionName: "applyLayerMaskKernel")
        self.alphaMaskPipeline = Self.makePipeline(device: device, library: library, functionName: "alphaMaskKernel")
        self.layerProcessingPipeline = Self.makePipeline(device: device, library: library, functionName: "layerProcessingKernel")
        self.layerTransformPipeline = Self.makePipeline(device: device, library: library, functionName: "layerTransformKernel")
        self.quadLayerTransformPipeline = Self.makePipeline(device: device, library: library, functionName: "quadLayerTransformKernel")
        self.quadMaskTransformPipeline = Self.makePipeline(device: device, library: library, functionName: "quadMaskTransformKernel")
        self.fillEligibilityPipeline = Self.makePipeline(device: device, library: library, functionName: "fillEligibilityKernel")
        self.fillPropagationPipeline = Self.makePipeline(device: device, library: library, functionName: "fillPropagationKernel")
        self.fillExpansionPipeline = Self.makePipeline(device: device, library: library, functionName: "fillExpansionKernel")
        self.fillComposePipeline = Self.makePipeline(device: device, library: library, functionName: "fillComposeKernel")
        self.blurHorizontalPipeline = Self.makePipeline(device: device, library: library, functionName: "blurHorizontalKernel")
        self.blurVerticalPipeline = Self.makePipeline(device: device, library: library, functionName: "blurVerticalKernel")
        self.blurBlendPipeline = Self.makePipeline(device: device, library: library, functionName: "blurBlendKernel")
        self.textMaskComposePipeline = Self.makePipeline(device: device, library: library, functionName: "textMaskComposeKernel")
        self.scaleRGBAPipeline = Self.makePipeline(device: device, library: library, functionName: "scaleRGBAKernel")
        self.scaleMaskPipeline = Self.makePipeline(device: device, library: library, functionName: "scaleMaskKernel")
        self.translateRGBAPipeline = Self.makePipeline(device: device, library: library, functionName: "translateRGBAKernel")
        self.translateMaskPipeline = Self.makePipeline(device: device, library: library, functionName: "translateMaskKernel")
        self.inpaintCropRGBAPipeline = Self.makePipeline(device: device, library: library, functionName: "inpaintCropRGBAKernel")
        self.inpaintCropMaskPipeline = Self.makePipeline(device: device, library: library, functionName: "inpaintCropMaskKernel")
        self.inpaintCompositePipeline = Self.makePipeline(device: device, library: library, functionName: "inpaintCompositeKernel")
        self.alphaPreservePipeline = Self.makePipeline(device: device, library: library, functionName: "alphaPreserveKernel")
        self.strokePreprocessPipeline = Self.makePipeline(device: device, library: library, functionName: "strokePreprocessKernel")
        self.smudgeDabCountPipeline = Self.makePipeline(device: device, library: library, functionName: "smudgeDabCountKernel")
        self.smudgeDabGenerationPipeline = Self.makePipeline(device: device, library: library, functionName: "smudgeDabGenerationKernel")
        self.strokePrimitiveGenerationPipeline = Self.makePipeline(device: device, library: library, functionName: "strokePrimitiveGenerationKernel")
        self.strokeTileCountPipeline = Self.makePipeline(device: device, library: library, functionName: "strokeTileCountKernel")
        self.strokePrefixScanPipeline = Self.makePipeline(device: device, library: library, functionName: "strokePrefixScanKernel")
        self.strokePrefixBlockScanPipeline = Self.makePipeline(device: device, library: library, functionName: "strokePrefixBlockScanKernel")
        self.strokePrefixAddPipeline = Self.makePipeline(device: device, library: library, functionName: "strokePrefixAddKernel")
        self.strokeTileRangePipeline = Self.makePipeline(device: device, library: library, functionName: "strokeTileRangeKernel")
        self.strokeCursorInitPipeline = Self.makePipeline(device: device, library: library, functionName: "strokeCursorInitKernel")
        self.strokePrimitiveScatterPipeline = Self.makePipeline(device: device, library: library, functionName: "strokePrimitiveScatterKernel")
        self.strokeRasterPipeline = Self.makePipeline(device: device, library: library, functionName: "strokeRasterKernel")
        self.strokeColorSmudgePipeline = Self.makePipeline(device: device, library: library, functionName: "strokeColorSmudgeKernel")
        self.copyStrokeRectPipeline = Self.makePipeline(device: device, library: library, functionName: "copyStrokeRectKernel")
    }

    public var isAvailable: Bool {
        device != nil &&
        commandQueue != nil &&
        compositePipeline != nil &&
        invertMaskPipeline != nil &&
        dilateMaskPipeline != nil &&
        erodeMaskPipeline != nil &&
        featherHorizontalPipeline != nil &&
        featherVerticalPipeline != nil &&
        colorRangePipeline != nil &&
        autoSelectionEligibilityPipeline != nil &&
        lassoSelectionPipeline != nil &&
        selectionPlacementPipeline != nil &&
        selectionCombinePipeline != nil &&
        selectionBoundsPipeline != nil &&
        selectionCropPipeline != nil &&
        selectionOverlayPipeline != nil &&
        eyedropperLoupePipeline != nil &&
        paperCompositePipeline != nil &&
        applyLayerMaskPipeline != nil &&
        alphaMaskPipeline != nil &&
        layerProcessingPipeline != nil &&
        layerTransformPipeline != nil &&
        quadLayerTransformPipeline != nil &&
        quadMaskTransformPipeline != nil &&
        fillEligibilityPipeline != nil &&
        fillPropagationPipeline != nil &&
        fillExpansionPipeline != nil &&
        fillComposePipeline != nil &&
        blurHorizontalPipeline != nil &&
        blurVerticalPipeline != nil &&
        blurBlendPipeline != nil &&
        textMaskComposePipeline != nil &&
        scaleRGBAPipeline != nil &&
        scaleMaskPipeline != nil &&
        translateRGBAPipeline != nil &&
        translateMaskPipeline != nil &&
        inpaintCropRGBAPipeline != nil &&
        inpaintCropMaskPipeline != nil &&
        inpaintCompositePipeline != nil &&
        alphaPreservePipeline != nil &&
        strokePreprocessPipeline != nil &&
        smudgeDabCountPipeline != nil &&
        smudgeDabGenerationPipeline != nil &&
        strokePrimitiveGenerationPipeline != nil &&
        strokeTileCountPipeline != nil &&
        strokePrefixScanPipeline != nil &&
        strokePrefixBlockScanPipeline != nil &&
        strokePrefixAddPipeline != nil &&
        strokeTileRangePipeline != nil &&
        strokeCursorInitPipeline != nil &&
        strokePrimitiveScatterPipeline != nil &&
        strokeRasterPipeline != nil &&
        strokeColorSmudgePipeline != nil &&
        copyStrokeRectPipeline != nil
    }

    public func resetStrokeExecutionSession() {
        withCacheLock {
            cachedStrokeExecution = nil
        }
    }

    public func releaseBufferHandle(_ handle: MetalBufferHandle?) {
        guard let handle else { return }
        _ = withCacheLock {
            cachedBuffers.removeValue(forKey: handle.id)
        }
    }

    public func materializedPixelData(for handle: MetalBufferHandle) -> Data? {
        guard let resource = cachedBufferResource(for: handle) else { return nil }
        return bytes(from: resource.buffer, count: resource.bytesPerRow * resource.height)
    }

    public func populateTexture(
        _ texture: MTLTexture,
        from handle: MetalBufferHandle,
        sourceOriginX: Int = 0,
        sourceOriginY: Int = 0,
        destinationOriginX: Int = 0,
        destinationOriginY: Int = 0,
        width: Int? = nil,
        height: Int? = nil
    ) -> Bool {
        guard let resource = cachedBufferResource(for: handle) else { return false }
        let copyWidth = min(width ?? resource.width, resource.width - sourceOriginX)
        let copyHeight = min(height ?? resource.height, resource.height - sourceOriginY)
        guard copyWidth > 0, copyHeight > 0 else { return false }
        let byteOffset = (sourceOriginY * resource.bytesPerRow) + (sourceOriginX * 4)
        let pointer = resource.buffer.contents().advanced(by: byteOffset)
        texture.replace(
            region: MTLRegionMake2D(destinationOriginX, destinationOriginY, copyWidth, copyHeight),
            mipmapLevel: 0,
            withBytes: pointer,
            bytesPerRow: resource.bytesPerRow
        )
        return true
    }

    public func makeBufferHandle(
        width: Int,
        height: Int,
        bytesPerRow: Int,
        buffer: MTLBuffer
    ) -> MetalBufferHandle {
        let handle = MetalBufferHandle(width: width, height: height, bytesPerRow: bytesPerRow)
        withCacheLock {
            cachedBuffers[handle.id] = CachedBufferResource(
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                buffer: buffer
            )
        }
        return handle
    }

    private func cachedBufferResource(for handle: MetalBufferHandle) -> CachedBufferResource? {
        withCacheLock {
            cachedBuffers[handle.id]
        }
    }

    func rgbaBytes(from handle: MetalBufferHandle, offset: Int, expectedCount: Int) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)? {
        guard
            offset >= 0,
            offset + 3 < expectedCount,
            handle.bytesPerRow * handle.height == expectedCount,
            let resource = cachedBufferResource(for: handle)
        else {
            return nil
        }
        let bytes = resource.buffer.contents().assumingMemoryBound(to: UInt8.self)
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
    }

    private func withCacheLock<T>(_ work: () throws -> T) rethrows -> T {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return try work()
    }

    public func selectionOverlayRGBA(
        maskData: Data,
        width: Int,
        height: Int,
        red: UInt8 = 91,
        green: UInt8 = 181,
        blue: UInt8 = 255,
        maximumAlpha: Float = 96.0 / 255.0
    ) -> Data? {
        guard
            width > 0,
            height > 0,
            maskData.count == width * height,
            let commandQueue,
            let pipeline = selectionOverlayPipeline,
            let sourceBuffer = makeBuffer(maskData),
            let outputBuffer = device?.makeBuffer(length: width * height * 4, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalSelectionOverlayDescriptor(
                    width: UInt32(width),
                    height: UInt32(height),
                    red: UInt32(red),
                    green: UInt32(green),
                    blue: UInt32(blue),
                    maximumAlpha: maximumAlpha
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: width, height: height)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return bytes(from: outputBuffer, count: width * height * 4)
    }

    public func eyedropperLoupeRGBA(
        sourcePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        gridSize: Int,
        paperStyle: CanvasPaperStyle,
        blendWithPaper: Bool
    ) -> Data? {
        guard
            gridSize > 0,
            canvasWidth > 0,
            canvasHeight > 0,
            sourcePixelData.count == canvasWidth * canvasHeight * 4,
            let commandQueue,
            let pipeline = eyedropperLoupePipeline,
            let sourceBuffer = makeBuffer(sourcePixelData),
            let outputBuffer = device?.makeBuffer(length: gridSize * gridSize * 4, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalEyedropperLoupeDescriptor(
                    sourceWidth: UInt32(canvasWidth),
                    sourceHeight: UInt32(canvasHeight),
                    centerX: Int32(centerX),
                    centerY: Int32(centerY),
                    gridSize: UInt32(gridSize),
                    blendWithPaper: blendWithPaper ? 1 : 0,
                    paperRed: paperStyle.red,
                    paperGreen: paperStyle.green,
                    paperBlue: paperStyle.blue
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: gridSize, height: gridSize)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return bytes(from: outputBuffer, count: gridSize * gridSize * 4)
    }

    public func compositedPaperPreviewRGBA(
        pixelData: Data,
        width: Int,
        height: Int,
        paperStyle: CanvasPaperStyle
    ) -> Data? {
        guard
            width > 0,
            height > 0,
            pixelData.count == width * height * 4,
            let commandQueue,
            let pipeline = paperCompositePipeline,
            let sourceBuffer = makeBuffer(pixelData),
            let outputBuffer = device?.makeBuffer(length: pixelData.count, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalPaperCompositeDescriptor(
                    width: UInt32(width),
                    height: UInt32(height),
                    paperRed: paperStyle.red,
                    paperGreen: paperStyle.green,
                    paperBlue: paperStyle.blue,
                    paperAlpha: paperStyle.alpha,
                    checkerboard: paperStyle.isTransparent ? 1 : 0
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: width, height: height)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return bytes(from: outputBuffer, count: pixelData.count)
    }

    public func invertMask(_ source: [UInt8]) -> [UInt8]? {
        mutateMask(source, pipeline: invertMaskPipeline, radius: 0)
    }

    public func expandedMask(_ source: [UInt8], width: Int, height: Int, expansion: Int) -> [UInt8]? {
        iterateMask(source, width: width, height: height, iterations: expansion, pipeline: dilateMaskPipeline)
    }

    public func contractedMask(_ source: [UInt8], width: Int, height: Int, contraction: Int) -> [UInt8]? {
        iterateMask(source, width: width, height: height, iterations: contraction, pipeline: erodeMaskPipeline)
    }

    public func featheredMask(_ source: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8]? {
        guard radius > 0 else { return source }
        guard
            let device,
            let commandQueue,
            let horizontalPipeline = featherHorizontalPipeline,
            let verticalPipeline = featherVerticalPipeline,
            let sourceBuffer = makeBuffer(source),
            let temporary = device.makeBuffer(length: source.count * MemoryLayout<Float>.stride, options: .storageModeShared),
            let outputBuffer = device.makeBuffer(length: source.count, options: .storageModeShared),
            let requestBuffer = makeBuffer(
                PrimoMetalMaskKernelDescriptor(
                    width: UInt32(width),
                    height: UInt32(height),
                    radius: UInt32(radius)
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let horizontalEncoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        horizontalEncoder.setComputePipelineState(horizontalPipeline)
        horizontalEncoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        horizontalEncoder.setBuffer(temporary, offset: 0, index: 1)
        horizontalEncoder.setBuffer(requestBuffer, offset: 0, index: 2)
        dispatch2D(encoder: horizontalEncoder, pipeline: horizontalPipeline, width: width, height: height)
        horizontalEncoder.endEncoding()

        guard let verticalEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        verticalEncoder.setComputePipelineState(verticalPipeline)
        verticalEncoder.setBuffer(temporary, offset: 0, index: 0)
        verticalEncoder.setBuffer(outputBuffer, offset: 0, index: 1)
        verticalEncoder.setBuffer(requestBuffer, offset: 0, index: 2)
        dispatch2D(encoder: verticalEncoder, pipeline: verticalPipeline, width: width, height: height)
        verticalEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return byteArray(from: outputBuffer, count: source.count)
    }

    public func colorRangeSelection(
        pixelData: Data,
        width: Int,
        height: Int,
        request: ColorRangeSelectionRequest
    ) -> [UInt8]? {
        guard
            let commandQueue,
            let pipeline = colorRangePipeline,
            let pixelBuffer = makeBuffer(pixelData),
            let outputBuffer = device?.makeBuffer(length: width * height, options: .storageModeShared),
            let requestBuffer = makeBuffer(
                PrimoMetalColorRangeSelectionDescriptor(
                    width: UInt32(width),
                    height: UInt32(height),
                    red: UInt32(request.red),
                    green: UInt32(request.green),
                    blue: UInt32(request.blue),
                    tolerance: Float(min(max(request.tolerance, 0.0), 1.0)),
                    minimumAlpha: Float(min(max(request.minimumAlpha, 0.0), 1.0))
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(pixelBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(requestBuffer, offset: 0, index: 2)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: width, height: height)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return byteArray(from: outputBuffer, count: width * height)
    }

    public func lassoSelection(
        points: [CGPoint],
        canvasWidth: Int,
        canvasHeight: Int
    ) -> [UInt8]? {
        guard
            canvasWidth > 0,
            canvasHeight > 0,
            points.count >= 3,
            let commandQueue,
            let pipeline = lassoSelectionPipeline,
            let outputBuffer = device?.makeBuffer(length: canvasWidth * canvasHeight, options: .storageModeShared)
        else {
            return nil
        }

        let descriptors = points.map { SIMD2<Float>(Float($0.x), Float($0.y)) }
        guard
            let pointBuffer = makeBuffer(descriptors),
            let requestBuffer = makeBuffer(
                PrimoMetalLassoSelectionDescriptor(
                    width: UInt32(canvasWidth),
                    height: UInt32(canvasHeight),
                    pointCount: UInt32(descriptors.count),
                    padding0: 0
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(pointBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(requestBuffer, offset: 0, index: 2)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: canvasWidth, height: canvasHeight)
        encoder.endEncoding()
        commandBuffer.commit()
       commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return byteArray(from: outputBuffer, count: canvasWidth * canvasHeight)
    }

    public func expandedSelectionMask(
        maskData: Data,
        maskWidth: Int,
        maskHeight: Int,
        originX: Int,
        originY: Int,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> [UInt8]? {
        guard
            canvasWidth > 0,
            canvasHeight > 0,
            maskWidth > 0,
            maskHeight > 0,
            maskData.count == maskWidth * maskHeight,
            let commandQueue,
            let pipeline = selectionPlacementPipeline,
            let inputBuffer = makeBuffer(maskData),
            let outputBuffer = device?.makeBuffer(length: canvasWidth * canvasHeight, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalSelectionPlacementDescriptor(
                    canvasWidth: UInt32(canvasWidth),
                    canvasHeight: UInt32(canvasHeight),
                    maskWidth: UInt32(maskWidth),
                    maskHeight: UInt32(maskHeight),
                    originX: Int32(originX),
                    originY: Int32(originY)
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: canvasWidth, height: canvasHeight)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return byteArray(from: outputBuffer, count: canvasWidth * canvasHeight)
    }

    public func combinedSelectionMask(
        base: [UInt8],
        incoming: [UInt8],
        mode: PrimoMetalSelectionCombineMode,
        width: Int,
        height: Int
    ) -> [UInt8]? {
        let expectedCount = width * height
        guard
            width > 0,
            height > 0,
            base.count == expectedCount,
            incoming.count == expectedCount,
            let commandQueue,
            let pipeline = selectionCombinePipeline,
            let baseBuffer = makeBuffer(base),
            let incomingBuffer = makeBuffer(incoming),
            let outputBuffer = device?.makeBuffer(length: expectedCount, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalSelectionCombineDescriptor(
                    width: UInt32(width),
                    height: UInt32(height),
                    mode: mode == .add ? 0 : 1,
                    padding0: 0
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(baseBuffer, offset: 0, index: 0)
        encoder.setBuffer(incomingBuffer, offset: 0, index: 1)
        encoder.setBuffer(outputBuffer, offset: 0, index: 2)
        encoder.setBuffer(descriptorBuffer, offset: 0, index: 3)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: width, height: height)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return byteArray(from: outputBuffer, count: expectedCount)
    }

    public func croppedSelectionMask(
        mask: [UInt8],
        width: Int,
        height: Int
    ) -> PrimoMetalCroppedSelectionMask? {
        guard
            width > 0,
            height > 0,
            mask.count == width * height,
            let device,
            let commandQueue,
            let boundsPipeline = selectionBoundsPipeline,
            let cropPipeline = selectionCropPipeline,
            let maskBuffer = makeBuffer(mask),
            let boundsBuffer = makeBuffer([UInt32(width), UInt32(height), 0, 0]),
            let requestBuffer = makeBuffer(
                PrimoMetalMaskKernelDescriptor(
                    width: UInt32(width),
                    height: UInt32(height),
                    radius: 0
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let boundsEncoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        boundsEncoder.setComputePipelineState(boundsPipeline)
        boundsEncoder.setBuffer(maskBuffer, offset: 0, index: 0)
        boundsEncoder.setBuffer(boundsBuffer, offset: 0, index: 1)
        boundsEncoder.setBuffer(requestBuffer, offset: 0, index: 2)
        dispatch2D(encoder: boundsEncoder, pipeline: boundsPipeline, width: width, height: height)
        boundsEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }

        let bounds = Array(UnsafeBufferPointer(start: boundsBuffer.contents().assumingMemoryBound(to: UInt32.self), count: 4))
        let minX = Int(bounds[0])
        let minY = Int(bounds[1])
        let maxX = Int(bounds[2])
        let maxY = Int(bounds[3])
        guard minX < width, minY < height, maxX >= minX, maxY >= minY else { return nil }

        let cropWidth = (maxX - minX) + 1
        let cropHeight = (maxY - minY) + 1
        guard
            let cropBuffer = device.makeBuffer(length: cropWidth * cropHeight, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalSelectionCropDescriptor(
                    sourceWidth: UInt32(width),
                    sourceHeight: UInt32(height),
                    originX: UInt32(minX),
                    originY: UInt32(minY),
                    cropWidth: UInt32(cropWidth),
                    cropHeight: UInt32(cropHeight),
                    padding0: 0,
                    padding1: 0
                )
            ),
            let cropCommandBuffer = commandQueue.makeCommandBuffer(),
            let cropEncoder = cropCommandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        cropEncoder.setComputePipelineState(cropPipeline)
        cropEncoder.setBuffer(maskBuffer, offset: 0, index: 0)
        cropEncoder.setBuffer(cropBuffer, offset: 0, index: 1)
        cropEncoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: cropEncoder, pipeline: cropPipeline, width: cropWidth, height: cropHeight)
        cropEncoder.endEncoding()
        cropCommandBuffer.commit()
        cropCommandBuffer.waitUntilCompleted()
        guard cropCommandBuffer.status == .completed else { return nil }

        return PrimoMetalCroppedSelectionMask(
            bounds: CGRect(x: minX, y: minY, width: cropWidth, height: cropHeight),
            maskData: bytes(from: cropBuffer, count: cropWidth * cropHeight),
            maskWidth: cropWidth,
            maskHeight: cropHeight
        )
    }

    public func preservingExistingAlpha(
        source: Data,
        existing: Data,
        width: Int,
        height: Int
    ) -> Data? {
        let expectedCount = width * height * 4
        guard
            width > 0,
            height > 0,
            source.count == expectedCount,
            existing.count == expectedCount,
            let commandQueue,
            let pipeline = alphaPreservePipeline,
            let sourceBuffer = makeBuffer(source),
            let existingBuffer = makeBuffer(existing),
            let outputBuffer = device?.makeBuffer(length: expectedCount, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalAlphaPreserveDescriptor(
                    width: UInt32(width),
                    height: UInt32(height)
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(sourceBuffer, offset: 0, index: 0)
        encoder.setBuffer(existingBuffer, offset: 0, index: 1)
        encoder.setBuffer(outputBuffer, offset: 0, index: 2)
        encoder.setBuffer(descriptorBuffer, offset: 0, index: 3)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: width, height: height)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return bytes(from: outputBuffer, count: expectedCount)
    }

    public func preservingExistingAlphaBufferHandle(
        sourceHandle: MetalBufferHandle,
        existingHandle: MetalBufferHandle?,
        existingPixelData: Data,
        width: Int,
        height: Int
    ) -> MetalBufferHandle? {
        let expectedCount = width * height * 4
        guard
            width > 0,
            height > 0,
            existingPixelData.count == expectedCount,
            let commandQueue,
            let pipeline = alphaPreservePipeline,
            let sourceResource = cachedBufferResource(for: sourceHandle)
        else {
            return nil
        }

        let existingBuffer: MTLBuffer?
        if let existingHandle, let existingResource = cachedBufferResource(for: existingHandle) {
            existingBuffer = existingResource.buffer
        } else {
            existingBuffer = makeBuffer(existingPixelData)
        }

        guard
            let existingBuffer,
            let outputBuffer = device?.makeBuffer(length: expectedCount, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalAlphaPreserveDescriptor(
                    width: UInt32(width),
                    height: UInt32(height)
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(sourceResource.buffer, offset: 0, index: 0)
        encoder.setBuffer(existingBuffer, offset: 0, index: 1)
        encoder.setBuffer(outputBuffer, offset: 0, index: 2)
        encoder.setBuffer(descriptorBuffer, offset: 0, index: 3)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: width, height: height)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return makeBufferHandle(width: width, height: height, bytesPerRow: width * 4, buffer: outputBuffer)
    }

    public func compositedPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int?,
        adjustedActiveLayerPixels: Data?,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)? = nil
    ) -> Data? {
        guard snapshot.width > 0, snapshot.height > 0 else { return nil }
        let orderedLayers = snapshot.layers.sorted(by: { $0.index < $1.index })
        guard
            let commandQueue,
            let pipeline = compositePipeline,
            let layerTexture = rebuildLayerTextureIfNeeded(snapshot: snapshot, orderedLayers: orderedLayers),
            let layerBuffer = makeBuffer(orderedLayers.map(Self.makeLayerDescriptor(for:))),
            let requestBuffer = makeBuffer(
                PrimoMetalCompositeRequestDescriptor(
                    canvasWidth: UInt32(snapshot.width),
                    canvasHeight: UInt32(snapshot.height),
                    originX: UInt32(dirtyRect?.originX ?? 0),
                    originY: UInt32(dirtyRect?.originY ?? 0),
                    outputWidth: UInt32(dirtyRect?.width ?? snapshot.width),
                    outputHeight: UInt32(dirtyRect?.height ?? snapshot.height),
                    layerCount: UInt32(orderedLayers.count),
                    activeLayerIndex: Int32(activeLayerIndex ?? -1),
                    hasActiveLayerOverride: adjustedActiveLayerPixels == nil ? 0 : 1,
                    includeActiveLayerWhenHidden: dirtyRect == nil ? 0 : 1
                )
            ),
            let outputBuffer = device?.makeBuffer(
                length: (dirtyRect?.width ?? snapshot.width) * (dirtyRect?.height ?? snapshot.height) * 4,
                options: .storageModeShared
            )
        else {
            return nil
        }

        let expectedCount = snapshot.width * snapshot.height * 4
        let overridePixels = adjustedActiveLayerPixels ?? Data(count: expectedCount)
        guard overridePixels.count == expectedCount, let overrideBuffer = makeBuffer(overridePixels) else {
            return nil
        }

        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        let outputWidth = dirtyRect?.width ?? snapshot.width
        let outputHeight = dirtyRect?.height ?? snapshot.height
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(layerTexture, index: 0)
        encoder.setBuffer(layerBuffer, offset: 0, index: 0)
        encoder.setBuffer(overrideBuffer, offset: 0, index: 1)
        encoder.setBuffer(outputBuffer, offset: 0, index: 2)
        encoder.setBuffer(requestBuffer, offset: 0, index: 3)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: outputWidth, height: outputHeight)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return bytes(from: outputBuffer, count: outputWidth * outputHeight * 4)
    }

    public func compositedBufferHandle(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int?,
        adjustedActiveLayerPixels: Data?,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)? = nil
    ) -> MetalBufferHandle? {
        compositedBufferHandle(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            adjustedActiveLayerBufferHandle: nil,
            dirtyRect: dirtyRect
        )
    }

    public func compositedBufferHandle(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int?,
        adjustedActiveLayerBufferHandle: MetalBufferHandle?,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)? = nil
    ) -> MetalBufferHandle? {
        compositedBufferHandle(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: nil,
            adjustedActiveLayerBufferHandle: adjustedActiveLayerBufferHandle,
            dirtyRect: dirtyRect
        )
    }

    private func compositedBufferHandle(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int?,
        adjustedActiveLayerPixels: Data?,
        adjustedActiveLayerBufferHandle: MetalBufferHandle?,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)? = nil
    ) -> MetalBufferHandle? {
        guard snapshot.width > 0, snapshot.height > 0 else { return nil }
        let orderedLayers = snapshot.layers.sorted(by: { $0.index < $1.index })
        let hasOverride = adjustedActiveLayerPixels != nil || adjustedActiveLayerBufferHandle != nil
        guard
            let commandQueue,
            let pipeline = compositePipeline,
            let layerTexture = rebuildLayerTextureIfNeeded(snapshot: snapshot, orderedLayers: orderedLayers),
            let layerBuffer = makeBuffer(orderedLayers.map(Self.makeLayerDescriptor(for:))),
            let requestBuffer = makeBuffer(
                PrimoMetalCompositeRequestDescriptor(
                    canvasWidth: UInt32(snapshot.width),
                    canvasHeight: UInt32(snapshot.height),
                    originX: UInt32(dirtyRect?.originX ?? 0),
                    originY: UInt32(dirtyRect?.originY ?? 0),
                    outputWidth: UInt32(dirtyRect?.width ?? snapshot.width),
                    outputHeight: UInt32(dirtyRect?.height ?? snapshot.height),
                    layerCount: UInt32(orderedLayers.count),
                    activeLayerIndex: Int32(activeLayerIndex ?? -1),
                    hasActiveLayerOverride: hasOverride ? 1 : 0,
                    includeActiveLayerWhenHidden: dirtyRect == nil ? 0 : 1
                )
            )
        else {
            return nil
        }

        let expectedCount = snapshot.width * snapshot.height * 4
        let overridePixels = adjustedActiveLayerPixels ?? Data(count: expectedCount)
        let outputWidth = dirtyRect?.width ?? snapshot.width
        let outputHeight = dirtyRect?.height ?? snapshot.height
        let overrideBuffer: MTLBuffer?
        if let adjustedActiveLayerBufferHandle {
            guard
                adjustedActiveLayerBufferHandle.width == snapshot.width,
                adjustedActiveLayerBufferHandle.height == snapshot.height,
                let resource = cachedBufferResource(for: adjustedActiveLayerBufferHandle)
            else {
                return nil
            }
            overrideBuffer = resource.buffer
        } else {
            guard overridePixels.count == expectedCount else { return nil }
            overrideBuffer = makeBuffer(overridePixels)
        }

        guard let overrideBuffer,
              let outputBuffer = device?.makeBuffer(length: outputWidth * outputHeight * 4, options: .storageModeShared),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(layerTexture, index: 0)
        encoder.setBuffer(layerBuffer, offset: 0, index: 0)
        encoder.setBuffer(overrideBuffer, offset: 0, index: 1)
        encoder.setBuffer(outputBuffer, offset: 0, index: 2)
        encoder.setBuffer(requestBuffer, offset: 0, index: 3)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: outputWidth, height: outputHeight)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return makeBufferHandle(width: outputWidth, height: outputHeight, bytesPerRow: outputWidth * 4, buffer: outputBuffer)
    }

    public func compositeDocument(snapshot: MetalDocumentSnapshot) -> Data? {
        compositedPixelData(
            snapshot: snapshot,
            activeLayerIndex: nil,
            adjustedActiveLayerPixels: nil,
            dirtyRect: nil
        )
    }

    public func compositeDocumentBufferHandle(snapshot: MetalDocumentSnapshot) -> MetalBufferHandle? {
        compositedBufferHandle(
            snapshot: snapshot,
            activeLayerIndex: nil,
            adjustedActiveLayerPixels: nil,
            dirtyRect: nil
        )
    }

    public func compositedIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        guard let handle = compositedBufferHandle(
            snapshot: snapshot,
            activeLayerIndex: nil,
            adjustedActiveLayerPixels: nil,
            dirtyRect: dirtyRect
        ) else {
            return nil
        }
        return IncrementalLayerUpdate(
            layerIndex: -1,
            originX: dirtyRect.originX,
            originY: dirtyRect.originY,
            width: dirtyRect.width,
            height: dirtyRect.height,
            gpuBufferHandle: handle,
            pixelData: Data()
        )
    }

    public func compositedPreviewPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        compositedPixelData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            dirtyRect: nil
        )
    }

    public func compositedPreviewIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        guard let handle = compositedBufferHandle(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            dirtyRect: dirtyRect
        ) else {
            return nil
        }
        return IncrementalLayerUpdate(
            layerIndex: -1,
            originX: dirtyRect.originX,
            originY: dirtyRect.originY,
            width: dirtyRect.width,
            height: dirtyRect.height,
            gpuBufferHandle: handle,
            pixelData: Data()
        )
    }

    public func compositedPreviewIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerBufferHandle: MetalBufferHandle,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        guard let handle = compositedBufferHandle(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerBufferHandle: adjustedActiveLayerBufferHandle,
            dirtyRect: dirtyRect
        ) else {
            return nil
        }
        return IncrementalLayerUpdate(
            layerIndex: -1,
            originX: dirtyRect.originX,
            originY: dirtyRect.originY,
            width: dirtyRect.width,
            height: dirtyRect.height,
            gpuBufferHandle: handle,
            pixelData: Data()
        )
    }

    public func applyLayerMask(
        pixelData: Data,
        maskData: Data,
        width: Int,
        height: Int
    ) -> Data? {
        guard
            width > 0,
            height > 0,
            pixelData.count == width * height * 4,
            maskData.count == width * height,
            let commandQueue,
            let pipeline = applyLayerMaskPipeline,
            let pixelBuffer = makeBuffer(pixelData),
            let maskBuffer = makeBuffer(maskData),
            let outputBuffer = device?.makeBuffer(length: pixelData.count, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalLayerMaskApplyDescriptor(
                    width: UInt32(width),
                    height: UInt32(height)
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(pixelBuffer, offset: 0, index: 0)
        encoder.setBuffer(maskBuffer, offset: 0, index: 1)
        encoder.setBuffer(outputBuffer, offset: 0, index: 2)
        encoder.setBuffer(descriptorBuffer, offset: 0, index: 3)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: width, height: height)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return bytes(from: outputBuffer, count: pixelData.count)
    }

    public func alphaMask(
        pixelData: Data,
        width: Int,
        height: Int
    ) -> [UInt8]? {
        guard
            width > 0,
            height > 0,
            pixelData.count == width * height * 4,
            let commandQueue,
            let pipeline = alphaMaskPipeline,
            let pixelBuffer = makeBuffer(pixelData),
            let outputBuffer = device?.makeBuffer(length: width * height, options: .storageModeShared),
            let descriptorBuffer = makeBuffer(
                PrimoMetalLayerMaskApplyDescriptor(
                    width: UInt32(width),
                    height: UInt32(height)
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(pixelBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(descriptorBuffer, offset: 0, index: 2)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: width, height: height)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return [UInt8](bytes(from: outputBuffer, count: width * height))
    }

    public func mergeLayers(
        lowerPixelData: Data,
        upperPixelData: Data,
        upperMaskData: Data?,
        canvasWidth: Int,
        canvasHeight: Int,
        upperOpacity: Float,
        upperBlendMode: LayerBlendMode
    ) -> Data? {
        let expectedCount = canvasWidth * canvasHeight * 4
        guard lowerPixelData.count == expectedCount, upperPixelData.count == expectedCount else {
            return nil
        }

        let resolvedUpper: Data
        if let upperMaskData {
            guard let maskedUpper = applyLayerMask(
                pixelData: upperPixelData,
                maskData: upperMaskData,
                width: canvasWidth,
                height: canvasHeight
            ) else {
                return nil
            }
            resolvedUpper = maskedUpper
        } else {
            resolvedUpper = upperPixelData
        }

        let snapshot = MetalDocumentSnapshot(
            width: canvasWidth,
            height: canvasHeight,
            revision: 0,
            compositePixelData: Data(count: expectedCount),
            layers: [
                MetalLayerSnapshot(
                    index: 0,
                    opacity: 1.0,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailSurface: nil,
                    thumbnailData: nil,
                    pixelData: lowerPixelData
                ),
                MetalLayerSnapshot(
                    index: 1,
                    opacity: upperOpacity,
                    visible: true,
                    isClipped: false,
                    blendMode: upperBlendMode,
                    thumbnailSurface: nil,
                    thumbnailData: nil,
                    pixelData: resolvedUpper
                )
            ]
        )
        return compositeDocument(snapshot: snapshot)
    }

    public func executeStroke(
        _ request: PrimoMetalStrokeExecutionRequest
    ) -> PrimoMetalStrokeExecutionResult? {
        guard let result = executeStroke(
            request,
            includeFullPixelData: true
        ) else {
            return nil
        }
        guard let pixelData = result.pixelData else { return nil }
        let cachedExecution = withCacheLock { cachedStrokeExecution }
        let gpuBufferHandle = cachedExecution.map {
            makeBufferHandle(
                width: request.canvasWidth,
                height: request.canvasHeight,
                bytesPerRow: request.canvasWidth * 4,
                buffer: $0.buffers.current
            )
        }
        return PrimoMetalStrokeExecutionResult(
            pixelData: pixelData,
            dirtyRect: result.dirtyRect,
            gpuBufferHandle: gpuBufferHandle,
            rectPixelData: result.rectPixelData
        )
    }

    public func executeStrokeMutation(
        _ request: PrimoMetalStrokeExecutionRequest
    ) -> PrimoMetalStrokeMutationResult? {
        guard let result = executeStroke(
            request,
            includeFullPixelData: false
        ) else {
            return nil
        }
        let cachedExecution = withCacheLock { cachedStrokeExecution }
        let gpuBufferHandle = cachedExecution.map {
            makeBufferHandle(
                width: request.canvasWidth,
                height: request.canvasHeight,
                bytesPerRow: request.canvasWidth * 4,
                buffer: $0.buffers.current
            )
        }
        return PrimoMetalStrokeMutationResult(
            dirtyRect: result.dirtyRect,
            gpuBufferHandle: gpuBufferHandle,
            rectPixelData: result.rectPixelData
        )
    }

    private func executeStroke(
        _ request: PrimoMetalStrokeExecutionRequest,
        includeFullPixelData: Bool
    ) -> (pixelData: Data?, dirtyRect: (originX: Int, originY: Int, width: Int, height: Int), rectPixelData: Data?)? {
        if request.brush.smudgeEngineEnabled {
            return executeColorSmudgeStroke(request, includeFullPixelData: includeFullPixelData)
        }
        guard Self.supportsStrokeRasterization(request.brush) else { return nil }
        guard let preprocess = preprocessStrokeSamples(
            samples: request.samples,
            brush: request.brush,
            canvasWidth: request.canvasWidth,
            canvasHeight: request.canvasHeight
        ) else {
            return nil
        }
        let descriptors = preprocess.descriptors
        guard
            request.canvasWidth > 0,
            request.canvasHeight > 0,
            request.basePixelData.count == request.canvasWidth * request.canvasHeight * 4,
            let commandQueue,
            let pipeline = strokeRasterPipeline,
            let copyPipeline = copyStrokeRectPipeline
        else {
            return nil
        }

        guard let executionContext = prepareStrokeExecutionContext(request: request, descriptors: descriptors) else {
            return nil
        }
        if executionContext.shouldAdoptCachedOutput {
            let resolvedDirtyRect = preprocess.dirtyRect
                ?? executionContext.cachedDirtyRect.map { ($0.originX, $0.originY, $0.width, $0.height) }
                ?? (0, 0, request.canvasWidth, request.canvasHeight)
            return (
                pixelData: includeFullPixelData
                    ? bytes(from: executionContext.buffers.current, count: request.basePixelData.count)
                    : nil,
                dirtyRect: resolvedDirtyRect,
                rectPixelData: executionContext.cachedRectPixelData
            )
        }

        guard let dirtyRect = preprocess.dirtyRect else {
            return (
                pixelData: includeFullPixelData
                    ? bytes(from: executionContext.buffers.current, count: request.basePixelData.count)
                    : nil,
                dirtyRect: (0, 0, request.canvasWidth, request.canvasHeight),
                rectPixelData: nil
            )
        }

        let customTip = resolvedCustomTipMask(request.brush.customTip)
        guard
            let brushBuffer = makeBuffer(Self.makeStrokeBrushDescriptor(request.brush, customTip: customTip)),
            let customTipBuffer = makeBuffer(customTip.alphaData),
            let copyRequestBuffer = makeBuffer(
                PrimoMetalStrokeRectCopyDescriptor(
                    canvasWidth: UInt32(request.canvasWidth),
                    canvasHeight: UInt32(request.canvasHeight),
                    originX: UInt32(dirtyRect.originX),
                    originY: UInt32(dirtyRect.originY),
                    rectWidth: UInt32(dirtyRect.width),
                    rectHeight: UInt32(dirtyRect.height)
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            return nil
        }

        guard let binningResources = makeStrokeBinningResources(
            commandBuffer: commandBuffer,
            descriptors: descriptors,
            sampleBuffer: preprocess.sampleBuffer,
            brush: request.brush,
            brushBuffer: brushBuffer,
            dirtyRect: dirtyRect,
            canvasWidth: request.canvasWidth,
            canvasHeight: request.canvasHeight
        ) else {
            return nil
        }
        guard let requestBuffer = makeBuffer(binningResources.requestDescriptor) else { return nil }

        guard let copyEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        copyEncoder.setComputePipelineState(copyPipeline)
        copyEncoder.setBuffer(executionContext.buffers.current, offset: 0, index: 0)
        copyEncoder.setBuffer(executionContext.buffers.scratch, offset: 0, index: 1)
        copyEncoder.setBuffer(copyRequestBuffer, offset: 0, index: 2)
        dispatch2D(encoder: copyEncoder, pipeline: copyPipeline, width: dirtyRect.width, height: dirtyRect.height)
        copyEncoder.endEncoding()

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(executionContext.buffers.current, offset: 0, index: 0)
        encoder.setBuffer(executionContext.buffers.scratch, offset: 0, index: 1)
        encoder.setBuffer(binningResources.primitiveBuffer, offset: 0, index: 2)
        encoder.setBuffer(brushBuffer, offset: 0, index: 3)
        encoder.setBuffer(requestBuffer, offset: 0, index: 4)
        encoder.setBuffer(customTipBuffer, offset: 0, index: 5)
        encoder.setBuffer(binningResources.tileRangeBuffer, offset: 0, index: 6)
        encoder.setBuffer(binningResources.primitiveIndexBuffer, offset: 0, index: 7)
        dispatch2D(encoder: encoder, pipeline: pipeline, width: dirtyRect.width, height: dirtyRect.height)
        encoder.endEncoding()

        guard let finalizeEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        finalizeEncoder.setComputePipelineState(copyPipeline)
        finalizeEncoder.setBuffer(executionContext.buffers.scratch, offset: 0, index: 0)
        finalizeEncoder.setBuffer(executionContext.buffers.current, offset: 0, index: 1)
        finalizeEncoder.setBuffer(copyRequestBuffer, offset: 0, index: 2)
        dispatch2D(encoder: finalizeEncoder, pipeline: copyPipeline, width: dirtyRect.width, height: dirtyRect.height)
        finalizeEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }

        let cachedDirtyRect = PrimoMetalStrokeDirtyRect(
            originX: dirtyRect.originX,
            originY: dirtyRect.originY,
            width: dirtyRect.width,
            height: dirtyRect.height
        )
        let rectPixelData = bytes(
            from: executionContext.buffers.current,
            dirtyRect: cachedDirtyRect,
            canvasWidth: request.canvasWidth,
            canvasHeight: request.canvasHeight
        )
        withCacheLock {
            cachedStrokeExecution = StrokeExecutionCache(
                width: request.canvasWidth,
                height: request.canvasHeight,
                baseSnapshotRevision: request.snapshotRevision,
                activeLayerIndex: request.activeLayerIndex,
                brush: request.brush,
                previewSamples: descriptors,
                committableSamples: descriptors,
                dirtyRect: cachedDirtyRect,
                rectPixelData: rectPixelData,
                buffers: executionContext.buffers,
                lastOutputValid: true
            )
        }
        return (
            pixelData: includeFullPixelData
                ? bytes(from: executionContext.buffers.current, count: request.basePixelData.count)
                : nil,
            dirtyRect: dirtyRect,
            rectPixelData: rectPixelData
        )
    }

    private func executeColorSmudgeStroke(
        _ request: PrimoMetalStrokeExecutionRequest,
        includeFullPixelData: Bool
    ) -> (pixelData: Data?, dirtyRect: (originX: Int, originY: Int, width: Int, height: Int), rectPixelData: Data?)? {
        guard
            request.canvasWidth > 0,
            request.canvasHeight > 0,
            request.basePixelData.count == request.canvasWidth * request.canvasHeight * 4,
            let commandQueue,
            let smudgePipeline = strokeColorSmudgePipeline,
            let copyPipeline = copyStrokeRectPipeline
        else {
            return nil
        }

        guard let preprocess = preprocessStrokeSamples(
            samples: request.samples,
            brush: request.brush,
            canvasWidth: request.canvasWidth,
            canvasHeight: request.canvasHeight
        ) else {
            return nil
        }
        guard
            let smudgeGeneration = generateColorSmudgeDabDescriptors(
                descriptors: preprocess.descriptors,
                sampleBuffer: preprocess.sampleBuffer,
                brush: request.brush,
                canvasWidth: request.canvasWidth,
                canvasHeight: request.canvasHeight
            ),
            !smudgeGeneration.descriptors.isEmpty
        else {
            return nil
        }
        guard let executionContext = prepareStrokeExecutionContext(request: request, descriptors: preprocess.descriptors) else {
            return nil
        }
        if executionContext.shouldAdoptCachedOutput {
            let resolvedDirtyRect = smudgeGeneration.dirtyRect
                ?? executionContext.cachedDirtyRect.map { ($0.originX, $0.originY, $0.width, $0.height) }
                ?? (0, 0, request.canvasWidth, request.canvasHeight)
            return (
                pixelData: includeFullPixelData
                    ? bytes(from: executionContext.buffers.current, count: request.basePixelData.count)
                    : nil,
                dirtyRect: resolvedDirtyRect,
                rectPixelData: executionContext.cachedRectPixelData
            )
        }

        let customTip = resolvedCustomTipMask(request.brush.customTip)
        guard
            let brushBuffer = makeBuffer(Self.makeStrokeBrushDescriptor(request.brush, customTip: customTip)),
            let customTipBuffer = makeBuffer(customTip.alphaData),
            let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            return nil
        }

        let generatedDabs = smudgeGeneration.descriptors
        for dab in generatedDabs {
            let rect = (
                originX: Int(dab.rectOriginX),
                originY: Int(dab.rectOriginY),
                width: Int(dab.rectWidth),
                height: Int(dab.rectHeight)
            )
            guard rect.width > 0, rect.height > 0 else { continue }

            guard
                let copyRequestBuffer = makeBuffer(
                    PrimoMetalStrokeRectCopyDescriptor(
                        canvasWidth: UInt32(request.canvasWidth),
                        canvasHeight: UInt32(request.canvasHeight),
                        originX: UInt32(rect.originX),
                        originY: UInt32(rect.originY),
                        rectWidth: UInt32(rect.width),
                        rectHeight: UInt32(rect.height)
                    )
                ),
                let dabBuffer = makeBuffer(
                    dab
                ),
                let copyEncoder = commandBuffer.makeComputeCommandEncoder()
            else {
                return nil
            }

            copyEncoder.setComputePipelineState(copyPipeline)
            copyEncoder.setBuffer(executionContext.buffers.current, offset: 0, index: 0)
            copyEncoder.setBuffer(executionContext.buffers.scratch, offset: 0, index: 1)
            copyEncoder.setBuffer(copyRequestBuffer, offset: 0, index: 2)
            dispatch2D(encoder: copyEncoder, pipeline: copyPipeline, width: rect.width, height: rect.height)
            copyEncoder.endEncoding()

            guard let smudgeEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
            smudgeEncoder.setComputePipelineState(smudgePipeline)
            smudgeEncoder.setBuffer(executionContext.buffers.current, offset: 0, index: 0)
            smudgeEncoder.setBuffer(executionContext.buffers.scratch, offset: 0, index: 1)
            smudgeEncoder.setBuffer(dabBuffer, offset: 0, index: 2)
            smudgeEncoder.setBuffer(brushBuffer, offset: 0, index: 3)
            smudgeEncoder.setBuffer(customTipBuffer, offset: 0, index: 4)
            dispatch2D(encoder: smudgeEncoder, pipeline: smudgePipeline, width: rect.width, height: rect.height)
            smudgeEncoder.endEncoding()

            guard let finalizeEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
            finalizeEncoder.setComputePipelineState(copyPipeline)
            finalizeEncoder.setBuffer(executionContext.buffers.scratch, offset: 0, index: 0)
            finalizeEncoder.setBuffer(executionContext.buffers.current, offset: 0, index: 1)
            finalizeEncoder.setBuffer(copyRequestBuffer, offset: 0, index: 2)
            dispatch2D(encoder: finalizeEncoder, pipeline: copyPipeline, width: rect.width, height: rect.height)
            finalizeEncoder.endEncoding()
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        guard let resolvedDirtyRect = smudgeGeneration.dirtyRect else {
            return (
                pixelData: includeFullPixelData ? bytes(from: executionContext.buffers.current, count: request.basePixelData.count) : nil,
                dirtyRect: (0, 0, request.canvasWidth, request.canvasHeight),
                rectPixelData: nil
            )
        }

        let cachedDirtyRect = PrimoMetalStrokeDirtyRect(
            originX: resolvedDirtyRect.originX,
            originY: resolvedDirtyRect.originY,
            width: resolvedDirtyRect.width,
            height: resolvedDirtyRect.height
        )
        let rectPixelData = bytes(
            from: executionContext.buffers.current,
            dirtyRect: cachedDirtyRect,
            canvasWidth: request.canvasWidth,
            canvasHeight: request.canvasHeight
        )
        withCacheLock {
            cachedStrokeExecution = StrokeExecutionCache(
                width: request.canvasWidth,
                height: request.canvasHeight,
                baseSnapshotRevision: request.snapshotRevision,
                activeLayerIndex: request.activeLayerIndex,
                brush: request.brush,
                previewSamples: preprocess.descriptors,
                committableSamples: preprocess.descriptors,
                dirtyRect: cachedDirtyRect,
                rectPixelData: rectPixelData,
                buffers: executionContext.buffers,
                lastOutputValid: true
            )
        }
        return (
            pixelData: includeFullPixelData ? bytes(from: executionContext.buffers.current, count: request.basePixelData.count) : nil,
            dirtyRect: resolvedDirtyRect,
            rectPixelData: rectPixelData
        )
    }

    public func rasterizedStrokePixelData(
        basePixelData: Data,
        baseBufferHandle: MetalBufferHandle? = nil,
        canvasWidth: Int,
        canvasHeight: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        mode: PrimoMetalStrokeExecutionMode = .commit,
        snapshotRevision: Int? = nil,
        activeLayerIndex: Int? = nil
    ) -> Data? {
        guard let result = executeStroke(
            PrimoMetalStrokeExecutionRequest(
                basePixelData: basePixelData,
                baseBufferHandle: baseBufferHandle,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                samples: samples,
                brush: brush,
                mode: mode,
                snapshotRevision: snapshotRevision,
                activeLayerIndex: activeLayerIndex
            )
        ) else {
            return nil
        }
        releaseBufferHandle(result.gpuBufferHandle)
        return result.pixelData
    }

    func debugStrokeBinningSummary(
        canvasWidth: Int,
        canvasHeight: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings
    ) -> PrimoMetalStrokeBinningDebugSummary? {
        guard
            canvasWidth > 0,
            canvasHeight > 0,
            let commandQueue
        else {
            return nil
        }
        let normalizedSamples = Self.normalizedCommittedStrokeSamples(samples, brush: brush)
        let descriptors = Self.strokeSampleDescriptors(samples: normalizedSamples)
        guard !descriptors.isEmpty else { return nil }
        guard let dirtyRect = Self.strokePreviewDirtyRect(
            samples: normalizedSamples,
            brush: brush,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        ) else {
            return nil
        }
        let customTip = resolvedCustomTipMask(brush.customTip)
        guard
            let sampleBuffer = makeBuffer(descriptors),
            let brushBuffer = makeBuffer(Self.makeStrokeBrushDescriptor(brush, customTip: customTip)),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let resources = makeStrokeBinningResources(
                commandBuffer: commandBuffer,
                descriptors: descriptors,
                sampleBuffer: sampleBuffer,
                brush: brush,
                brushBuffer: brushBuffer,
                dirtyRect: dirtyRect,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight
            )
        else {
            return nil
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }

        let tileCount = Int(resources.requestDescriptor.tileCount)
        let tileRanges = Array(
            UnsafeBufferPointer(
                start: resources.tileRangeBuffer.contents().assumingMemoryBound(to: PrimoMetalStrokeTileRangeDescriptor.self),
                count: tileCount
            )
        )
        let primitiveIndices = Array(
            UnsafeBufferPointer(
                start: resources.primitiveIndexBuffer.contents().assumingMemoryBound(to: UInt32.self),
                count: Int(resources.requestDescriptor.maxPrimitiveIndexCount)
            )
        )
        var monotonic = true
        var previousStart = 0
        var totalReferences = 0
        for (index, range) in tileRanges.enumerated() {
            let start = Int(range.startIndex)
            let count = Int(range.primitiveCount)
            if index > 0, start < previousStart {
                monotonic = false
            }
            previousStart = start
            totalReferences += count
        }
        let boundsValid = primitiveIndices.prefix(totalReferences).allSatisfy { Int($0) < Int(resources.requestDescriptor.sampleCount) }
        return PrimoMetalStrokeBinningDebugSummary(
            primitiveCount: Int(resources.requestDescriptor.sampleCount),
            tileCount: tileCount,
            totalPrimitiveReferences: totalReferences,
            monotonicTileOffsets: monotonic,
            primitiveIndexBoundsValid: boundsValid
        )
    }

    private func prepareStrokeExecutionContext(
        request: PrimoMetalStrokeExecutionRequest,
        descriptors: [PrimoMetalStrokeSampleDescriptor]
    ) -> StrokeExecutionContext? {
        let cachedExecution = withCacheLock { cachedStrokeExecution }
        if let cachedStrokeExecution = cachedExecution,
           cachedStrokeExecution.width == request.canvasWidth,
           cachedStrokeExecution.height == request.canvasHeight,
           cachedStrokeExecution.baseSnapshotRevision == request.snapshotRevision,
           cachedStrokeExecution.activeLayerIndex == request.activeLayerIndex,
           cachedStrokeExecution.brush == request.brush,
           cachedStrokeExecution.lastOutputValid {
            switch request.mode {
            case .interactive:
                if descriptors == cachedStrokeExecution.previewSamples {
                    return StrokeExecutionContext(
                        buffers: cachedStrokeExecution.buffers,
                        shouldAdoptCachedOutput: true,
                        cachedDirtyRect: cachedStrokeExecution.dirtyRect,
                        cachedRectPixelData: cachedStrokeExecution.rectPixelData
                    )
                }
            case .commit:
                if descriptors == cachedStrokeExecution.committableSamples {
                    return StrokeExecutionContext(
                        buffers: cachedStrokeExecution.buffers,
                        shouldAdoptCachedOutput: true,
                        cachedDirtyRect: cachedStrokeExecution.dirtyRect,
                        cachedRectPixelData: cachedStrokeExecution.rectPixelData
                    )
                }
            case .previewAdopt:
                break
            }
        }

        guard
            let current = makeLayerSourceBuffer(
                pixelData: request.basePixelData,
                bufferHandle: request.baseBufferHandle,
                expectedCount: request.canvasWidth * request.canvasHeight * 4
            )
        else {
            return nil
        }
        guard let scratch = makeBuffer(from: current, count: request.canvasWidth * request.canvasHeight * 4) else {
            return nil
        }
        return StrokeExecutionContext(
            buffers: PrimoMetalBufferPair(current: current, scratch: scratch),
            shouldAdoptCachedOutput: false,
            cachedDirtyRect: nil,
            cachedRectPixelData: nil
        )
    }

    private func rebuildLayerTextureIfNeeded(snapshot: MetalDocumentSnapshot, orderedLayers: [MetalLayerSnapshot]) -> MTLTexture? {
        let signature = SnapshotTextureSignature(
            revision: snapshot.revision,
            width: snapshot.width,
            height: snapshot.height,
            transferKind: snapshot.transferKind,
            compositeStorageIdentity: snapshot.compositeBufferHandle.map(Self.handleIdentity(_:)) ?? Self.dataStorageIdentity(snapshot.compositePixelData),
            layers: orderedLayers.map {
                SnapshotLayerSignature(
                    index: $0.index,
                    opacity: $0.opacity,
                    visible: $0.visible,
                    isClipped: $0.isClipped,
                    blendMode: $0.blendMode,
                    gpuHandleID: $0.gpuBufferHandle?.id,
                    pixelStorageIdentity: Self.dataStorageIdentity($0.pixelData)
                )
            }
        )
        let cachedTexture = withCacheLock {
            cachedSignature == signature ? cachedLayerTexture : nil
        }
        if let cachedTexture {
            return cachedTexture
        }
        guard let device else { return nil }
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2DArray
        descriptor.pixelFormat = .rgba8Unorm
        descriptor.width = max(snapshot.width, 1)
        descriptor.height = max(snapshot.height, 1)
        descriptor.depth = 1
        descriptor.mipmapLevelCount = 1
        descriptor.arrayLength = max(orderedLayers.count, 1)
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        let expectedCount = snapshot.width * snapshot.height * 4
        for (slice, layer) in orderedLayers.enumerated() {
            if let handle = layer.gpuBufferHandle,
               let resource = cachedBufferResource(for: handle) {
                texture.replace(
                    region: MTLRegionMake2D(0, 0, snapshot.width, snapshot.height),
                    mipmapLevel: 0,
                    slice: slice,
                    withBytes: resource.buffer.contents(),
                    bytesPerRow: resource.bytesPerRow,
                    bytesPerImage: resource.bytesPerRow * resource.height
                )
                continue
            }
            guard layer.pixelData.count == expectedCount else { continue }
            layer.pixelData.withUnsafeBytes { bytes in
                guard let baseAddress = bytes.baseAddress else { return }
                texture.replace(
                    region: MTLRegionMake2D(0, 0, snapshot.width, snapshot.height),
                    mipmapLevel: 0,
                    slice: slice,
                    withBytes: baseAddress,
                    bytesPerRow: snapshot.width * 4,
                    bytesPerImage: layer.pixelData.count
                )
            }
        }
        withCacheLock {
            cachedSignature = signature
            cachedLayerTexture = texture
        }
        return texture
    }

    private static func dataStorageIdentity(_ data: Data) -> UInt {
        data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return 0 }
            return UInt(bitPattern: baseAddress)
        }
    }

    private static func handleIdentity(_ handle: MetalBufferHandle) -> UInt {
        UInt(bitPattern: handle.id.uuidString.hashValue)
    }

    func makeBuffer<T>(_ values: [T]) -> MTLBuffer? {
        guard !values.isEmpty else {
            return device?.makeBuffer(length: MemoryLayout<T>.stride, options: .storageModeShared)
        }
        return values.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return nil }
            return device?.makeBuffer(bytes: baseAddress, length: bytes.count, options: .storageModeShared)
        }
    }

    func makeBuffer<T>(_ value: T) -> MTLBuffer? {
        var mutableValue = value
        return withUnsafeBytes(of: &mutableValue) { bytes in
            guard let baseAddress = bytes.baseAddress else { return nil }
            return device?.makeBuffer(bytes: baseAddress, length: bytes.count, options: .storageModeShared)
        }
    }

    func makeBuffer(_ data: Data) -> MTLBuffer? {
        data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return nil }
            return device?.makeBuffer(bytes: baseAddress, length: data.count, options: .storageModeShared)
        }
    }

    func makeBuffer(_ values: [UInt8]) -> MTLBuffer? {
        values.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return nil }
            return device?.makeBuffer(bytes: baseAddress, length: values.count, options: .storageModeShared)
        }
    }

    func makeBuffer(from source: MTLBuffer, count: Int) -> MTLBuffer? {
        guard count > 0 else { return device?.makeBuffer(length: 1, options: .storageModeShared) }
        return device?.makeBuffer(bytes: source.contents(), length: count, options: .storageModeShared)
    }

    func makeLayerSourceBuffer(pixelData: Data, bufferHandle: MetalBufferHandle?, expectedCount: Int) -> MTLBuffer? {
        if let bufferHandle,
           bufferHandle.bytesPerRow * bufferHandle.height == expectedCount,
           let resource = cachedBufferResource(for: bufferHandle) {
            return resource.buffer
        }
        guard pixelData.count == expectedCount else { return nil }
        return makeBuffer(pixelData)
    }

    func bytes(from buffer: MTLBuffer, count: Int) -> Data {
        Data(bytes: buffer.contents(), count: count)
    }

    func byteArray(from buffer: MTLBuffer, count: Int) -> [UInt8] {
        Array(UnsafeBufferPointer(start: buffer.contents().assumingMemoryBound(to: UInt8.self), count: count))
    }

    private func mutateMask(_ source: [UInt8], pipeline: MTLComputePipelineState?, radius: Int) -> [UInt8]? {
        guard
            let commandQueue,
            let pipeline,
            let inputBuffer = makeBuffer(source),
            let outputBuffer = device?.makeBuffer(length: source.count, options: .storageModeShared),
            let requestBuffer = makeBuffer(
                PrimoMetalMaskKernelDescriptor(
                    width: UInt32(source.isEmpty ? 0 : source.count),
                    height: 1,
                    radius: UInt32(radius)
                )
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(requestBuffer, offset: 0, index: 2)
        dispatchLinear(encoder: encoder, pipeline: pipeline, count: source.count)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return byteArray(from: outputBuffer, count: source.count)
    }

    private func iterateMask(
        _ source: [UInt8],
        width: Int,
        height: Int,
        iterations: Int,
        pipeline: MTLComputePipelineState?
    ) -> [UInt8]? {
        guard iterations > 0 else { return source }
        guard
            let device,
            let commandQueue,
            let pipeline,
            let first = makeBuffer(source),
            let second = device.makeBuffer(length: source.count, options: .storageModeShared),
            let requestBuffer = makeBuffer(
                PrimoMetalMaskKernelDescriptor(
                    width: UInt32(width),
                    height: UInt32(height),
                    radius: 1
                )
            )
        else {
            return nil
        }

        var buffers = PrimoMetalBufferPair(current: first, scratch: second)
        for _ in 0..<iterations {
            guard
                let commandBuffer = commandQueue.makeCommandBuffer(),
                let encoder = commandBuffer.makeComputeCommandEncoder()
            else {
                return nil
            }

            encoder.setComputePipelineState(pipeline)
            encoder.setBuffer(buffers.current, offset: 0, index: 0)
            encoder.setBuffer(buffers.scratch, offset: 0, index: 1)
            encoder.setBuffer(requestBuffer, offset: 0, index: 2)
            dispatch2D(encoder: encoder, pipeline: pipeline, width: width, height: height)
            encoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            guard commandBuffer.status == .completed else { return nil }
            swap(&buffers.current, &buffers.scratch)
        }
        return byteArray(from: buffers.current, count: source.count)
    }

    private func bytes(
        from buffer: MTLBuffer,
        dirtyRect: PrimoMetalStrokeDirtyRect,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> Data? {
        guard dirtyRect.originX >= 0, dirtyRect.originY >= 0 else { return nil }
        guard dirtyRect.originX + dirtyRect.width <= canvasWidth else { return nil }
        guard dirtyRect.originY + dirtyRect.height <= canvasHeight else { return nil }
        var data = Data(count: dirtyRect.width * dirtyRect.height * 4)
        let source = buffer.contents().assumingMemoryBound(to: UInt8.self)
        data.withUnsafeMutableBytes { destinationBytes in
            guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for row in 0..<dirtyRect.height {
                let srcOffset = ((dirtyRect.originY + row) * canvasWidth + dirtyRect.originX) * 4
                let dstOffset = row * dirtyRect.width * 4
                memcpy(destination + dstOffset, source + srcOffset, dirtyRect.width * 4)
            }
        }
        return data
    }

    func dispatch2D(
        encoder: MTLComputeCommandEncoder,
        pipeline: MTLComputePipelineState,
        width: Int,
        height: Int
    ) {
        let threadWidth = min(pipeline.threadExecutionWidth, max(width, 1))
        let threadHeight = max(1, min(pipeline.maxTotalThreadsPerThreadgroup / max(threadWidth, 1), 8))
        encoder.dispatchThreads(
            MTLSize(width: max(width, 1), height: max(height, 1), depth: 1),
            threadsPerThreadgroup: MTLSize(width: threadWidth, height: threadHeight, depth: 1)
        )
    }

    private func dispatchLinear(
        encoder: MTLComputeCommandEncoder,
        pipeline: MTLComputePipelineState,
        count: Int
    ) {
        let width = max(1, min(pipeline.threadExecutionWidth, count))
        encoder.dispatchThreads(
            MTLSize(width: max(count, 1), height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
        )
    }

    static func makePipeline(device: MTLDevice?, library: MTLLibrary?, functionName: String) -> MTLComputePipelineState? {
        guard let device, let function = library?.makeFunction(name: functionName) else { return nil }
        return try? device.makeComputePipelineState(function: function)
    }

    private static func makeLayerDescriptor(for layer: MetalLayerSnapshot) -> PrimoMetalCompositeLayerDescriptor {
        PrimoMetalCompositeLayerDescriptor(
            documentIndex: Int32(layer.index),
            opacity: layer.opacity,
            visible: layer.visible ? 1 : 0,
            isClipped: layer.isClipped ? 1 : 0,
            blendMode: Int32(blendModeIdentifier(layer.blendMode))
        )
    }

    static func strokeSampleDescriptors(samples: [StylusSample]) -> [PrimoMetalStrokeSampleDescriptor] {
        let progressTable = strokeProgressTable(samples)
        return zip(samples, progressTable).map { sample, progress in
            PrimoMetalStrokeSampleDescriptor(
                x: Float(sample.point.x),
                y: Float(sample.point.y),
                pressure: Float(sample.pressure),
                progress: Float(progress)
            )
        }
    }

    private static func normalizedCommittedStrokeSamples(_ samples: [StylusSample], brush: BrushRuntimeSettings) -> [StylusSample] {
        var normalized = samples.map { sample in
            StylusSample(
                point: CGPoint(x: sample.point.x.isFinite ? sample.point.x : 0, y: sample.point.y.isFinite ? sample.point.y : 0),
                pressure: sample.pressure.isFinite ? sample.pressure : 1.0,
                altitude: sample.altitude.isFinite ? sample.altitude : .pi / 2,
                azimuth: sample.azimuth.isFinite ? sample.azimuth : 0,
                timestamp: sample.timestamp.isFinite ? sample.timestamp : 0
            )
        }
        guard normalized.count > 1 else { return normalized }
        let jumpThreshold = max(CGFloat(brush.radius) * 8.0, 24.0)
        while normalized.count > 1 {
            let last = normalized[normalized.count - 1]
            let previous = normalized[normalized.count - 2]
            let dx = last.point.x - previous.point.x
            let dy = last.point.y - previous.point.y
            let distance = sqrt((dx * dx) + (dy * dy))
            let pressureDropThreshold = max(0.08, previous.pressure * 0.5)
            if !(distance > jumpThreshold && last.pressure < pressureDropThreshold) { break }
            normalized.removeLast()
        }
        var deduplicated: [StylusSample] = []
        deduplicated.reserveCapacity(normalized.count)
        for sample in normalized {
            if let previous = deduplicated.last {
                let dx = sample.point.x - previous.point.x
                let dy = sample.point.y - previous.point.y
                if sqrt((dx * dx) + (dy * dy)) < 0.001 && abs(sample.pressure - previous.pressure) < 0.001 {
                    continue
                }
            }
            deduplicated.append(sample)
        }
        return deduplicated
    }

    private static func strokeProgressTable(_ samples: [StylusSample]) -> [CGFloat] {
        guard !samples.isEmpty else { return [] }
        guard samples.count > 1 else { return [0] }
        var cumulative: [CGFloat] = [0]
        cumulative.reserveCapacity(samples.count)
        var totalLength: CGFloat = 0
        for pair in zip(samples, samples.dropFirst()) {
            let dx = pair.1.point.x - pair.0.point.x
            let dy = pair.1.point.y - pair.0.point.y
            totalLength += sqrt((dx * dx) + (dy * dy))
            cumulative.append(totalLength)
        }
        guard totalLength > 0.001 else {
            return Array(repeating: 0, count: samples.count)
        }
        return cumulative.map { $0 / totalLength }
    }

    private static func strokePreviewDirtyRect(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> (originX: Int, originY: Int, width: Int, height: Int)? {
        guard !samples.isEmpty, canvasWidth > 0, canvasHeight > 0 else { return nil }
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        let scatterExtent = brush.scatterEnabled ? max(CGFloat(brush.scatterLateral), CGFloat(brush.scatterLinear)) : 0
        let softness = max(0, 1.0 - CGFloat(brush.hardness))
        let featherPadding = max(
            brush.tipKind == .airbrush ? CGFloat(brush.radius) * (0.9 + softness * 0.6) : CGFloat(brush.radius) * (0.35 + softness * 0.75),
            brush.tipKind == .airbrush ? 18.0 : 10.0
        )
        for sample in samples {
            let pressureFactor = max(0.1, 1.0 + ((sample.pressure - 1.0) * CGFloat(brush.pressureSensitivity)))
            let radiusPadding = max(CGFloat(brush.radius) * pressureFactor, 1.5)
                + (scatterExtent * CGFloat(brush.radius))
                + featherPadding
                + 6.0
            minX = min(minX, sample.point.x - radiusPadding)
            minY = min(minY, sample.point.y - radiusPadding)
            maxX = max(maxX, sample.point.x + radiusPadding)
            maxY = max(maxY, sample.point.y + radiusPadding)
        }
        guard minX.isFinite, minY.isFinite, maxX.isFinite, maxY.isFinite else { return nil }
        let originX = max(0, Int(floor(minX)))
        let originY = max(0, Int(floor(minY)))
        let maxRectX = min(canvasWidth - 1, Int(ceil(maxX)))
        let maxRectY = min(canvasHeight - 1, Int(ceil(maxY)))
        guard maxRectX >= originX, maxRectY >= originY else { return nil }
        return (originX, originY, maxRectX - originX + 1, maxRectY - originY + 1)
    }

    private static func clippedRect(
        from rect: CGRect
    ) -> (originX: Int, originY: Int, width: Int, height: Int) {
        guard
            rect.origin.x.isFinite,
            rect.origin.y.isFinite,
            rect.width.isFinite,
            rect.height.isFinite
        else {
            return (originX: 0, originY: 0, width: 0, height: 0)
        }
        return (
            originX: Int(rect.origin.x),
            originY: Int(rect.origin.y),
            width: Int(rect.width),
            height: Int(rect.height)
        )
    }

    private static func union(
        _ lhs: (originX: Int, originY: Int, width: Int, height: Int),
        _ rhs: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> (originX: Int, originY: Int, width: Int, height: Int) {
        let minX = min(lhs.originX, rhs.originX)
        let minY = min(lhs.originY, rhs.originY)
        let maxX = max(lhs.originX + lhs.width, rhs.originX + rhs.width)
        let maxY = max(lhs.originY + lhs.height, rhs.originY + rhs.height)
        return (minX, minY, maxX - minX, maxY - minY)
    }

    private func makeStrokeBinningResources(
        commandBuffer: MTLCommandBuffer,
        descriptors: [PrimoMetalStrokeSampleDescriptor],
        sampleBuffer: MTLBuffer,
        brush: BrushRuntimeSettings,
        brushBuffer: MTLBuffer,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int),
        canvasWidth: Int,
        canvasHeight: Int
    ) -> StrokeBinningResources? {
        guard
            let device,
            let primitiveGenerationPipeline = strokePrimitiveGenerationPipeline,
            let tileCountPipeline = strokeTileCountPipeline,
            let prefixScanPipeline = strokePrefixScanPipeline,
            let prefixBlockScanPipeline = strokePrefixBlockScanPipeline,
            let prefixAddPipeline = strokePrefixAddPipeline,
            let tileRangePipeline = strokeTileRangePipeline,
            let cursorInitPipeline = strokeCursorInitPipeline,
            let primitiveScatterPipeline = strokePrimitiveScatterPipeline
        else {
            return nil
        }

        let primitiveCount = max(1, descriptors.count > 1 ? descriptors.count - 1 : 1)
        let tileSize = Self.strokeTileSize
        let tileColumns = max(1, (dirtyRect.width + tileSize - 1) / tileSize)
        let tileRows = max(1, (dirtyRect.height + tileSize - 1) / tileSize)
        let tileCount = tileColumns * tileRows
        let blockSize = Self.strokePrefixBlockSize
        let blockCount = max(1, (tileCount + blockSize - 1) / blockSize)
        let maxPrimitiveIndexCount = max(primitiveCount, primitiveCount * tileCount)

        let requestDescriptor = PrimoMetalStrokeRasterRequestDescriptor(
            canvasWidth: UInt32(canvasWidth),
            canvasHeight: UInt32(canvasHeight),
            originX: UInt32(dirtyRect.originX),
            originY: UInt32(dirtyRect.originY),
            rectWidth: UInt32(dirtyRect.width),
            rectHeight: UInt32(dirtyRect.height),
            sampleCount: UInt32(primitiveCount),
            inputSampleCount: UInt32(descriptors.count),
            tileSize: UInt32(tileSize),
            tileColumns: UInt32(tileColumns),
            tileRows: UInt32(tileRows),
            tileCount: UInt32(tileCount),
            maxPrimitiveIndexCount: UInt32(maxPrimitiveIndexCount),
            prefixBlockSize: UInt32(blockSize)
        )

        guard
            let requestBuffer = makeBuffer(requestDescriptor),
            let prefixDescriptorBuffer = makeBuffer(
                PrimoMetalStrokePrefixDescriptor(
                    elementCount: UInt32(tileCount),
                    blockSize: UInt32(blockSize)
                )
            ),
            let blockPrefixDescriptorBuffer = makeBuffer(
                PrimoMetalStrokePrefixDescriptor(
                    elementCount: UInt32(blockCount),
                    blockSize: UInt32(blockSize)
                )
            ),
            let primitiveBuffer = device.makeBuffer(
                length: primitiveCount * MemoryLayout<PrimoMetalStrokePrimitiveDescriptor>.stride,
                options: .storageModeShared
            ),
            let tileCountBuffer = device.makeBuffer(
                length: tileCount * MemoryLayout<UInt32>.stride,
                options: .storageModeShared
            ),
            let tileOffsetBuffer = device.makeBuffer(
                length: tileCount * MemoryLayout<UInt32>.stride,
                options: .storageModeShared
            ),
            let tileRangeBuffer = device.makeBuffer(
                length: tileCount * MemoryLayout<PrimoMetalStrokeTileRangeDescriptor>.stride,
                options: .storageModeShared
            ),
            let blockSumBuffer = device.makeBuffer(
                length: blockCount * MemoryLayout<UInt32>.stride,
                options: .storageModeShared
            ),
            let blockOffsetBuffer = device.makeBuffer(
                length: blockCount * MemoryLayout<UInt32>.stride,
                options: .storageModeShared
            ),
            let primitiveIndexCursorBuffer = device.makeBuffer(
                length: tileCount * MemoryLayout<UInt32>.stride,
                options: .storageModeShared
            ),
            let primitiveIndexBuffer = device.makeBuffer(
                length: maxPrimitiveIndexCount * MemoryLayout<UInt32>.stride,
                options: .storageModeShared
            )
        else {
            return nil
        }

        memset(tileCountBuffer.contents(), 0, tileCount * MemoryLayout<UInt32>.stride)
        memset(tileOffsetBuffer.contents(), 0, tileCount * MemoryLayout<UInt32>.stride)
        memset(tileRangeBuffer.contents(), 0, tileCount * MemoryLayout<PrimoMetalStrokeTileRangeDescriptor>.stride)
        memset(blockSumBuffer.contents(), 0, blockCount * MemoryLayout<UInt32>.stride)
        memset(blockOffsetBuffer.contents(), 0, blockCount * MemoryLayout<UInt32>.stride)
        memset(primitiveIndexCursorBuffer.contents(), 0, tileCount * MemoryLayout<UInt32>.stride)
        memset(primitiveIndexBuffer.contents(), 0, maxPrimitiveIndexCount * MemoryLayout<UInt32>.stride)

        guard let primitiveEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        primitiveEncoder.setComputePipelineState(primitiveGenerationPipeline)
        primitiveEncoder.setBuffer(sampleBuffer, offset: 0, index: 0)
        primitiveEncoder.setBuffer(primitiveBuffer, offset: 0, index: 1)
        primitiveEncoder.setBuffer(brushBuffer, offset: 0, index: 2)
        primitiveEncoder.setBuffer(requestBuffer, offset: 0, index: 3)
        dispatchLinear(encoder: primitiveEncoder, pipeline: primitiveGenerationPipeline, count: primitiveCount)
        primitiveEncoder.endEncoding()

        guard let countEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        countEncoder.setComputePipelineState(tileCountPipeline)
        countEncoder.setBuffer(primitiveBuffer, offset: 0, index: 0)
        countEncoder.setBuffer(tileCountBuffer, offset: 0, index: 1)
        countEncoder.setBuffer(brushBuffer, offset: 0, index: 2)
        countEncoder.setBuffer(requestBuffer, offset: 0, index: 3)
        dispatchLinear(encoder: countEncoder, pipeline: tileCountPipeline, count: primitiveCount)
        countEncoder.endEncoding()

        guard let prefixEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        prefixEncoder.setComputePipelineState(prefixScanPipeline)
        prefixEncoder.setBuffer(tileCountBuffer, offset: 0, index: 0)
        prefixEncoder.setBuffer(tileOffsetBuffer, offset: 0, index: 1)
        prefixEncoder.setBuffer(blockSumBuffer, offset: 0, index: 2)
        prefixEncoder.setBuffer(prefixDescriptorBuffer, offset: 0, index: 3)
        dispatchLinear(encoder: prefixEncoder, pipeline: prefixScanPipeline, count: blockCount)
        prefixEncoder.endEncoding()

        guard let blockPrefixEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        blockPrefixEncoder.setComputePipelineState(prefixBlockScanPipeline)
        blockPrefixEncoder.setBuffer(blockSumBuffer, offset: 0, index: 0)
        blockPrefixEncoder.setBuffer(blockOffsetBuffer, offset: 0, index: 1)
        blockPrefixEncoder.setBuffer(blockPrefixDescriptorBuffer, offset: 0, index: 2)
        dispatchLinear(encoder: blockPrefixEncoder, pipeline: prefixBlockScanPipeline, count: 1)
        blockPrefixEncoder.endEncoding()

        guard let addEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        addEncoder.setComputePipelineState(prefixAddPipeline)
        addEncoder.setBuffer(tileOffsetBuffer, offset: 0, index: 0)
        addEncoder.setBuffer(blockOffsetBuffer, offset: 0, index: 1)
        addEncoder.setBuffer(prefixDescriptorBuffer, offset: 0, index: 2)
        dispatchLinear(encoder: addEncoder, pipeline: prefixAddPipeline, count: tileCount)
        addEncoder.endEncoding()

        guard let tileRangeEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        tileRangeEncoder.setComputePipelineState(tileRangePipeline)
        tileRangeEncoder.setBuffer(tileCountBuffer, offset: 0, index: 0)
        tileRangeEncoder.setBuffer(tileOffsetBuffer, offset: 0, index: 1)
        tileRangeEncoder.setBuffer(tileRangeBuffer, offset: 0, index: 2)
        tileRangeEncoder.setBuffer(prefixDescriptorBuffer, offset: 0, index: 3)
        dispatchLinear(encoder: tileRangeEncoder, pipeline: tileRangePipeline, count: tileCount)
        tileRangeEncoder.endEncoding()

        guard let cursorEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        cursorEncoder.setComputePipelineState(cursorInitPipeline)
        cursorEncoder.setBuffer(tileOffsetBuffer, offset: 0, index: 0)
        cursorEncoder.setBuffer(primitiveIndexCursorBuffer, offset: 0, index: 1)
        cursorEncoder.setBuffer(prefixDescriptorBuffer, offset: 0, index: 2)
        dispatchLinear(encoder: cursorEncoder, pipeline: cursorInitPipeline, count: tileCount)
        cursorEncoder.endEncoding()

        guard let scatterEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        scatterEncoder.setComputePipelineState(primitiveScatterPipeline)
        scatterEncoder.setBuffer(primitiveBuffer, offset: 0, index: 0)
        scatterEncoder.setBuffer(primitiveIndexCursorBuffer, offset: 0, index: 1)
        scatterEncoder.setBuffer(primitiveIndexBuffer, offset: 0, index: 2)
        scatterEncoder.setBuffer(brushBuffer, offset: 0, index: 3)
        scatterEncoder.setBuffer(requestBuffer, offset: 0, index: 4)
        dispatchLinear(encoder: scatterEncoder, pipeline: primitiveScatterPipeline, count: primitiveCount)
        scatterEncoder.endEncoding()

        return StrokeBinningResources(
            primitiveBuffer: primitiveBuffer,
            tileRangeBuffer: tileRangeBuffer,
            primitiveIndexBuffer: primitiveIndexBuffer,
            requestDescriptor: requestDescriptor
        )
    }

    private static func makeStrokeBrushDescriptor(_ brush: BrushRuntimeSettings, customTip: BrushTipRaster) -> PrimoMetalStrokeBrushDescriptor {
        let profile = strokeRasterProfile(for: brush)
        return PrimoMetalStrokeBrushDescriptor(
            radius: Float(brush.radius),
            pressureSensitivity: Float(brush.pressureSensitivity),
            taperIn: Float(brush.taperIn),
            taperOut: Float(brush.taperOut),
            opacity: Float(brush.opacity),
            flow: Float(brush.flow),
            hardness: Float(brush.hardness),
            opacityPressureSensitivity: Float(brush.opacityPressureSensitivity),
            flowPressureSensitivity: Float(brush.flowPressureSensitivity),
            grainScale: Float(brush.grainScale),
            grainContrast: Float(brush.grainContrast),
            paperScale: Float(brush.paperScale),
            paperStrength: Float(brush.paperStrength),
            paperThreshold: Float(brush.paperThreshold),
            textureStrength: Float(brush.textureStrength),
            wetness: profile.wetness,
            colorMixStrength: profile.colorMixStrength,
            smudgeBleed: profile.smudgeBleed,
            smudgeRadius: profile.smudgeRadius,
            paintLoad: profile.paintLoad,
            loadPressureSensitivity: Float(min(max(brush.loadPressureSensitivity, 0.0), 1.0)),
            smudgeLength: Float(min(max(brush.smudgeLength, 0.0), 1.0)),
            colorRate: Float(min(max(brush.colorRate, 0.0), 1.0)),
            red: Float(brush.red) / 255.0,
            green: Float(brush.green) / 255.0,
            blue: Float(brush.blue) / 255.0,
            scatterLateral: Float(brush.scatterEnabled ? brush.scatterLateral : 0),
            scatterLinear: Float(brush.scatterEnabled ? brush.scatterLinear : 0),
            count: Float(max(1, brush.count)),
            countJitter: Float(max(0.0, brush.countJitter)),
            countSizeJitter: Float(max(0.0, brush.countSizeJitter)),
            countOpacityJitter: Float(max(0.0, brush.countOpacityJitter)),
            dualScale: Float(brush.dualBrushEnabled ? brush.dualScale : 0),
            dualSpacing: Float(brush.dualBrushEnabled ? brush.dualSpacing : 0),
            dualScatter: Float(brush.dualBrushEnabled ? brush.dualScatter : 0),
            customTipWidth: UInt32(customTip.width),
            customTipHeight: UInt32(customTip.height),
            isEraser: brush.isEraser ? 1 : 0,
            isPencil: brush.tipKind == .pencil ? 1 : 0,
            isOil: brush.tipKind == .oil ? 1 : 0,
            isAirbrush: brush.tipKind == .airbrush ? 1 : 0,
            dualBrushEnabled: brush.dualBrushEnabled ? 1 : 0,
            customTipEnabled: brush.customTip == nil ? 0 : 1,
            scatterMode: brush.scatterMode == .spray ? 1 : 0,
            textureMode: {
                switch brush.textureMode {
                case .off: return 0
                case .strokeLocked: return 1
                case .eachTip: return 2
                case .moving: return 3
                }
            }(),
            dualBlendMode: {
                switch brush.dualBlendMode {
                case .multiply: return 0
                case .darker: return 1
                case .subtract: return 2
                }
            }(),
            colorMixingMode: {
                switch brush.colorMixingMode {
                case .off: return 0
                case .blend: return 1
                case .runningColor: return 2
                case .smear: return 3
                }
            }(),
            smudgeMode: {
                switch brush.smudgeMode {
                case .smearing: return 0
                case .dulling: return 1
                }
            }()
        )
    }

    private static func supportsStrokeRasterization(_ brush: BrushRuntimeSettings) -> Bool {
        brush.radius >= 0.5
    }

    private static func makeColorSmudgeDabs(
        samples: [StylusSample],
        progressTable: [CGFloat],
        brush: BrushRuntimeSettings,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> [PrimoMetalColorSmudgeDab] {
        guard let first = samples.first else { return [] }
        var dabs: [PrimoMetalColorSmudgeDab] = []
        let firstRadius = resolvedSmudgeStrokeRadius(for: first, progress: progressTable.first ?? 0, brush: brush)
        if let firstDab = makeColorSmudgeDab(
            sample: first,
            progress: progressTable.first ?? 0,
            radius: firstRadius,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        ) {
            dabs.append(firstDab)
        }

        guard samples.count > 1 else { return dabs }

        for index in samples.indices.dropFirst() {
            let start = samples[index - 1]
            let end = samples[index]
            let startProgress = progressTable[index - 1]
            let endProgress = progressTable[index]
            let startRadius = resolvedSmudgeStrokeRadius(for: start, progress: startProgress, brush: brush)
            let endRadius = resolvedSmudgeStrokeRadius(for: end, progress: endProgress, brush: brush)
            let dx = end.point.x - start.point.x
            let dy = end.point.y - start.point.y
            let distance = sqrt((dx * dx) + (dy * dy))
            let spacing = max(1.0, ((startRadius + endRadius) * 0.5) * max(CGFloat(brush.stampSpacing), 0.02))
            guard distance.isFinite, spacing.isFinite, spacing > 0 else { continue }
            let steps = max(1, Int(ceil(distance / spacing)))
            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                let interpolated = interpolatedStylusSample(from: start, to: end, progress: t)
                let progress = startProgress + ((endProgress - startProgress) * t)
                let radius = resolvedSmudgeStrokeRadius(for: interpolated, progress: progress, brush: brush)
                if let dab = makeColorSmudgeDab(
                    sample: interpolated,
                    progress: progress,
                    radius: radius,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight
                ) {
                    dabs.append(dab)
                }
            }
        }
        return dabs
    }

    private static func makeColorSmudgeDab(
        sample: StylusSample,
        progress: CGFloat,
        radius: CGFloat,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> PrimoMetalColorSmudgeDab? {
        guard sample.point.x.isFinite, sample.point.y.isFinite, progress.isFinite, radius.isFinite else { return nil }
        let margin = max(2.0, radius + 2.0)
        guard margin.isFinite else { return nil }
        let rawRect = CGRect(
            x: floor(sample.point.x - margin),
            y: floor(sample.point.y - margin),
            width: ceil(margin * 2.0),
            height: ceil(margin * 2.0)
        )
        guard rawRect.origin.x.isFinite, rawRect.origin.y.isFinite, rawRect.width.isFinite, rawRect.height.isFinite else {
            return nil
        }
        let clipped = rawRect.intersection(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
        guard clipped.origin.x.isFinite, clipped.origin.y.isFinite, clipped.width.isFinite, clipped.height.isFinite else {
            return nil
        }
        return PrimoMetalColorSmudgeDab(
            center: sample.point,
            radius: radius,
            progress: progress,
            sample: sample,
            destinationRect: clipped
        )
    }

    private static func resolvedSmudgeStrokeRadius(
        for sample: StylusSample,
        progress: CGFloat,
        brush: BrushRuntimeSettings
    ) -> CGFloat {
        let clampedPressure = max(0.08, min(sample.pressure, 1.0))
        let pressureFactor = max(0.1, 1.0 + ((clampedPressure - 1.0) * CGFloat(brush.pressureSensitivity)))
        let taper = strokeTaperScale(progress: progress, taperIn: CGFloat(brush.taperIn), taperOut: CGFloat(brush.taperOut))
        return max(CGFloat(brush.radius) * pressureFactor * taper, 1.5)
    }

    private static func strokeTaperScale(progress: CGFloat, taperIn: CGFloat, taperOut: CGFloat) -> CGFloat {
        func easedRamp(_ progress: CGFloat, length: CGFloat) -> CGFloat {
            guard length > 0.001 else { return 1.0 }
            let t = max(0.0, min(1.0, progress / length))
            let eased = t * t * (3.0 - (2.0 * t))
            return 0.08 + (0.92 * eased)
        }

        let entry = easedRamp(progress, length: taperIn)
        let exit = easedRamp(1.0 - progress, length: taperOut)
        return min(entry, exit)
    }

    private static func interpolatedStylusSample(from start: StylusSample, to end: StylusSample, progress t: CGFloat) -> StylusSample {
        StylusSample(
            point: CGPoint(
                x: start.point.x + ((end.point.x - start.point.x) * t),
                y: start.point.y + ((end.point.y - start.point.y) * t)
            ),
            pressure: start.pressure + ((end.pressure - start.pressure) * t),
            altitude: start.altitude + ((end.altitude - start.altitude) * t),
            azimuth: start.azimuth + ((end.azimuth - start.azimuth) * t),
            timestamp: start.timestamp + ((end.timestamp - start.timestamp) * Double(t))
        )
    }

    private func preprocessStrokeSamples(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> (
        descriptors: [PrimoMetalStrokeSampleDescriptor],
        sampleBuffer: MTLBuffer,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)?
    )? {
        guard
            !samples.isEmpty,
            let commandQueue,
            let pipeline = strokePreprocessPipeline,
            let summaryBuffer = device?.makeBuffer(length: MemoryLayout<PrimoMetalStrokePreprocessSummary>.stride, options: .storageModeShared),
            let descriptorBuffer = device?.makeBuffer(
                length: max(samples.count, 1) * MemoryLayout<PrimoMetalStrokeSampleDescriptor>.stride,
                options: .storageModeShared
            ),
            let requestBuffer = makeBuffer(
                PrimoMetalStrokePreprocessDescriptor(
                    sampleCount: UInt32(samples.count),
                    canvasWidth: UInt32(canvasWidth),
                    canvasHeight: UInt32(canvasHeight),
                    radius: Float(brush.radius),
                    pressureSensitivity: Float(brush.pressureSensitivity),
                    taperIn: Float(brush.taperIn),
                    taperOut: Float(brush.taperOut),
                    hardness: Float(brush.hardness),
                    scatterLateral: Float(brush.scatterEnabled ? brush.scatterLateral : 0),
                    scatterLinear: Float(brush.scatterEnabled ? brush.scatterLinear : 0),
                    scatterEnabled: brush.scatterEnabled ? 1 : 0,
                    isAirbrush: brush.tipKind == .airbrush ? 1 : 0
                )
            ),
            let rawSampleBuffer = makeBuffer(samples.map {
                PrimoMetalRawStrokeSample(
                    x: Float($0.point.x),
                    y: Float($0.point.y),
                    pressure: Float($0.pressure),
                    altitude: Float($0.altitude),
                    azimuth: Float($0.azimuth),
                    timestamp: Float($0.timestamp)
                )
            }),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        memset(summaryBuffer.contents(), 0, MemoryLayout<PrimoMetalStrokePreprocessSummary>.stride)
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(rawSampleBuffer, offset: 0, index: 0)
        encoder.setBuffer(descriptorBuffer, offset: 0, index: 1)
        encoder.setBuffer(summaryBuffer, offset: 0, index: 2)
        encoder.setBuffer(requestBuffer, offset: 0, index: 3)
        dispatchLinear(encoder: encoder, pipeline: pipeline, count: 1)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }

        let summary = summaryBuffer.contents().assumingMemoryBound(to: PrimoMetalStrokePreprocessSummary.self).pointee
        let effectiveCount = Int(summary.effectiveSampleCount)
        guard effectiveCount > 0 else { return nil }
        let base = descriptorBuffer.contents().assumingMemoryBound(to: PrimoMetalStrokeSampleDescriptor.self)
        let descriptors = Array(UnsafeBufferPointer(start: base, count: effectiveCount))
        let dirtyRect = summary.dirtyWidth > 0 && summary.dirtyHeight > 0
            ? (
                originX: Int(summary.dirtyOriginX),
                originY: Int(summary.dirtyOriginY),
                width: Int(summary.dirtyWidth),
                height: Int(summary.dirtyHeight)
            )
            : nil
        return (descriptors: descriptors, sampleBuffer: descriptorBuffer, dirtyRect: dirtyRect)
    }

    private func generateColorSmudgeDabDescriptors(
        descriptors: [PrimoMetalStrokeSampleDescriptor],
        sampleBuffer: MTLBuffer,
        brush: BrushRuntimeSettings,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> (
        descriptors: [PrimoMetalColorSmudgeDabDescriptor],
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)?
    )? {
        guard
            !descriptors.isEmpty,
            let commandQueue,
            let countPipeline = smudgeDabCountPipeline,
            let generationPipeline = smudgeDabGenerationPipeline,
            let brushBuffer = makeBuffer(Self.makeStrokeBrushDescriptor(brush, customTip: BrushTipRaster(width: 1, height: 1, alphaData: Data([255])))),
            let generationDescriptorBuffer = makeBuffer(
                PrimoMetalSmudgeDabGenerationDescriptor(
                    sampleCount: UInt32(descriptors.count),
                    canvasWidth: UInt32(canvasWidth),
                    canvasHeight: UInt32(canvasHeight),
                    stampSpacing: Float(max(CGFloat(brush.stampSpacing), 0.02))
                )
            ),
            let countSummaryBuffer = device?.makeBuffer(length: MemoryLayout<PrimoMetalSmudgeDabCountSummary>.stride, options: .storageModeShared)
        else {
            return nil
        }

        guard let countCommandBuffer = commandQueue.makeCommandBuffer(),
              let countEncoder = countCommandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        memset(countSummaryBuffer.contents(), 0, MemoryLayout<PrimoMetalSmudgeDabCountSummary>.stride)
        countEncoder.setComputePipelineState(countPipeline)
        countEncoder.setBuffer(sampleBuffer, offset: 0, index: 0)
        countEncoder.setBuffer(countSummaryBuffer, offset: 0, index: 1)
        countEncoder.setBuffer(brushBuffer, offset: 0, index: 2)
        countEncoder.setBuffer(generationDescriptorBuffer, offset: 0, index: 3)
        dispatchLinear(encoder: countEncoder, pipeline: countPipeline, count: 1)
        countEncoder.endEncoding()
        countCommandBuffer.commit()
        countCommandBuffer.waitUntilCompleted()
        guard countCommandBuffer.status == .completed else { return nil }

        let dabCount = Int(countSummaryBuffer.contents().assumingMemoryBound(to: PrimoMetalSmudgeDabCountSummary.self).pointee.dabCount)
        guard dabCount > 0,
              let dabBuffer = device?.makeBuffer(
                length: dabCount * MemoryLayout<PrimoMetalColorSmudgeDabDescriptor>.stride,
                options: .storageModeShared
              ),
              let generationSummaryBuffer = device?.makeBuffer(
                length: MemoryLayout<PrimoMetalSmudgeDabGenerationSummary>.stride,
                options: .storageModeShared
              ),
              let generationCommandBuffer = commandQueue.makeCommandBuffer(),
              let generationEncoder = generationCommandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        memset(generationSummaryBuffer.contents(), 0, MemoryLayout<PrimoMetalSmudgeDabGenerationSummary>.stride)
        generationEncoder.setComputePipelineState(generationPipeline)
        generationEncoder.setBuffer(sampleBuffer, offset: 0, index: 0)
        generationEncoder.setBuffer(dabBuffer, offset: 0, index: 1)
        generationEncoder.setBuffer(generationSummaryBuffer, offset: 0, index: 2)
        generationEncoder.setBuffer(brushBuffer, offset: 0, index: 3)
        generationEncoder.setBuffer(generationDescriptorBuffer, offset: 0, index: 4)
        dispatchLinear(encoder: generationEncoder, pipeline: generationPipeline, count: 1)
        generationEncoder.endEncoding()
        generationCommandBuffer.commit()
        generationCommandBuffer.waitUntilCompleted()
        guard generationCommandBuffer.status == .completed else { return nil }

        let summary = generationSummaryBuffer.contents().assumingMemoryBound(to: PrimoMetalSmudgeDabGenerationSummary.self).pointee
        let generatedCount = Int(summary.dabCount)
        let base = dabBuffer.contents().assumingMemoryBound(to: PrimoMetalColorSmudgeDabDescriptor.self)
        let generatedDescriptors = Array(UnsafeBufferPointer(start: base, count: generatedCount))
        let dirtyRect = summary.dirtyWidth > 0 && summary.dirtyHeight > 0
            ? (
                originX: Int(summary.dirtyOriginX),
                originY: Int(summary.dirtyOriginY),
                width: Int(summary.dirtyWidth),
                height: Int(summary.dirtyHeight)
            )
            : nil
        return (descriptors: generatedDescriptors, dirtyRect: dirtyRect)
    }

    private func resolvedCustomTipMask(_ raster: BrushTipRaster?) -> BrushTipRaster {
        guard let raster else { return BrushTipRaster(width: 1, height: 1, alphaData: Data([255])) }
        guard raster.width > 0, raster.height > 0, raster.alphaData.count == raster.width * raster.height else {
            return BrushTipRaster(width: 1, height: 1, alphaData: Data([255]))
        }
        let cacheKey = BrushTipCacheKey(width: raster.width, height: raster.height, digest: raster.alphaData.hashValue)
        if let cached = withCacheLock({ cachedScaledBrushTips[cacheKey] }) {
            return cached
        }
        let maxDimension = 64
        if max(raster.width, raster.height) <= maxDimension {
            withCacheLock {
                cachedScaledBrushTips[cacheKey] = raster
            }
            return raster
        }
        let scale = min(Double(maxDimension) / Double(raster.width), Double(maxDimension) / Double(raster.height))
        let targetWidth = max(1, Int((Double(raster.width) * scale).rounded(.toNearestOrEven)))
        let targetHeight = max(1, Int((Double(raster.height) * scale).rounded(.toNearestOrEven)))
        if let scaledData = scaledMaskData(
            raster.alphaData,
            sourceWidth: raster.width,
            sourceHeight: raster.height,
            targetWidth: targetWidth,
            targetHeight: targetHeight
        ) {
            let scaled = BrushTipRaster(width: targetWidth, height: targetHeight, alphaData: scaledData)
            withCacheLock {
                cachedScaledBrushTips[cacheKey] = scaled
            }
            return scaled
        }
        withCacheLock {
            cachedScaledBrushTips[cacheKey] = raster
        }
        return raster
    }

    private static func strokeRasterProfile(for brush: BrushRuntimeSettings) -> (wetness: Float, colorMixStrength: Float, smudgeBleed: Float, smudgeRadius: Float, paintLoad: Float) {
        switch brush.tipKind {
        case .pencil:
            return (0, 0, 0, 0, 1)
        case .ink:
            return (
                Float(min(max(brush.wetness * 0.35, 0), 0.22)),
                Float(min(max(brush.colorMixStrength * 0.28, 0), 0.18)),
                Float(min(max(brush.smudgeBleed * 0.22, 0), 0.16)),
                Float(min(max(brush.smudgeRadius * 0.20, 0), 0.18)),
                Float(max(0.82, min(brush.paintLoad, 1.0)))
            )
        case .oil:
            return (
                Float(min(max((brush.wetness * 0.88) + 0.08, 0), 1)),
                Float(min(max((brush.colorMixStrength * 0.92) + 0.06, 0), 1)),
                Float(min(max((brush.smudgeBleed * 0.78) + 0.08, 0), 1)),
                Float(min(max((brush.smudgeRadius * 0.82) + 0.06, 0), 1)),
                Float(min(max((brush.paintLoad * 0.90) + 0.05, 0.08), 1))
            )
        case .airbrush:
            return (
                Float(min(max(brush.wetness * 0.16, 0), 0.12)),
                Float(min(max(brush.colorMixStrength * 0.12, 0), 0.10)),
                0,
                Float(min(max(brush.smudgeRadius * 0.08, 0), 0.08)),
                Float(max(0.88, min(brush.paintLoad, 1.0)))
            )
        }
    }

    static func blendModeIdentifier(_ mode: LayerBlendMode) -> Int {
        switch mode {
        case .normal: return 0
        case .darken: return 1
        case .multiply: return 2
        case .colorBurn: return 3
        case .linearBurn: return 4
        case .subtract: return 5
        case .lighten: return 6
        case .screen: return 7
        case .colorDodge: return 8
        case .glowDodge: return 9
        case .overlay: return 10
        case .softLight: return 11
        case .hardLight: return 12
        case .difference: return 13
        case .vividLight: return 14
        case .linearLight: return 15
        case .pinLight: return 16
        case .hardMix: return 17
        case .exclusion: return 18
        case .darkerColor: return 19
        case .lighterColor: return 20
        case .divide: return 21
        case .hue: return 22
        case .saturation: return 23
        case .color: return 24
        case .add: return 25
        case .addGlow: return 26
        case .luminosity: return 27
        }
    }
}
