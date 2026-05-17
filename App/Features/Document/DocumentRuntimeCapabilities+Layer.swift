import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoCanvasPresentationDomain
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRuntime
import PrimoDocumentStrokeApplication

struct DocumentLayerMutationCapability: Sendable {
    let layerStructureRuntime: LayerStructureEditingRuntime
    let layerContentRuntime: LayerContentEditingRuntime
    let textLayerRuntime: TextLayerEditingRuntime
    let selectionRuntime: LayerSelectionEditingRuntime
    let presentationRuntime: DocumentPresentationRuntime
}

struct LayerWorkflowEnvironment: Sendable {
    let layerStructureRuntime: LayerStructureEditingRuntime
    let layerContentRuntime: LayerContentEditingRuntime
    let textLayerRuntime: TextLayerEditingRuntime
    let selectionRuntime: LayerSelectionEditingRuntime
    let presentationRuntime: DocumentPresentationRuntime
    let strokeRuntime: StrokeEditingRuntime
}

protocol LayerMutationWorkflowSubmitting: Sendable {
    func addLayer(named name: String) -> DocumentCreatedLayerMutationResult
    func createFolder(named name: String, afterLayerAt activeLayerIndex: LayerAnchorIndex) -> DocumentCreatedFolderMutationResult
    func deleteFolder(_ folderID: ExistingFolderID) -> DocumentMutationResult
    func deleteLayer(_ index: ExistingLayerIndex) -> DocumentMutationResult
    func duplicateLayer(_ index: ExistingLayerIndex, named duplicateName: String) -> DocumentCreatedLayerMutationResult
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
    func revealLayerForEditing(_ command: LayerEditAuthorization) -> DocumentMutationResult
    func ensureLayerVisible(_ command: LayerEditAuthorization) -> DocumentMutationResult
    func applyLayerSurfaceMutation(_ command: LayerEditAuthorization, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult
}

protocol LayerVisibilityPort: Sendable {
    func revealLayerForEditing(_ command: LayerEditAuthorization) -> DocumentMutationResult
    func ensureLayerVisible(_ command: LayerEditAuthorization) -> DocumentMutationResult
    func applyLayerSurfaceMutation(_ command: LayerEditAuthorization, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult
}

protocol LayerContentWorkflowSubmitting: Sendable {
    func applyPixels(_ pixelData: LayerPixelData, to target: LayerContentMutationTarget) -> Result<AppliedLayerContentMutation, DocumentMutationFailure>
    func applyTextLayer(_ textLayer: TextLayerData, to target: LayerContentMutationTarget) -> Result<AppliedLayerContentMutation, DocumentMutationFailure>
}

protocol LayerContentSubmitting: Sendable {
    func pixelDataForLayer(_ index: ExistingLayerIndex) -> Result<LayerPixelData, DocumentMutationFailure>
    func replaceLayerPixels(_ command: LayerPixelReplacementCommand) -> DocumentMutationResult
    func replaceLayerPixels(_ command: ValidatedLayerContentReplacementCommand) -> DocumentMutationResult
}

protocol LayerContentPort: LayerContentSubmitting {}

protocol SelectionWorkflowRequesting: Sendable {
    func invertedSelection(_ selection: CanvasSelection?, canvasGeometry: PixelGeometry, mode: SelectionToolMode) -> CanvasSelection?
    func adjustedSelection(_ selection: CanvasSelection?, canvasGeometry: PixelGeometry, expansion: Int, isInverted: Bool) -> CanvasSelection?
    func featheredSelection(_ selection: CanvasSelection?, canvasGeometry: PixelGeometry, radius: Int) -> CanvasSelection?
    func makeColorRangeSelection(request: ColorRangeSelectionRequest, snapshot: MetalDocumentSnapshot?, activeLayerIndex: ExistingLayerIndex, mode: SelectionToolMode) -> CanvasSelection?
    func combinedSelection(existing: CanvasSelection?, incoming: CanvasSelection?, mode: SelectionCombineMode, canvasGeometry: PixelGeometry) -> CanvasSelection?
    func makeRectangleSelection(from startPoint: CGPoint, to endPoint: CGPoint, canvasGeometry: PixelGeometry) -> CanvasSelection?
    func makeLassoSelection(from points: [CGPoint], canvasGeometry: PixelGeometry) -> CanvasSelection?
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
