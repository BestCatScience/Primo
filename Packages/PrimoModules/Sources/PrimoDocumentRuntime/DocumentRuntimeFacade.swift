import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoCanvasPresentationDomain
import PrimoCanvasPresentationInfrastructure
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoDocumentGPUContracts
import PrimoDocumentMetalRuntimeInfrastructure
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRenderingInfrastructure
import PrimoDocumentStrokeApplication
import PrimoDocumentStrokeInfrastructure
import PrimoDocumentMetalStrokeInfrastructure

public struct DocumentRuntimeComposition: Sendable {
    public let queryGateway: DocumentQueryGateway
    public let mutationGateway: DocumentMutationGateway
    public let strokeGateway: StrokeInputGateway
    public let historyGateway: DocumentHistoryGateway
    public let persistenceGateway: DocumentPersistenceGateway
    public let exportGateway: DocumentExportGateway
    public let textLayerGateway: TextLayerGateway
    public let layerEffectsGateway: DocumentLayerEffectsGateway
    public let editingGateway: DocumentEditingGateway
    public let strokeSessionUseCase: DocumentStrokeSessionUseCase
    public let gpuOperationGateway: DocumentGpuOperationGateway

    public init(
        queryGateway: DocumentQueryGateway,
        mutationGateway: DocumentMutationGateway,
        strokeGateway: StrokeInputGateway,
        historyGateway: DocumentHistoryGateway,
        persistenceGateway: DocumentPersistenceGateway,
        exportGateway: DocumentExportGateway,
        textLayerGateway: TextLayerGateway,
        layerEffectsGateway: DocumentLayerEffectsGateway,
        editingGateway: DocumentEditingGateway,
        strokeSessionUseCase: DocumentStrokeSessionUseCase,
        gpuOperationGateway: DocumentGpuOperationGateway
    ) {
        self.queryGateway = queryGateway
        self.mutationGateway = mutationGateway
        self.strokeGateway = strokeGateway
        self.historyGateway = historyGateway
        self.persistenceGateway = persistenceGateway
        self.exportGateway = exportGateway
        self.textLayerGateway = textLayerGateway
        self.layerEffectsGateway = layerEffectsGateway
        self.editingGateway = editingGateway
        self.strokeSessionUseCase = strokeSessionUseCase
        self.gpuOperationGateway = gpuOperationGateway
    }

    init(_ infrastructure: PrimoDocumentEngineInfrastructure.DocumentRuntimeComposition) {
        self.init(
            queryGateway: infrastructure.queryGateway,
            mutationGateway: infrastructure.mutationGateway,
            strokeGateway: infrastructure.strokeGateway,
            historyGateway: infrastructure.historyGateway,
            persistenceGateway: infrastructure.persistenceGateway,
            exportGateway: infrastructure.exportGateway,
            textLayerGateway: infrastructure.textLayerGateway,
            layerEffectsGateway: infrastructure.layerEffectsGateway,
            editingGateway: infrastructure.editingGateway,
            strokeSessionUseCase: infrastructure.strokeSessionUseCase,
            gpuOperationGateway: infrastructure.gpuOperationGateway
        )
    }

    public func withOverrides(
        queryGateway: DocumentQueryGateway? = nil,
        mutationGateway: DocumentMutationGateway? = nil,
        strokeGateway: StrokeInputGateway? = nil,
        historyGateway: DocumentHistoryGateway? = nil,
        persistenceGateway: DocumentPersistenceGateway? = nil,
        exportGateway: DocumentExportGateway? = nil,
        textLayerGateway: TextLayerGateway? = nil,
        layerEffectsGateway: DocumentLayerEffectsGateway? = nil,
        editingGateway: DocumentEditingGateway? = nil,
        strokeSessionUseCase: DocumentStrokeSessionUseCase? = nil,
        gpuOperationGateway: DocumentGpuOperationGateway? = nil
    ) -> DocumentRuntimeComposition {
        DocumentRuntimeComposition(
            queryGateway: queryGateway ?? self.queryGateway,
            mutationGateway: mutationGateway ?? self.mutationGateway,
            strokeGateway: strokeGateway ?? self.strokeGateway,
            historyGateway: historyGateway ?? self.historyGateway,
            persistenceGateway: persistenceGateway ?? self.persistenceGateway,
            exportGateway: exportGateway ?? self.exportGateway,
            textLayerGateway: textLayerGateway ?? self.textLayerGateway,
            layerEffectsGateway: layerEffectsGateway ?? self.layerEffectsGateway,
            editingGateway: editingGateway ?? self.editingGateway,
            strokeSessionUseCase: strokeSessionUseCase ?? self.strokeSessionUseCase,
            gpuOperationGateway: gpuOperationGateway ?? self.gpuOperationGateway
        )
    }
}

public enum DocumentRuntimeCompositionFactory {
    public static func live(
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) -> DocumentRuntimeComposition {
        DocumentRuntimeComposition(
            PrimoDocumentEngineInfrastructure.DocumentRuntimeCompositionFactory.live(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
    }
}

public struct DocumentProjectPreview: Equatable, Sendable {
    public let canvasSize: CGSize
    public let layerCount: Int
    public let previewSurface: DocumentCompositeSurface?

    public init(
        canvasSize: CGSize,
        layerCount: Int,
        previewSurface: DocumentCompositeSurface?
    ) {
        self.canvasSize = canvasSize
        self.layerCount = layerCount
        self.previewSurface = previewSurface
    }

    init(_ infrastructure: PrimoDocumentEngineInfrastructure.DocumentProjectPreview) {
        self.init(
            canvasSize: infrastructure.canvasSize,
            layerCount: infrastructure.layerCount,
            previewSurface: infrastructure.previewSurface
        )
    }
}

public enum DocumentProjectPreviewLoader {
    public static func loadPreview(
        from url: URL,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) throws -> DocumentProjectPreview {
        try DocumentProjectPreview(
            PrimoDocumentEngineInfrastructure.DocumentProjectPreviewLoader.loadPreview(
                from: url,
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
    }
}

public struct TimelapseExportProgress: Equatable, Sendable {
    public var progress: Double
    public var previewSurface: DocumentCompositeSurface?
    public var previewImageData: Data?

    public init(
        progress: Double,
        previewSurface: DocumentCompositeSurface? = nil,
        previewImageData: Data?
    ) {
        self.progress = progress
        self.previewSurface = previewSurface
        self.previewImageData = previewImageData
    }

    init(_ infrastructure: PrimoDocumentEngineInfrastructure.TimelapseExportProgress) {
        self.init(
            progress: infrastructure.progress,
            previewSurface: infrastructure.previewSurface,
            previewImageData: infrastructure.previewImageData
        )
    }
}

public struct TimelapseExportResult: Equatable, Sendable {
    public var url: URL

    public init(url: URL) {
        self.url = url
    }

    init(_ infrastructure: PrimoDocumentEngineInfrastructure.TimelapseExportResult) {
        self.init(url: infrastructure.url)
    }
}

public enum TimelapseExportError: Error {
    case insufficientFrames
    case cannotAddWriterInput
    case failedToStartWriting
    case invalidFrameData
    case exportFailed
    case cancelled
}

public enum TimelapseExportService {
    public static func exportVideo(
        from capture: TimelapseCapture,
        to directory: URL,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        progress: ((TimelapseExportProgress) -> Void)? = nil
    ) throws -> TimelapseExportResult {
        do {
            return try TimelapseExportResult(
                PrimoDocumentEngineInfrastructure.TimelapseExportService.exportVideo(
                    from: capture,
                    to: directory,
                    fileClient: fileClient,
                    dateClient: dateClient,
                    progress: progress.map { callback in
                        { callback(TimelapseExportProgress($0)) }
                    }
                )
            )
        } catch let error as PrimoDocumentEngineInfrastructure.TimelapseExportError {
            throw TimelapseExportError(error)
        } catch {
            throw error
        }
    }
}

private extension TimelapseExportError {
    init(_ infrastructure: PrimoDocumentEngineInfrastructure.TimelapseExportError) {
        switch infrastructure {
        case .insufficientFrames:
            self = .insufficientFrames
        case .cannotAddWriterInput:
            self = .cannotAddWriterInput
        case .failedToStartWriting:
            self = .failedToStartWriting
        case .invalidFrameData:
            self = .invalidFrameData
        case .exportFailed:
            self = .exportFailed
        case .cancelled:
            self = .cancelled
        }
    }
}

public struct GpuCanvasPreviewRenderer: CanvasPreviewRendering, CanvasTransformPreviewRendering, SelectionMaskProcessing {
    private let renderer: PrimoDocumentRenderingInfrastructure.GpuCanvasPreviewRenderer

    public init(gpuOperations: DocumentGpuOperationGateway = DocumentGpuOperationGatewayFactory.live()) {
        self.renderer = PrimoDocumentRenderingInfrastructure.GpuCanvasPreviewRenderer(gpuOperations: gpuOperations)
    }

    public func eyedropperLoupeSurface(
        sourcePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        gridSize: Int,
        paperStyle: CanvasPaperStyle,
        blendWithPaper: Bool
    ) -> DocumentCompositeSurface? {
        renderer.eyedropperLoupeSurface(
            sourcePixelData: sourcePixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            centerX: centerX,
            centerY: centerY,
            gridSize: gridSize,
            paperStyle: paperStyle,
            blendWithPaper: blendWithPaper
        )
    }

    public func selectionOverlaySurface(maskData: Data, width: Int, height: Int) -> DocumentCompositeSurface? {
        renderer.selectionOverlaySurface(maskData: maskData, width: width, height: height)
    }

    public func compositePreviewImageData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        renderer.compositePreviewImageData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels
        )
    }

    public func paperCompositeSurface(
        pixelData: Data,
        width: Int,
        height: Int,
        paperStyle: CanvasPaperStyle
    ) -> DocumentCompositeSurface? {
        renderer.paperCompositeSurface(pixelData: pixelData, width: width, height: height, paperStyle: paperStyle)
    }

    public func shapePreviewSurface(
        stroke: Stroke,
        style: PreviewStrokeStyle,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> DocumentCompositeSurface? {
        renderer.shapePreviewSurface(stroke: stroke, style: style, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
    }

    public func transformedTextPreviewSurface(
        textLayer: TextLayerData,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> DocumentCompositeSurface? {
        renderer.transformedTextPreviewSurface(textLayer: textLayer, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
    }

    public func transformedTextLayoutRect(textLayer: TextLayerData, canvasSize: CGSize) -> CGRect? {
        renderer.transformedTextLayoutRect(textLayer: textLayer, canvasSize: canvasSize)
    }
}

public struct GpuCanvasEyedropperSampler: CanvasEyedropperSampling {
    private let sampler = PrimoDocumentRenderingInfrastructure.GpuCanvasEyedropperSampler()

    public init() {}

    public func sampledColor(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        source: EyedropperSamplingSource,
        point: CGPoint,
        paperStyle: CanvasPaperStyle
    ) -> SampledColor? {
        sampler.sampledColor(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            source: source,
            point: point,
            paperStyle: paperStyle
        )
    }
}

public struct GpuLayerTransformProcessor: LayerTransformProcessing {
    private let processor: PrimoDocumentRenderingInfrastructure.GpuLayerTransformProcessor

    public init(gpuOperations: DocumentGpuOperationGateway = DocumentGpuOperationGatewayFactory.live()) {
        self.processor = PrimoDocumentRenderingInfrastructure.GpuLayerTransformProcessor(gpuOperations: gpuOperations)
    }

    public func transformedLayerPixels(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selection: CanvasSelection?,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint?,
        mode: CanvasTransformMode,
        quadOffsets: TransformQuadOffsets
    ) -> Data? {
        processor.transformedLayerPixels(
            source: source,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            selection: selection,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: pivot,
            mode: mode,
            quadOffsets: quadOffsets
        )
    }

    public func transformedSelection(
        _ selection: CanvasSelection?,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint?,
        mode: CanvasTransformMode,
        quadOffsets: TransformQuadOffsets,
        canvasSize: CGSize
    ) -> CanvasSelection? {
        processor.transformedSelection(
            selection,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: pivot,
            mode: mode,
            quadOffsets: quadOffsets,
            canvasSize: canvasSize
        )
    }

    public func transformationBounds(
        selection: CanvasSelection?,
        pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> CGRect? {
        processor.transformationBounds(
            selection: selection,
            pixelData: pixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )
    }
}

public enum BrushStrokeKernel {
    public static func taperScale(progress: CGFloat, taperIn: CGFloat, taperOut: CGFloat) -> CGFloat {
        PrimoDocumentStrokeInfrastructure.BrushStrokeKernel.taperScale(
            progress: progress,
            taperIn: taperIn,
            taperOut: taperOut
        )
    }

    public static func taperScale(progress: Double, taperIn: Double, taperOut: Double) -> Double {
        PrimoDocumentStrokeInfrastructure.BrushStrokeKernel.taperScale(
            progress: progress,
            taperIn: taperIn,
            taperOut: taperOut
        )
    }

    public static func resolvedRadius(
        for sample: StylusSample,
        progress: CGFloat,
        brush: BrushRuntimeSettings
    ) -> CGFloat {
        PrimoDocumentStrokeInfrastructure.BrushStrokeKernel.resolvedRadius(
            for: sample,
            progress: progress,
            brush: brush
        )
    }

    public static func previewStampAlpha(
        pressure: Double,
        opacityJitter: Double,
        opacity: Double,
        flow: Double,
        hardness: Double,
        opacityPressureSensitivity: Double,
        flowPressureSensitivity: Double,
        hasCustomTip: Bool
    ) -> Double {
        PrimoDocumentStrokeInfrastructure.BrushStrokeKernel.previewStampAlpha(
            pressure: pressure,
            opacityJitter: opacityJitter,
            opacity: opacity,
            flow: flow,
            hardness: hardness,
            opacityPressureSensitivity: opacityPressureSensitivity,
            flowPressureSensitivity: flowPressureSensitivity,
            hasCustomTip: hasCustomTip
        )
    }

    public static func noise(x: CGFloat, y: CGFloat) -> CGFloat {
        PrimoDocumentStrokeInfrastructure.BrushStrokeKernel.noise(x: x, y: y)
    }
}

public enum GpuRenderingSupport {
    public static func shouldUseIncrementalPreviewUpdate(for brush: BrushRuntimeSettings) -> Bool {
        PrimoDocumentMetalStrokeInfrastructure.GpuRenderingSupport.shouldUseIncrementalPreviewUpdate(for: brush)
    }

    public static func shouldUseGpuOnlyResponsivePreview(for brush: BrushRuntimeSettings) -> Bool {
        PrimoDocumentMetalStrokeInfrastructure.GpuRenderingSupport.shouldUseGpuOnlyResponsivePreview(for: brush)
    }

    public static func responsivePreviewBrush(from brush: BrushRuntimeSettings) -> BrushRuntimeSettings {
        PrimoDocumentMetalStrokeInfrastructure.GpuRenderingSupport.responsivePreviewBrush(from: brush)
    }
}

public enum PrimoMetalSurfaceFiltering: Sendable {
    case linear
    case nearest
}

private extension PrimoDocumentMetalRuntimeInfrastructure.PrimoMetalSurfaceFiltering {
    init(_ filtering: PrimoMetalSurfaceFiltering) {
        switch filtering {
        case .linear:
            self = .linear
        case .nearest:
            self = .nearest
        }
    }
}

#if canImport(UIKit)
import UIKit

@MainActor
public final class CanvasPresentationContainerView: UIView {
    private let content: PrimoCanvasPresentationInfrastructure.CanvasPresentationContainerView

    public var documentSize: CGSize {
        get { content.documentSize }
        set { content.documentSize = newValue }
    }

    public var actionSink: CanvasPresentationActionSink? {
        get { content.actionSink }
        set { content.actionSink = newValue }
    }

    public init(environment: CanvasPresentationEnvironment) {
        self.content = PrimoCanvasPresentationInfrastructure.CanvasPresentationContainerView(environment: environment)
        super.init(frame: .zero)
        backgroundColor = .clear
        clipsToBounds = true
        addSubview(content)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        content.frame = bounds
    }

    public func update(_ state: CanvasPresentationState) {
        content.update(state)
    }
}

@MainActor
public final class CanvasPixelSurfaceView: UIView {
    private let content = PrimoCanvasPresentationInfrastructure.CanvasPixelSurfaceView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        addSubview(content)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        content.frame = bounds
    }

    public func update(
        surface: DocumentCompositeSurface?,
        opacity: CGFloat = 1.0,
        filtering: PrimoMetalSurfaceFiltering = .linear
    ) {
        content.update(
            surface: surface,
            opacity: opacity,
            filtering: PrimoDocumentMetalRuntimeInfrastructure.PrimoMetalSurfaceFiltering(filtering)
        )
        isHidden = surface == nil
    }
}

#endif
