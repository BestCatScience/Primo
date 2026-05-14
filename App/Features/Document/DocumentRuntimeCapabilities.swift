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

protocol PresentationReadable: Sendable {
    func lightweightPresentation() -> PaintDocumentPresentation
    func presentation() -> PaintDocumentPresentation
}

protocol DirtyRefreshRequesting: Sendable {
    func setPaperStyle(_ paperStyle: CanvasPaperStyle)
    func prewarmDrawingResources()
}

protocol WorkspaceSnapshotRendering: Sendable {
    var exportGateway: DocumentExportGateway { get }
    var renderingWorkflow: DocumentRenderingWorkflow { get }
}

typealias PresentationWorkflowAccess = PresentationReadable & DirtyRefreshRequesting & WorkspaceSnapshotRendering
struct DocumentCanvasMutationCapability: Sendable {
    let canvasMutationRuntime: CanvasMutationRuntime
    let presentationRuntime: DocumentPresentationRuntime
    let persistenceRuntime: DocumentPersistenceRuntime
}

struct DocumentLayerMutationCapability: Sendable {
    let layerEditingRuntime: LayerEditingRuntime
    let presentationRuntime: DocumentPresentationRuntime
}

struct LayerWorkflowEnvironment: Sendable {
    let layerEditingRuntime: LayerEditingRuntime
    let presentationRuntime: DocumentPresentationRuntime
    let strokeRuntime: StrokeEditingRuntime
}

protocol StrokePreviewLeasing: Sendable {
    func cancel() -> GpuStrokeSessionOutcome
    func discardPreviewLease(_ lease: StrokePreviewLease)
    func previewLease(for mutation: GpuCommitMutation) -> StrokePreviewLease
}

protocol StrokePreviewResolving: Sendable {
    func beginPreview(
        sample: StylusSample,
        baseSnapshot: MetalDocumentSnapshot?,
        context: DocumentStrokeContext,
        usesResponsivePreview: Bool
    ) -> GpuStrokeSessionOutcome

    func appendPreview(
        baseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        renderState: StrokeSessionRenderState?,
        samples: [StylusSample],
        fullSamples: [StylusSample],
        context: DocumentStrokeContext,
        usesResponsivePreview: Bool
    ) -> GpuStrokeSessionOutcome

    func finish(
        renderState: StrokeSessionRenderState?,
        baseSnapshot: MetalDocumentSnapshot?,
        renderSnapshot: MetalDocumentSnapshot?,
        samples: [StylusSample],
        context: DocumentStrokeContext,
        allowsApproximatePreviewCommit: Bool,
        refreshViaDirtyPresentation: Bool
    ) -> GpuStrokeSessionOutcome
}

protocol StrokeMutationSubmitting: Sendable {
    func cancelStroke()
    func blurStroke(_ command: ValidatedBlurStrokeMutationCommand) -> DocumentMutationResult
    func blurStroke(
        _ samples: [StylusSample],
        _ brush: BrushRuntimeSettings,
        _ layerIndex: Int,
        _ clearSelectionAfterBlur: Bool
    ) -> DocumentMutationResult
    func endBlurStroke() -> DocumentMutationResult
    func cancelBlurStroke()
    func fill(_ command: ValidatedFillMutationCommand) -> DocumentMutationResult
    func fill(_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult
}

protocol LayerMutationWorkflowSubmitting: Sendable {
    func addLayer(named name: String) -> DocumentIndexedMutationResult
    func createFolder(named name: String, afterLayerAt activeLayerIndex: Int) -> DocumentIndexedMutationResult
    func deleteFolder(_ folderID: Int) -> DocumentMutationResult
    func deleteLayer(_ index: Int) -> DocumentMutationResult
    func duplicateLayer(_ index: Int, named duplicateName: String) -> DocumentIndexedMutationResult
    func moveLayer(_ index: Int, to destinationIndex: Int) -> DocumentMutationResult
    func assignLayer(_ index: Int, toFolder folderID: Int?) -> DocumentMutationResult
    func mergeLayerDown(_ index: Int) -> DocumentMutationResult
    func setLayerVisibility(_ index: Int, visible: Bool) -> DocumentMutationResult
    func setActiveLayer(_ index: Int) -> DocumentMutationResult
    func setLayerOpacity(_ index: Int, opacity: Double) -> DocumentMutationResult
    func setLayerLocked(_ index: Int, isLocked: Bool) -> DocumentMutationResult
    func setLayerAlphaLocked(_ index: Int, isAlphaLocked: Bool) -> DocumentMutationResult
    func setLayerClipped(_ index: Int, isClipped: Bool) -> DocumentMutationResult
    func setFolderExpanded(_ folderID: Int, isExpanded: Bool) -> DocumentMutationResult
    func setFolderVisibility(_ folderID: Int, visible: Bool) -> DocumentMutationResult
    func setFolderName(_ folderID: Int, name: String) -> DocumentMutationResult
    func setLayerBlendMode(_ index: Int, blendMode: LayerBlendMode) -> DocumentMutationResult
    func setLayerName(_ index: Int, name: String) -> DocumentMutationResult
    func applyLayerProcessing(_ index: Int, request: LayerProcessingRequest) -> DocumentMutationResult
    func clearLayer(_ index: Int) -> DocumentMutationResult
    func replaceLayerMask(_ index: Int, maskData: Data) -> DocumentMutationResult
    func clearLayerMask(_ index: Int) -> DocumentMutationResult
    func applyLayerMask(_ index: Int) -> DocumentMutationResult
}

protocol LayerMutationSubmitting: Sendable {
    func revealLayerForEditing(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult
    func revealLayerForEditing(_ index: Int) -> DocumentMutationResult
    func ensureLayerVisible(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult
    func ensureLayerVisible(_ index: Int) -> DocumentMutationResult
    func applyLayerSurfaceMutation(_ index: Int, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult
}

protocol LayerContentWorkflowSubmitting: Sendable {
    func applyPixels(_ pixelData: Data, to target: LayerContentMutationTarget) -> Result<AppliedLayerContentMutation, DocumentMutationFailure>
    func applyTextLayer(_ textLayer: TextLayerData, to target: LayerContentMutationTarget) -> Result<AppliedLayerContentMutation, DocumentMutationFailure>
}

protocol LayerContentSubmitting: Sendable {
    func pixelDataForLayer(_ index: Int) -> Data
    func replaceLayerPixels(_ command: ValidatedLayerContentReplacementCommand) -> DocumentMutationResult
    func replaceLayerPixels(_ index: Int, _ pixelData: Data) -> DocumentMutationResult
}

protocol CanvasEditingExecuting: Sendable {
    func execute(_ command: CanvasEditingCommand, state context: CanvasEditingContext) -> CanvasEditingOutcome
}

protocol SelectionWorkflowRequesting: Sendable {
    func invertedSelection(_ selection: CanvasSelection?, canvasSize: CGSize, mode: SelectionToolMode) -> CanvasSelection?
    func adjustedSelection(_ selection: CanvasSelection?, canvasSize: CGSize, expansion: Int, isInverted: Bool) -> CanvasSelection?
    func featheredSelection(_ selection: CanvasSelection?, canvasSize: CGSize, radius: Int) -> CanvasSelection?
    func makeColorRangeSelection(request: ColorRangeSelectionRequest, snapshot: MetalDocumentSnapshot?, activeLayerIndex: Int, mode: SelectionToolMode) -> CanvasSelection?
    func combinedSelection(existing: CanvasSelection?, incoming: CanvasSelection?, mode: SelectionCombineMode, canvasSize: CGSize) -> CanvasSelection?
    func makeRectangleSelection(from startPoint: CGPoint, to endPoint: CGPoint, canvasSize: CGSize) -> CanvasSelection?
    func makeLassoSelection(from points: [CGPoint], canvasSize: CGSize) -> CanvasSelection?
    func makeAutoSelection(
        at point: CGPoint,
        snapshot: MetalDocumentSnapshot?,
        layerIndex: Int,
        thresholdMode: FillThresholdMode,
        opacityTolerance: Double,
        colorTolerance: Double,
        expansion: Int
    ) -> CanvasSelection?
    func expandedMask(from selection: CanvasSelection, canvasWidth: Int, canvasHeight: Int) -> [UInt8]?
}

typealias CanvasStrokeWorkflowAccess =
    PresentationReadable
    & DirtyRefreshRequesting
    & WorkspaceSnapshotRendering
    & StrokePreviewLeasing
    & StrokePreviewResolving
    & StrokeMutationSubmitting
    & LayerMutationSubmitting
    & LayerContentSubmitting
    & CanvasEditingExecuting
    & SelectionWorkflowRequesting
    & LayerTransformProcessing

struct DocumentExportCapability: Sendable {
    let exportRuntime: DocumentExportRuntime
}

struct DocumentPersistenceCapability: Sendable {
    let persistenceRuntime: DocumentPersistenceRuntime
}

struct DocumentPreviewRenderingCapability: Sendable {
    let previewRuntime: CanvasPreviewRuntime
}
