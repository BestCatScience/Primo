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

struct DocumentLayerVisibilityAdapter: LayerVisibilityPort {
    private let runtime: LayerStructureEditingRuntime

    init(runtime: LayerStructureEditingRuntime) {
        self.runtime = runtime
    }
}

struct DocumentLayerContentAdapter: LayerContentPort {
    private let runtime: LayerContentEditingRuntime

    init(runtime: LayerContentEditingRuntime) {
        self.runtime = runtime
    }
}

struct DocumentSelectionProcessingAdapter: SelectionProcessingPort {
    private let runtime: LayerSelectionEditingRuntime

    init(runtime: LayerSelectionEditingRuntime) {
        self.runtime = runtime
    }
}

extension LayerStructureEditingRuntime {
    func revealLayerForEditing(_ command: LayerEditAuthorization) -> DocumentMutationResult {
        revealLayerForEditing(command.existingLayerIndex)
    }

    func ensureLayerVisible(_ command: LayerEditAuthorization) -> DocumentMutationResult {
        ensureLayerVisible(command.existingLayerIndex)
    }

    func applyLayerSurfaceMutation(_ command: LayerEditAuthorization, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult {
        applyLayerSurfaceMutation(command.editableLayerIndex, payload)
    }
}

extension LayerContentSubmitting {
    func replaceLayerPixels(_ command: ValidatedLayerContentReplacementCommand) -> DocumentMutationResult {
        replaceLayerPixels(
            LayerPixelReplacementCommand(
                index: command.layer.editableLayerIndex,
                pixelData: command.pixelData
            )
        )
    }
}

extension LayerStructureEditingRuntime:
    LayerMutationWorkflowSubmitting,
    LayerMutationSubmitting,
    LayerVisibilityPort
{}

extension LayerContentEditingRuntime:
    LayerContentWorkflowSubmitting,
    LayerContentSubmitting,
    LayerContentPort
{}

extension LayerSelectionEditingRuntime:
    SelectionWorkflowRequesting,
    SelectionProcessingPort
{}

struct DocumentLayerCommandMutationSubmitter: LayerMutationSubmitting, LayerVisibilityPort {
    let service: DocumentLayerCommandService

    func revealLayerForEditing(_ command: LayerEditAuthorization) -> DocumentMutationResult {
        service.revealLayerForEditing(command.existingLayerIndex.rawValue)
    }

    func ensureLayerVisible(_ command: LayerEditAuthorization) -> DocumentMutationResult {
        service.ensureLayerVisible(command.existingLayerIndex.rawValue)
    }

    func applyLayerSurfaceMutation(_ command: LayerEditAuthorization, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult {
        service.applyLayerSurfaceMutation(command.editableLayerIndex.rawValue, payload)
    }
}

extension DocumentLayerMutationCapability {
    var contentService: any LayerContentWorkflowSubmitting {
        layerContentRuntime
    }

    var renderingWorkflow: DocumentRenderingWorkflow {
        presentationRuntime.renderingWorkflow
    }

    var mutationWorkflowService: any LayerMutationWorkflowSubmitting {
        layerStructureRuntime
    }

    var presentationReader: DocumentPresentationReader {
        DocumentPresentationReader(
            lightweightPresentation: presentationRuntime.lightweightPresentation,
            presentation: presentationRuntime.presentation
        )
    }

    var textLayerService: TextLayerEditingRuntime {
        textLayerRuntime
    }

    var selectionWorkflowService: any SelectionWorkflowRequesting {
        selectionRuntime
    }
}

extension LayerWorkflowEnvironment {
    var contentService: any LayerContentWorkflowSubmitting {
        layerContentRuntime
    }

    var renderingWorkflow: DocumentRenderingWorkflow {
        presentationRuntime.renderingWorkflow
    }

    var mutationWorkflowService: any LayerMutationWorkflowSubmitting {
        layerStructureRuntime
    }

    var presentationReader: DocumentPresentationReader {
        DocumentPresentationReader(
            lightweightPresentation: presentationRuntime.lightweightPresentation,
            presentation: presentationRuntime.presentation
        )
    }

    var textLayerService: TextLayerEditingRuntime {
        textLayerRuntime
    }

    var selectionWorkflowService: any SelectionWorkflowRequesting {
        selectionRuntime
    }

    var canvasStrokeInteractionService: any StrokePreviewLeasing {
        DocumentStrokePreviewAdapter(runtime: strokeRuntime)
    }
}

extension DocumentLayerVisibilityAdapter {
    func revealLayerForEditing(_ command: LayerEditAuthorization) -> DocumentMutationResult {
        runtime.revealLayerForEditing(command)
    }

    func ensureLayerVisible(_ command: LayerEditAuthorization) -> DocumentMutationResult {
        runtime.ensureLayerVisible(command)
    }

    func applyLayerSurfaceMutation(_ command: LayerEditAuthorization, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult {
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

extension DocumentSelectionProcessingAdapter {
    func invertedSelection(_ selection: CanvasSelection?, canvasGeometry: PixelGeometry, mode: SelectionToolMode) -> CanvasSelection? {
        runtime.invertedSelection(selection, canvasGeometry: canvasGeometry, mode: mode)
    }

    func adjustedSelection(_ selection: CanvasSelection?, canvasGeometry: PixelGeometry, expansion: Int, isInverted: Bool) -> CanvasSelection? {
        runtime.adjustedSelection(selection, canvasGeometry: canvasGeometry, expansion: expansion, isInverted: isInverted)
    }

    func featheredSelection(_ selection: CanvasSelection?, canvasGeometry: PixelGeometry, radius: Int) -> CanvasSelection? {
        runtime.featheredSelection(selection, canvasGeometry: canvasGeometry, radius: radius)
    }

    func makeColorRangeSelection(request: ColorRangeSelectionRequest, snapshot: MetalDocumentSnapshot?, activeLayerIndex: ExistingLayerIndex, mode: SelectionToolMode) -> CanvasSelection? {
        runtime.makeColorRangeSelection(request: request, snapshot: snapshot, activeLayerIndex: activeLayerIndex, mode: mode)
    }

    func combinedSelection(existing: CanvasSelection?, incoming: CanvasSelection?, mode: SelectionCombineMode, canvasGeometry: PixelGeometry) -> CanvasSelection? {
        runtime.combinedSelection(existing: existing, incoming: incoming, mode: mode, canvasGeometry: canvasGeometry)
    }

    func makeRectangleSelection(from startPoint: CGPoint, to endPoint: CGPoint, canvasGeometry: PixelGeometry) -> CanvasSelection? {
        runtime.makeRectangleSelection(from: startPoint, to: endPoint, canvasGeometry: canvasGeometry)
    }

    func makeLassoSelection(from points: [CGPoint], canvasGeometry: PixelGeometry) -> CanvasSelection? {
        runtime.makeLassoSelection(from: points, canvasGeometry: canvasGeometry)
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
