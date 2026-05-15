import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoCanvasPresentationDomain
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentEngineInfrastructure
import PrimoDocumentGPUContracts
import PrimoDocumentMetalRuntimeInfrastructure
import PrimoDocumentMetalStrokeInfrastructure
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRenderingInfrastructure
import PrimoDocumentRuntime
import PrimoDocumentStrokeApplication
import PrimoDocumentStrokeInfrastructure


private final class DocumentRuntimePresentationBroadcaster: @unchecked Sendable {
    private let lock = NSLock()
    private let currentPresentation: @Sendable () -> Result<PaintDocumentPresentation, DocumentMutationFailure>
    private var continuations: [UUID: AsyncStream<PaintDocumentPresentation>.Continuation] = [:]

    init(currentPresentation: @escaping @Sendable () -> Result<PaintDocumentPresentation, DocumentMutationFailure>) {
        self.currentPresentation = currentPresentation
    }

    func stream() -> AsyncStream<PaintDocumentPresentation> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            lock.unlock()
            if case let .success(presentation) = currentPresentation() {
                continuation.yield(presentation)
            }
            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(id)
            }
        }
    }

    func publishLatest() {
        if case let .success(presentation) = currentPresentation() {
            publish(presentation)
        }
    }

    private func publish(_ presentation: PaintDocumentPresentation) {
        lock.lock()
        let activeContinuations = Array(continuations.values)
        lock.unlock()
        for continuation in activeContinuations {
            continuation.yield(presentation)
        }
    }

    private func removeContinuation(_ id: UUID) {
        lock.lock()
        continuations[id] = nil
        lock.unlock()
    }
}

private extension Result where Success == DocumentCommandOutcome, Failure == DocumentMutationFailure {
    func getOrFailureOutcome() -> DocumentCommandOutcome {
        switch self {
        case let .success(outcome):
            return outcome
        case let .failure(failure):
            return .failure(failure)
        }
    }
}

package extension PrimoDocumentRuntime.DocumentRuntimeComposition {
    init(_ infrastructure: PrimoDocumentEngineInfrastructure.DocumentRuntimeComposition) {
        self.init(
            queryGateway: infrastructure.queryGateway,
            renderGateway: infrastructure.renderGateway,
            dirtyUpdateQueue: infrastructure.dirtyUpdateQueue,
            mutationGateway: infrastructure.mutationGateway,
            strokeGateway: infrastructure.strokeGateway,
            historyGateway: infrastructure.historyGateway,
            persistenceGateway: infrastructure.persistenceGateway,
            exportGateway: infrastructure.exportGateway,
            textLayerGateway: infrastructure.textLayerGateway,
            layerEffectsGateway: infrastructure.layerEffectsGateway,
            editingGateway: infrastructure.editingGateway,
            strokeSessionUseCase: infrastructure.strokeSessionUseCase,
            canvasPreviewOperations: infrastructure.canvasPreviewOperations,
            selectionMaskOperations: infrastructure.selectionMaskOperations,
            layerTransformOperations: infrastructure.layerTransformOperations,
            renderingOperations: infrastructure.renderingOperations,
            surfaceHandleReleaser: infrastructure.surfaceHandleReleaser
        )
    }
}

package enum DocumentRuntimeCompositionFactory {
    package static func live(
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) -> PrimoDocumentRuntime.DocumentRuntimeComposition {
        PrimoDocumentRuntime.DocumentRuntimeComposition(
            PrimoDocumentEngineInfrastructure.DocumentRuntimeCompositionFactory.live(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
    }
}

package extension DocumentRuntimeServices {
    init(composition: PrimoDocumentRuntime.DocumentRuntimeComposition) {
        let canvasCommands = DocumentCanvasCommandService(
            queryGateway: composition.queryGateway,
            renderGateway: composition.renderGateway,
            mutationGateway: composition.mutationGateway,
            persistenceGateway: composition.persistenceGateway
        )
        let layerCommands = DocumentLayerCommandService(mutationGateway: composition.mutationGateway)
        let strokeCommands = DocumentStrokeCommandService(strokeGateway: composition.strokeGateway)
        let canvasStrokeInteractionService = CanvasStrokeInteractionService(
            sessionUseCase: composition.strokeSessionUseCase,
            releasePreviewLease: composition.surfaceHandleReleaser.releaseSurfaceLease
        )
        let historyCommands = DocumentHistoryCommandService(historyGateway: composition.historyGateway)
        let mutationWorkflow = DocumentMutationWorkflowService(
            documentQueryGateway: composition.queryGateway,
            documentEditingGateway: composition.editingGateway,
            documentLayerEffectsGateway: composition.layerEffectsGateway
        )
        let contentService = DocumentContentService(
            documentQueryGateway: composition.queryGateway,
            documentRenderGateway: composition.renderGateway,
            documentEditingGateway: composition.editingGateway,
            documentMutationGateway: composition.mutationGateway
        )
        let canvasPreviewRenderer = GpuCanvasPreviewRenderer(operations: composition.canvasPreviewOperations)
        let canvasEyedropperSampler = GpuCanvasEyedropperSampler()
        let layerTransformProcessor = GpuLayerTransformProcessor(
            layerTransformOperations: composition.layerTransformOperations,
            selectionOperations: composition.selectionMaskOperations
        )
        let selectionMaskProcessor = GpuCanvasPreviewRenderer(operations: composition.canvasPreviewOperations)
        let canvasEditingWorkflow = CanvasEditingWorkflowService(
            documentContentService: contentService,
            layerTransformProcessor: layerTransformProcessor
        )
        let selectionWorkflow = SelectionWorkflowService(operations: composition.selectionMaskOperations)
        let canvasPresentationEnvironment = CanvasPresentationEnvironment(
            previewRenderer: canvasPreviewRenderer,
            eyedropperSampler: canvasEyedropperSampler,
            selectionProcessor: selectionMaskProcessor
        )
        let presentationReader = DocumentPresentationReader(
            lightweightPresentation: composition.queryGateway.lightweightPresentation,
            presentation: composition.queryGateway.presentation
        )
        let renderingWorkflow = DocumentRenderingWorkflow(operations: composition.renderingOperations)
        let textLayerService = DocumentTextLayerService(
            textLayerData: { index in composition.textLayerGateway.textLayerData(index.rawValue) },
            setTextLayer: { index, textLayer in
                composition.editingGateway.execute(.content(.setTextLayer(index: index.rawValue, textLayer: textLayer)))
                    .map { _ in () }
            },
            clearTextLayerData: { index in composition.textLayerGateway.clearTextLayerData(index.rawValue) }
        )
        let persistenceClient = DocumentPersistenceClient(
            saveProject: composition.persistenceGateway.saveProject,
            loadProject: composition.persistenceGateway.loadProject,
            setPaperStyle: composition.persistenceGateway.setPaperStyle,
            newCanvas: composition.persistenceGateway.newCanvas,
            prewarmDrawingResources: composition.persistenceGateway.prewarmDrawingResources
        )
        let exportClient = DocumentExportClient(
            compositeSurface: composition.exportGateway.compositeSurface,
            compositePNGData: composition.exportGateway.compositePNGData,
            timelapseCapture: composition.exportGateway.timelapseCapture
        )
        self.init(
            canvasCommands: canvasCommands,
            layerCommands: layerCommands,
            strokeCommands: strokeCommands,
            canvasStrokeInteractionService: canvasStrokeInteractionService,
            historyCommands: historyCommands,
            mutationWorkflow: mutationWorkflow,
            contentService: contentService,
            canvasEditingWorkflow: canvasEditingWorkflow,
            selectionWorkflow: selectionWorkflow,
            canvasPreviewRenderer: canvasPreviewRenderer,
            canvasEyedropperSampler: canvasEyedropperSampler,
            layerTransformProcessor: layerTransformProcessor,
            selectionMaskProcessor: selectionMaskProcessor,
            canvasPresentationEnvironment: canvasPresentationEnvironment,
            presentationReader: presentationReader,
            renderingWorkflow: renderingWorkflow,
            textLayerService: textLayerService,
            exportClient: exportClient,
            persistenceClient: persistenceClient
        )
    }
}


package extension DocumentApplicationRuntime {
    init(composition: PrimoDocumentRuntime.DocumentRuntimeComposition) {
        let services = DocumentRuntimeServices(composition: composition)
        self.init(
            presentation: DocumentPresentationRuntime(services: services),
            canvasMutation: CanvasMutationRuntime(services: services),
            strokeEditing: StrokeEditingRuntime(strokeRuntime: CanvasStrokeRuntime(services: services)),
            layerEditing: LayerEditingRuntime(services: services),
            persistence: DocumentPersistenceRuntime(services: services),
            export: DocumentExportRuntime(services: services),
            preview: CanvasPreviewRuntime(services: services)
        )
    }
}


package extension DocumentRuntime {
    init(composition: PrimoDocumentRuntime.DocumentRuntimeComposition) {
        let services = DocumentRuntimeServices(composition: composition)
        let presentationBroadcaster = DocumentRuntimePresentationBroadcaster {
            composition.queryGateway.lightweightPresentation()
        }
        let mutationOutcome: @Sendable (
            Result<DocumentMutationSuccess, DocumentMutationFailure>
        ) -> DocumentCommandOutcome = { result in
            if case .success = result {
                presentationBroadcaster.publishLatest()
            }
            return .mutation(result)
        }

        let executeClosure: @Sendable (DocumentCommand) async -> DocumentCommandOutcome = { command in
            switch command {
            case let .presentation(request):
                switch request {
                case .lightweight:
                    return composition.queryGateway.lightweightPresentation()
                        .map(DocumentCommandOutcome.presentation)
                        .getOrFailureOutcome()
                case .full, .current:
                    return composition.queryGateway.presentation()
                        .map(DocumentCommandOutcome.presentation)
                        .getOrFailureOutcome()
                }
            case let .canvas(command):
                switch command {
                case let .createSized(size):
                    return mutationOutcome(services.canvasCommands.createCanvas(size.width, size.height).map { .completed })
                case let .resizeSized(size):
                    return mutationOutcome(services.canvasCommands.resizeCanvas(size.width, size.height).map { .completed })
                case let .resizeExtentSized(size):
                    return mutationOutcome(services.canvasCommands.resizeCanvasExtent(size.width, size.height).map { .completed })
                case let .create(width, height):
                    return mutationOutcome(services.canvasCommands.createCanvas(width, height).map { .completed })
                case let .resize(width, height):
                    return mutationOutcome(services.canvasCommands.resizeCanvas(width, height).map { .completed })
                case let .resizeExtent(width, height):
                    return mutationOutcome(services.canvasCommands.resizeCanvasExtent(width, height).map { .completed })
                case let .initializeImported(request, layerName):
                    return mutationOutcome(services.canvasCommands.initializeImportedCanvas(request, layerName).map { .completed })
                case .compositeSurface:
                    return services.canvasCommands.compositeSurface()
                        .map(DocumentCommandOutcome.compositeSurface)
                        .getOrFailureOutcome()
                case let .setPaperStyle(style):
                    return mutationOutcome(composition.persistenceGateway.setPaperStyle(style).map { .completed })
                }
            case let .layer(command):
                switch command {
                case let .edit(request):
                    return mutationOutcome(
                        composition.editingGateway.execute(request)
                            .map { _ in .completed }
                    )
                case let .mergeExistingLayerDown(index):
                    return mutationOutcome(composition.layerEffectsGateway.mergeLayerDown(index.rawValue).map { .completed })
                case let .setEditableTextLayer(index, textLayer):
                    return mutationOutcome(
                        composition.editingGateway.execute(.content(.setTextLayer(index: index.rawValue, textLayer: textLayer)))
                            .map { _ in .completed }
                    )
                case let .applyEditableProcessing(index, request):
                    return mutationOutcome(
                        composition.editingGateway.execute(.content(.applyProcessing(index: index.rawValue, request: request)))
                            .map { _ in .completed }
                    )
                }
            case let .stroke(command):
                switch command {
                case let .begin(sample, settings):
                    return mutationOutcome(composition.strokeGateway.beginStroke(sample, settings).map { .completed })
                case let .append(sample):
                    return mutationOutcome(composition.strokeGateway.appendStroke(sample).map { .completed })
                case .end:
                    return mutationOutcome(composition.strokeGateway.endStroke().map { .completed })
                case .cancel:
                    return mutationOutcome(composition.strokeGateway.cancelStroke().map { .completed })
                case let .fill(sample, settings):
                    return mutationOutcome(composition.strokeGateway.fill(sample, settings).map { .completed })
                }
            case let .history(command):
                switch command {
                case .state:
                    let canUndo: Bool
                    switch composition.historyGateway.canUndo() {
                    case let .failure(failure):
                        return .failure(failure)
                    case let .success(value):
                        canUndo = value
                    }
                    let canRedo: Bool
                    switch composition.historyGateway.canRedo() {
                    case let .failure(failure):
                        return .failure(failure)
                    case let .success(value):
                        canRedo = value
                    }
                    return .history(
                        DocumentHistoryState(
                            canUndo: canUndo,
                            canRedo: canRedo
                        )
                    )
                case .undo:
                    return mutationOutcome(composition.historyGateway.undo().map { .completed })
                case .redo:
                    return mutationOutcome(composition.historyGateway.redo().map { .completed })
                }
            }
        }

        self.init(
            execute: executeClosure,
            observePresentation: {
                presentationBroadcaster.stream()
            }
        )
    }
}


public enum DocumentApplicationRuntimeFactory {
    public static func live(
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) -> DocumentApplicationRuntime {
        DocumentApplicationRuntime(
            composition: DocumentRuntimeCompositionFactory.live(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
    }

    public static func liveWorkflows(
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) -> DocumentApplicationWorkflowRuntime {
        live(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        ).workflows
    }
}

public enum DocumentRuntimeFactory {
    public static func live(
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) -> DocumentRuntime {
        DocumentRuntime(
            composition: DocumentRuntimeCompositionFactory.live(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
    }
}

public enum DocumentProjectPreviewLoader {
    public static func loadPreview(
        from url: URL,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) throws -> PrimoDocumentRuntime.DocumentProjectPreview {
        try PrimoDocumentRuntime.DocumentProjectPreview(
            PrimoDocumentEngineInfrastructure.DocumentProjectPreviewLoader.loadPreview(
                from: url,
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
    }
}

private extension PrimoDocumentRuntime.DocumentProjectPreview {
    init(_ infrastructure: PrimoDocumentEngineInfrastructure.DocumentProjectPreview) {
        self.init(
            canvasSize: infrastructure.canvasSize,
            layerCount: infrastructure.layerCount,
            previewSurface: infrastructure.previewSurface
        )
    }
}

public enum TimelapseExportService {
    public static func exportVideo(
        from capture: TimelapseCapture,
        to directory: URL,
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        progress: ((PrimoDocumentRuntime.TimelapseExportProgress) -> Void)? = nil
    ) throws -> PrimoDocumentRuntime.TimelapseExportResult {
        do {
            return try PrimoDocumentRuntime.TimelapseExportResult(
                PrimoDocumentEngineInfrastructure.TimelapseExportService.exportVideo(
                    from: capture,
                    to: directory,
                    fileClient: fileClient,
                    dateClient: dateClient,
                    progress: progress.map { callback in
                        { callback(PrimoDocumentRuntime.TimelapseExportProgress($0)) }
                    }
                )
            )
        } catch let error as PrimoDocumentEngineInfrastructure.TimelapseExportError {
            throw PrimoDocumentRuntime.TimelapseExportError(error)
        } catch {
            throw error
        }
    }
}

private extension PrimoDocumentRuntime.TimelapseExportProgress {
    init(_ infrastructure: PrimoDocumentEngineInfrastructure.TimelapseExportProgress) {
        self.init(
            progress: infrastructure.progress,
            previewSurface: infrastructure.previewSurface,
            previewImageData: infrastructure.previewImageData
        )
    }
}

private extension PrimoDocumentRuntime.TimelapseExportResult {
    init(_ infrastructure: PrimoDocumentEngineInfrastructure.TimelapseExportResult) {
        self.init(url: infrastructure.url)
    }
}

private extension PrimoDocumentRuntime.TimelapseExportError {
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

public struct GpuCanvasPreviewRenderer: CanvasPreviewRendering, SelectionMaskProcessing {
    private let renderer: PrimoDocumentRenderingInfrastructure.GpuCanvasPreviewRenderer

    public init() {
        self.init(operations: DocumentGpuOperationGatewayFactory.live().canvasPreviewRenderingOperations)
    }

    package init(operations: DocumentCanvasPreviewRenderingOperations) {
        self.renderer = PrimoDocumentRenderingInfrastructure.GpuCanvasPreviewRenderer(operations: operations)
    }

    package init(gpuOperations: DocumentGpuOperationGateway) {
        self.init(operations: gpuOperations.canvasPreviewRenderingOperations)
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

    public init() {
        let gpuOperations = DocumentGpuOperationGatewayFactory.live()
        self.init(
            layerTransformOperations: gpuOperations.layerTransformOperations,
            selectionOperations: gpuOperations.selectionMaskOperations
        )
    }

    package init(
        layerTransformOperations: DocumentLayerTransformOperations,
        selectionOperations: DocumentSelectionMaskOperations
    ) {
        self.processor = PrimoDocumentRenderingInfrastructure.GpuLayerTransformProcessor(
            layerTransformOperations: layerTransformOperations,
            selectionOperations: selectionOperations
        )
    }

    package init(gpuOperations: DocumentGpuOperationGateway) {
        self.init(
            layerTransformOperations: gpuOperations.layerTransformOperations,
            selectionOperations: gpuOperations.selectionMaskOperations
        )
    }

    public func transformedLayerPixels(
        source: RgbaSurface,
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
        surface: RgbaSurface
    ) -> CGRect? {
        processor.transformationBounds(
            selection: selection,
            surface: surface
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
