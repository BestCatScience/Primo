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
    func revealLayerForEditing(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult {
        revealLayerForEditing(command.existingLayerIndex)
    }

    func ensureLayerVisible(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult {
        ensureLayerVisible(command.existingLayerIndex)
    }

    func applyLayerSurfaceMutation(_ command: ValidatedDocumentLayerMutationCommand, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult {
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

    func revealLayerForEditing(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult {
        service.revealLayerForEditing(command.existingLayerIndex.rawValue)
    }

    func ensureLayerVisible(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult {
        service.ensureLayerVisible(command.existingLayerIndex.rawValue)
    }

    func applyLayerSurfaceMutation(_ command: ValidatedDocumentLayerMutationCommand, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult {
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
