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
    func lightweightPresentation() -> Result<PaintDocumentPresentation, DocumentMutationFailure>
    func presentation() -> Result<PaintDocumentPresentation, DocumentMutationFailure>
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

protocol StrokePreviewPort: StrokePreviewLeasing, StrokePreviewResolving {}

protocol StrokeMutationSubmitting: Sendable {
    func cancelStroke()
    func blurStroke(_ command: ValidatedBlurStrokeMutationCommand) -> DocumentMutationResult
    func endBlurStroke() -> DocumentMutationResult
    func cancelBlurStroke()
    func fill(_ command: ValidatedFillMutationCommand) -> DocumentMutationResult
    func fill(_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult
}

protocol StrokeCommitPort: Sendable {
    func cancelStroke()
    func blurStroke(_ command: ValidatedBlurStrokeMutationCommand) -> DocumentMutationResult
    func endBlurStroke() -> DocumentMutationResult
    func cancelBlurStroke()
    func fill(_ command: ValidatedFillMutationCommand) -> DocumentMutationResult
}

protocol LayerMutationWorkflowSubmitting: Sendable {
    func addLayer(named name: String) -> DocumentIndexedMutationResult
    func createFolder(named name: String, afterLayerAt activeLayerIndex: LayerAnchorIndex) -> DocumentIndexedMutationResult
    func deleteFolder(_ folderID: ExistingFolderID) -> DocumentMutationResult
    func deleteLayer(_ index: ExistingLayerIndex) -> DocumentMutationResult
    func duplicateLayer(_ index: ExistingLayerIndex, named duplicateName: String) -> DocumentIndexedMutationResult
    func moveLayer(_ index: ExistingLayerIndex, to destinationIndex: ExistingLayerIndex) -> DocumentMutationResult
    func assignLayer(_ index: ExistingLayerIndex, toFolder folderID: ExistingFolderID?) -> DocumentMutationResult
    func mergeLayerDown(_ index: ExistingLayerIndex) -> DocumentMutationResult
    func setLayerVisibility(_ index: ExistingLayerIndex, visible: Bool) -> DocumentMutationResult
    func setActiveLayer(_ index: ExistingLayerIndex) -> DocumentMutationResult
    func setLayerOpacity(_ index: ExistingLayerIndex, opacity: UnitInterval) -> DocumentMutationResult
    func setLayerLocked(_ index: ExistingLayerIndex, isLocked: Bool) -> DocumentMutationResult
    func setLayerAlphaLocked(_ index: ExistingLayerIndex, isAlphaLocked: Bool) -> DocumentMutationResult
    func setLayerClipped(_ index: ExistingLayerIndex, isClipped: Bool) -> DocumentMutationResult
    func setFolderExpanded(_ folderID: ExistingFolderID, isExpanded: Bool) -> DocumentMutationResult
    func setFolderVisibility(_ folderID: ExistingFolderID, visible: Bool) -> DocumentMutationResult
    func setFolderName(_ folderID: ExistingFolderID, name: String) -> DocumentMutationResult
    func setLayerBlendMode(_ index: ExistingLayerIndex, blendMode: LayerBlendMode) -> DocumentMutationResult
    func setLayerName(_ index: ExistingLayerIndex, name: String) -> DocumentMutationResult
    func applyLayerProcessing(_ index: EditableLayerIndex, request: LayerProcessingRequest) -> DocumentMutationResult
    func clearLayer(_ index: EditableLayerIndex) -> DocumentMutationResult
    func replaceLayerMask(_ index: EditableLayerIndex, mask: LayerMaskData) -> DocumentMutationResult
    func clearLayerMask(_ index: EditableLayerIndex) -> DocumentMutationResult
    func applyLayerMask(_ index: EditableLayerIndex) -> DocumentMutationResult
}

protocol LayerMutationSubmitting: Sendable {
    func revealLayerForEditing(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult
    func ensureLayerVisible(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult
    func applyLayerSurfaceMutation(_ command: ValidatedDocumentLayerMutationCommand, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult
}

protocol LayerVisibilityPort: Sendable {
    func revealLayerForEditing(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult
    func ensureLayerVisible(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult
    func applyLayerSurfaceMutation(_ command: ValidatedDocumentLayerMutationCommand, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult
}

protocol LayerContentWorkflowSubmitting: Sendable {
    func applyPixels(_ pixelData: Data, to target: LayerContentMutationTarget) -> Result<AppliedLayerContentMutation, DocumentMutationFailure>
    func applyTextLayer(_ textLayer: TextLayerData, to target: LayerContentMutationTarget) -> Result<AppliedLayerContentMutation, DocumentMutationFailure>
}

protocol LayerContentSubmitting: Sendable {
    func pixelDataForLayer(_ index: Int) -> Result<Data, DocumentMutationFailure>
    func replaceLayerPixels(_ command: LayerPixelReplacementCommand) -> DocumentMutationResult
    func replaceLayerPixels(_ command: ValidatedLayerContentReplacementCommand) -> DocumentMutationResult
}

protocol LayerContentPort: LayerContentSubmitting {}

protocol CanvasEditingExecuting: Sendable {
    func execute(_ command: CanvasEditingCommand, state context: CanvasEditingContext) -> CanvasEditingOutcome
}

protocol CanvasTransformPort: CanvasEditingExecuting, LayerTransformProcessing {}

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
        layerIndex: ExistingLayerIndex,
        thresholdMode: FillThresholdMode,
        opacityTolerance: Double,
        colorTolerance: Double,
        expansion: Int
    ) -> CanvasSelection?
    func expandedMask(from selection: CanvasSelection, canvasGeometry: PixelGeometry) -> MaskSurface?
}

protocol SelectionProcessingPort: SelectionWorkflowRequesting {}

protocol CanvasEditingPresentationPort: Sendable {
    var renderingWorkflow: DocumentRenderingWorkflow { get }
    var presentationReader: DocumentPresentationReader { get }
}

protocol PaperStylePort: Sendable {
    func setPaperStyle(_ paperStyle: CanvasPaperStyle)
}

struct DocumentExportCapability: Sendable {
    let exportRuntime: DocumentExportRuntime
}

struct DocumentPersistenceCapability: Sendable {
    let persistenceRuntime: DocumentPersistenceRuntime
}

struct DocumentPreviewRenderingCapability: Sendable {
    let previewRuntime: CanvasPreviewRuntime
}
