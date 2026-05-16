import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoCanvasPresentationDomain
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRuntime
import PrimoDocumentStrokeApplication

struct DocumentPresentationWorkflowAccess: PresentationWorkflowAccess {
    private let presentationRuntime: DocumentPresentationRuntime
    private let persistenceRuntime: DocumentPersistenceRuntime
    private let exportRuntime: DocumentExportRuntime

    init(
        presentationRuntime: DocumentPresentationRuntime,
        persistenceRuntime: DocumentPersistenceRuntime,
        exportRuntime: DocumentExportRuntime
    ) {
        self.presentationRuntime = presentationRuntime
        self.persistenceRuntime = persistenceRuntime
        self.exportRuntime = exportRuntime
    }

    func lightweightPresentation() -> Result<PaintDocumentPresentation, DocumentMutationFailure> {
        presentationRuntime.lightweightPresentation()
    }

    func presentation() -> Result<PaintDocumentPresentation, DocumentMutationFailure> {
        presentationRuntime.presentation()
    }

    func setPaperStyle(_ paperStyle: CanvasPaperStyle) {
        _ = persistenceRuntime.setPaperStyle(paperStyle)
    }

    func prewarmDrawingResources() {
        _ = persistenceRuntime.prewarmDrawingResources()
    }

    var exportGateway: DocumentExportGateway {
        exportRuntime.gateway
    }

    var renderingWorkflow: DocumentRenderingWorkflow {
        presentationRuntime.renderingWorkflow
    }
}
struct DocumentStrokePreviewAdapter: StrokePreviewPort {
    private let runtime: StrokeEditingRuntime

    init(runtime: StrokeEditingRuntime) {
        self.runtime = runtime
    }
}

struct DocumentStrokeCommitAdapter: StrokeCommitPort {
    private let runtime: StrokeEditingRuntime

    init(runtime: StrokeEditingRuntime) {
        self.runtime = runtime
    }
}

struct DocumentLayerVisibilityAdapter: LayerVisibilityPort {
    private let runtime: LayerEditingRuntime

    init(runtime: LayerEditingRuntime) {
        self.runtime = runtime
    }
}

struct DocumentLayerContentAdapter: LayerContentPort {
    private let runtime: LayerEditingRuntime

    init(runtime: LayerEditingRuntime) {
        self.runtime = runtime
    }
}

struct DocumentSelectionProcessingAdapter: SelectionProcessingPort {
    private let runtime: LayerEditingRuntime

    init(runtime: LayerEditingRuntime) {
        self.runtime = runtime
    }
}

struct DocumentCanvasTransformAdapter: CanvasTransformPort {
    private let runtime: LayerEditingRuntime

    init(runtime: LayerEditingRuntime) {
        self.runtime = runtime
    }
}

struct DocumentCanvasEditingPresentationAdapter: CanvasEditingPresentationPort {
    private let runtime: DocumentPresentationRuntime

    init(runtime: DocumentPresentationRuntime) {
        self.runtime = runtime
    }
}

struct DocumentPaperStyleAdapter: PaperStylePort {
    private let runtime: DocumentPersistenceRuntime

    init(runtime: DocumentPersistenceRuntime) {
        self.runtime = runtime
    }
}

extension StrokeEditingRuntime {
    func blurStroke(_ command: ValidatedBlurStrokeMutationCommand) -> DocumentMutationResult {
        blurStroke(
            command.samples,
            command.brush,
            layerIndex: command.layer.layerIndex,
            clearSelectionAfterBlur: command.clearSelectionAfterBlur
        )
    }

    func fill(_ command: ValidatedFillMutationCommand) -> DocumentMutationResult {
        fill(command.sample, command.brush)
    }
}

extension LayerEditingRuntime {
    func revealLayerForEditing(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult {
        revealLayerForEditing(command.existingLayerIndex)
    }

    func ensureLayerVisible(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult {
        ensureLayerVisible(command.existingLayerIndex)
    }

    func applyLayerSurfaceMutation(_ command: ValidatedDocumentLayerMutationCommand, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult {
        applyLayerSurfaceMutation(command.layerIndex, payload)
    }
}

extension LayerContentSubmitting {
    func replaceLayerPixels(_ command: ValidatedLayerContentReplacementCommand) -> DocumentMutationResult {
        replaceLayerPixels(
            LayerPixelReplacementCommand(
                index: command.layer.layerIndex,
                pixelData: command.pixelData
            )
        )
    }
}

extension LayerEditingRuntime:
    LayerMutationWorkflowSubmitting,
    LayerContentWorkflowSubmitting,
    LayerMutationSubmitting,
    LayerVisibilityPort,
    LayerContentSubmitting,
    LayerContentPort,
    CanvasEditingExecuting,
    SelectionWorkflowRequesting,
    SelectionProcessingPort
{}

struct DocumentLayerCommandMutationSubmitter: LayerMutationSubmitting, LayerVisibilityPort {
    let service: DocumentLayerCommandService

    func revealLayerForEditing(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult {
        service.revealLayerForEditing(command.existingLayerIndex.rawValue)
    }

    func ensureLayerVisible(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult {
        service.ensureLayerVisible(command.existingLayerIndex.rawValue)
    }

    func applyLayerSurfaceMutation(_ command: ValidatedDocumentLayerMutationCommand, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult {
        service.applyLayerSurfaceMutation(command.layerIndex.rawValue, payload)
    }
}

struct DocumentStrokeCommandMutationSubmitter: StrokeMutationSubmitting, StrokeCommitPort {
    let service: DocumentStrokeCommandService

    func cancelStroke() {
        _ = service.cancelStroke()
    }

    func endBlurStroke() -> DocumentMutationResult {
        service.endBlurStroke()
    }

    func cancelBlurStroke() {
        _ = service.cancelBlurStroke()
    }

    func fill(_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult {
        service.fill(sample, brush)
    }

    func blurStroke(_ command: ValidatedBlurStrokeMutationCommand) -> DocumentMutationResult {
        service.blurStroke(
            command.samples,
            command.brush,
            command.layer.layerIndex.rawValue,
            command.clearSelectionAfterBlur
        )
    }

    func fill(_ command: ValidatedFillMutationCommand) -> DocumentMutationResult {
        service.fill(command.sample, command.brush)
    }

}

extension PresentationReadable {
    var presentationReader: DocumentPresentationReader {
        DocumentPresentationReader(
            lightweightPresentation: lightweightPresentation,
            presentation: presentation
        )
    }
}


extension DocumentCanvasMutationCapability {
    var canvasCommandService: CanvasMutationRuntime {
        canvasMutationRuntime
    }

    var historyCommandService: CanvasMutationRuntime {
        canvasMutationRuntime
    }

    var persistenceGateway: DocumentPersistenceGateway {
        persistenceRuntime.gateway
    }

    var presentationReader: DocumentPresentationReader {
        DocumentPresentationReader(
            lightweightPresentation: presentationRuntime.lightweightPresentation,
            presentation: presentationRuntime.presentation
        )
    }

    var renderingWorkflow: DocumentRenderingWorkflow {
        presentationRuntime.renderingWorkflow
    }
}

extension DocumentLayerMutationCapability {
    var contentService: LayerEditingRuntime {
        layerEditingRuntime
    }

    var renderingWorkflow: DocumentRenderingWorkflow {
        presentationRuntime.renderingWorkflow
    }

    var mutationWorkflowService: any LayerMutationWorkflowSubmitting {
        layerEditingRuntime
    }

    var presentationReader: DocumentPresentationReader {
        DocumentPresentationReader(
            lightweightPresentation: presentationRuntime.lightweightPresentation,
            presentation: presentationRuntime.presentation
        )
    }

    var textLayerService: LayerEditingRuntime {
        layerEditingRuntime
    }

    var selectionWorkflowService: any SelectionWorkflowRequesting {
        layerEditingRuntime
    }
}

extension LayerWorkflowEnvironment {
    var contentService: any LayerContentWorkflowSubmitting {
        layerEditingRuntime
    }

    var renderingWorkflow: DocumentRenderingWorkflow {
        presentationRuntime.renderingWorkflow
    }

    var mutationWorkflowService: any LayerMutationWorkflowSubmitting {
        layerEditingRuntime
    }

    var presentationReader: DocumentPresentationReader {
        DocumentPresentationReader(
            lightweightPresentation: presentationRuntime.lightweightPresentation,
            presentation: presentationRuntime.presentation
        )
    }

    var textLayerService: LayerEditingRuntime {
        layerEditingRuntime
    }

    var selectionWorkflowService: any SelectionWorkflowRequesting {
        layerEditingRuntime
    }

    var canvasStrokeInteractionService: any StrokePreviewLeasing {
        DocumentStrokePreviewAdapter(runtime: strokeRuntime)
    }
}

extension DocumentCanvasEditingPresentationAdapter {
    var renderingWorkflow: DocumentRenderingWorkflow {
        runtime.renderingWorkflow
    }

    var presentationReader: DocumentPresentationReader {
        DocumentPresentationReader(
            lightweightPresentation: runtime.lightweightPresentation,
            presentation: runtime.presentation
        )
    }
}

extension DocumentPaperStyleAdapter {
    func setPaperStyle(_ paperStyle: CanvasPaperStyle) {
        _ = runtime.setPaperStyle(paperStyle)
    }
}

extension DocumentStrokePreviewAdapter {
    func cancel() -> GpuStrokeSessionOutcome {
        runtime.cancel()
    }

    func discardPreviewLease(_ lease: StrokePreviewLease) {
        runtime.discardPreviewLease(lease)
    }

    func previewLease(for mutation: GpuCommitMutation) -> StrokePreviewLease {
        runtime.previewLease(for: mutation)
    }

    func beginPreview(
        sample: StylusSample,
        baseSnapshot: MetalDocumentSnapshot?,
        context: DocumentStrokeContext,
        usesResponsivePreview: Bool
    ) -> GpuStrokeSessionOutcome {
        runtime.beginPreview(
            sample: sample,
            baseSnapshot: baseSnapshot,
            context: context,
            usesResponsivePreview: usesResponsivePreview
        )
    }

    func appendPreview(
        baseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        renderState: StrokeSessionRenderState?,
        samples: [StylusSample],
        fullSamples: [StylusSample],
        context: DocumentStrokeContext,
        usesResponsivePreview: Bool
    ) -> GpuStrokeSessionOutcome {
        runtime.appendPreview(
            baseSnapshot: baseSnapshot,
            renderSnapshot: renderSnapshot,
            renderState: renderState,
            samples: samples,
            fullSamples: fullSamples,
            context: context,
            usesResponsivePreview: usesResponsivePreview
        )
    }

    func finish(
        renderState: StrokeSessionRenderState?,
        baseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        samples: [StylusSample],
        context: DocumentStrokeContext,
        allowsApproximatePreviewCommit: Bool,
        refreshViaDirtyPresentation: Bool
    ) -> GpuStrokeSessionOutcome {
        runtime.finish(
            renderState: renderState,
            baseSnapshot: baseSnapshot,
            renderSnapshot: renderSnapshot,
            samples: samples,
            context: context,
            allowsApproximatePreviewCommit: allowsApproximatePreviewCommit,
            refreshViaDirtyPresentation: refreshViaDirtyPresentation
        )
    }
}

extension DocumentStrokeCommitAdapter {
    func cancelStroke() {
        _ = runtime.cancelStroke()
    }

    func blurStroke(_ command: ValidatedBlurStrokeMutationCommand) -> DocumentMutationResult {
        runtime.blurStroke(command)
    }

    func endBlurStroke() -> DocumentMutationResult {
        runtime.endBlurStroke()
    }

    func cancelBlurStroke() {
        _ = runtime.cancelBlurStroke()
    }

    func fill(_ command: ValidatedFillMutationCommand) -> DocumentMutationResult {
        runtime.fill(command)
    }
}

extension DocumentLayerVisibilityAdapter {
    func revealLayerForEditing(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult {
        runtime.revealLayerForEditing(command)
    }

    func ensureLayerVisible(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult {
        runtime.ensureLayerVisible(command)
    }

    func applyLayerSurfaceMutation(_ command: ValidatedDocumentLayerMutationCommand, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult {
        runtime.applyLayerSurfaceMutation(command, payload)
    }
}

extension DocumentLayerContentAdapter {
    func pixelDataForLayer(_ index: ExistingLayerIndex) -> Result<LayerPixelData, DocumentMutationFailure> {
        runtime.pixelDataForLayer(index)
    }

    func replaceLayerPixels(_ command: LayerPixelReplacementCommand) -> DocumentMutationResult {
        runtime.replaceLayerPixels(command)
    }
}

extension DocumentCanvasTransformAdapter {
    func execute(_ command: CanvasEditingCommand, state context: CanvasEditingContext) -> CanvasEditingOutcome {
        runtime.execute(command, state: context)
    }

    func transformedLayerPixels(
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
        runtime.transformedLayerPixels(
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

    func transformedSelection(
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
        runtime.transformedSelection(
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

    func transformationBounds(
        selection: CanvasSelection?,
        surface: RgbaSurface
    ) -> CGRect? {
        runtime.transformationBounds(
            selection: selection,
            surface: surface
        )
    }
}

extension DocumentSelectionProcessingAdapter {
    func invertedSelection(_ selection: CanvasSelection?, canvasSize: CGSize, mode: SelectionToolMode) -> CanvasSelection? {
        runtime.invertedSelection(selection, canvasSize: canvasSize, mode: mode)
    }

    func adjustedSelection(_ selection: CanvasSelection?, canvasSize: CGSize, expansion: Int, isInverted: Bool) -> CanvasSelection? {
        runtime.adjustedSelection(selection, canvasSize: canvasSize, expansion: expansion, isInverted: isInverted)
    }

    func featheredSelection(_ selection: CanvasSelection?, canvasSize: CGSize, radius: Int) -> CanvasSelection? {
        runtime.featheredSelection(selection, canvasSize: canvasSize, radius: radius)
    }

    func makeColorRangeSelection(request: ColorRangeSelectionRequest, snapshot: MetalDocumentSnapshot?, activeLayerIndex: ExistingLayerIndex, mode: SelectionToolMode) -> CanvasSelection? {
        runtime.makeColorRangeSelection(request: request, snapshot: snapshot, activeLayerIndex: activeLayerIndex, mode: mode)
    }

    func combinedSelection(existing: CanvasSelection?, incoming: CanvasSelection?, mode: SelectionCombineMode, canvasSize: CGSize) -> CanvasSelection? {
        runtime.combinedSelection(existing: existing, incoming: incoming, mode: mode, canvasSize: canvasSize)
    }

    func makeRectangleSelection(from startPoint: CGPoint, to endPoint: CGPoint, canvasSize: CGSize) -> CanvasSelection? {
        runtime.makeRectangleSelection(from: startPoint, to: endPoint, canvasSize: canvasSize)
    }

    func makeLassoSelection(from points: [CGPoint], canvasSize: CGSize) -> CanvasSelection? {
        runtime.makeLassoSelection(from: points, canvasSize: canvasSize)
    }

    func makeAutoSelection(
        at point: CGPoint,
        snapshot: MetalDocumentSnapshot?,
        layerIndex: ExistingLayerIndex,
        thresholdMode: FillThresholdMode,
        opacityTolerance: Double,
        colorTolerance: Double,
        expansion: Int
    ) -> CanvasSelection? {
        runtime.makeAutoSelection(
            at: point,
            snapshot: snapshot,
            layerIndex: layerIndex,
            thresholdMode: thresholdMode,
            opacityTolerance: opacityTolerance,
            colorTolerance: colorTolerance,
            expansion: expansion
        )
    }

    func expandedMask(from selection: CanvasSelection, canvasGeometry: PixelGeometry) -> MaskSurface? {
        runtime.expandedMask(from: selection, canvasGeometry: canvasGeometry)
    }
}

extension DocumentExportCapability {
    var exportGateway: DocumentExportGateway {
        exportRuntime.gateway
    }
}

extension DocumentPersistenceCapability {
    var persistenceGateway: DocumentPersistenceGateway {
        persistenceRuntime.gateway
    }
}

extension DocumentPersistenceRuntime {
    var gateway: DocumentPersistenceGateway {
        DocumentPersistenceGateway(
            saveProject: saveProject,
            loadProject: loadProject,
            setPaperStyle: setPaperStyle,
            newCanvas: { width, height in
                guard let size = ValidCanvasSize(width, height) else {
                    return .failure(.invalidCanvasSize(width: width, height: height))
                }
                return newCanvas(size)
            },
            prewarmDrawingResources: prewarmDrawingResources
        )
    }
}

extension DocumentExportRuntime {
    var gateway: DocumentExportGateway {
        DocumentExportGateway(
            compositeSurface: compositeSurface,
            compositePNGData: compositePNGData,
            timelapseCapture: timelapseCapture
        )
    }
}

private struct CanvasPreviewRuntimeRenderer: CanvasPreviewRendering {
    let runtime: CanvasPreviewRuntime

    func eyedropperLoupeSurface(
        sourcePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        gridSize: Int,
        paperStyle: CanvasPaperStyle,
        blendWithPaper: Bool
    ) -> DocumentCompositeSurface? {
        guard let source = RgbaSurface(width: canvasWidth, height: canvasHeight, data: sourcePixelData) else {
            return nil
        }
        return runtime.eyedropperLoupeSurface(
            source: source,
            centerX: centerX,
            centerY: centerY,
            gridSize: gridSize,
            paperStyle: paperStyle,
            blendWithPaper: blendWithPaper
        )
    }

    func selectionOverlaySurface(maskData: Data, width: Int, height: Int) -> DocumentCompositeSurface? {
        guard let mask = MaskSurface(width: width, height: height, data: maskData) else {
            return nil
        }
        return runtime.selectionOverlaySurface(mask)
    }

    func compositePreviewImageData(snapshot: MetalDocumentSnapshot, activeLayerIndex: Int, adjustedActiveLayerPixels: Data) -> Data? {
        guard
            let geometry = PixelGeometry(width: snapshot.width, height: snapshot.height),
            let layerIndex = DocumentLayerMutationContext(
                revision: DocumentRevision(snapshot.revision),
                layerCount: snapshot.layers.count,
                folderIDs: [],
                isLayerLocked: { _ in false }
            ).existingLayerIndex(activeLayerIndex),
            let surface = RgbaSurface(geometry: geometry, data: adjustedActiveLayerPixels)
        else {
            return nil
        }
        return runtime.compositePreviewImageData(
            snapshot: snapshot,
            activeLayerIndex: layerIndex,
            adjustedActiveLayerPixels: surface
        )
    }

    func paperCompositeSurface(pixelData: Data, width: Int, height: Int, paperStyle: CanvasPaperStyle) -> DocumentCompositeSurface? {
        guard let surface = RgbaSurface(width: width, height: height, data: pixelData) else {
            return nil
        }
        return runtime.paperCompositeSurface(surface, paperStyle: paperStyle)
    }

    func shapePreviewSurface(stroke: Stroke, style: PreviewStrokeStyle, canvasWidth: Int, canvasHeight: Int) -> DocumentCompositeSurface? {
        guard let canvasGeometry = PixelGeometry(width: canvasWidth, height: canvasHeight) else { return nil }
        return runtime.shapePreviewSurface(stroke: stroke, style: style, canvasGeometry: canvasGeometry)
    }

    func transformedTextPreviewSurface(textLayer: TextLayerData, canvasWidth: Int, canvasHeight: Int) -> DocumentCompositeSurface? {
        guard let canvasGeometry = PixelGeometry(width: canvasWidth, height: canvasHeight) else { return nil }
        return runtime.transformedTextPreviewSurface(textLayer: textLayer, canvasGeometry: canvasGeometry)
    }

    func transformedTextLayoutRect(textLayer: TextLayerData, canvasSize: CGSize) -> CGRect? {
        runtime.transformedTextLayoutRect(textLayer: textLayer, canvasSize: canvasSize)
    }
}

private struct CanvasPreviewRuntimeEyedropperSampler: CanvasEyedropperSampling {
    let runtime: CanvasPreviewRuntime

    func sampledColor(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        source: EyedropperSamplingSource,
        point: CGPoint,
        paperStyle: CanvasPaperStyle
    ) -> SampledColor? {
        guard let layerIndex = DocumentLayerMutationContext(
            revision: DocumentRevision(snapshot.revision),
            layerCount: snapshot.layers.count,
            folderIDs: [],
            isLayerLocked: { _ in false }
        ).existingLayerIndex(activeLayerIndex) else {
            return nil
        }
        return runtime.sampledColor(
            snapshot: snapshot,
            activeLayerIndex: layerIndex,
            source: source,
            point: point,
            paperStyle: paperStyle
        )
    }
}

private struct CanvasPreviewRuntimeSelectionMaskProcessor: SelectionMaskProcessing {
    let runtime: CanvasPreviewRuntime

    func selectionOverlaySurface(maskData: Data, width: Int, height: Int) -> DocumentCompositeSurface? {
        guard let mask = MaskSurface(width: width, height: height, data: maskData) else {
            return nil
        }
        return runtime.selectionOverlaySurface(mask)
    }
}

extension DocumentPreviewRenderingCapability {
    var canvasPreviewRenderer: any CanvasPreviewRendering {
        CanvasPreviewRuntimeRenderer(runtime: previewRuntime)
    }

    var canvasEyedropperSampler: any CanvasEyedropperSampling {
        CanvasPreviewRuntimeEyedropperSampler(runtime: previewRuntime)
    }

    var selectionMaskProcessor: any SelectionMaskProcessing {
        CanvasPreviewRuntimeSelectionMaskProcessor(runtime: previewRuntime)
    }

    var canvasPresentationEnvironment: CanvasPresentationEnvironment {
        previewRuntime.presentationEnvironment()
    }
}
