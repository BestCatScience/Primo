import ComposableArchitecture
import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoCanvasPresentationDomain
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRuntime
import PrimoDocumentStrokeApplication
import PrimoWorkspaceApplication

struct ValidatedDocumentLayerMutationCommand: Equatable, Sendable {
    let command: DocumentMutationCommand
    let layerIndex: Int

    init(command: DocumentMutationCommand, layerIndex: Int) {
        self.command = command
        self.layerIndex = layerIndex
    }
}

struct ValidatedLayerContentReplacementCommand: Equatable, Sendable {
    let layer: ValidatedDocumentLayerMutationCommand
    let pixelData: Data
}

struct ValidatedBlurStrokeMutationCommand: Equatable, Sendable {
    let layer: ValidatedDocumentLayerMutationCommand
    let samples: [StylusSample]
    let brush: BrushRuntimeSettings
    let clearSelectionAfterBlur: Bool
}

struct ValidatedFillMutationCommand: Equatable, Sendable {
    let layer: ValidatedDocumentLayerMutationCommand
    let sample: StylusSample
    let brush: BrushRuntimeSettings
}

struct DocumentWorkflowCommandValidator: Sendable {
    private let validator = DocumentMutationValidator()

    func editableLayerCommand(
        index: Int,
        in state: DocumentEditingState
    ) -> Result<ValidatedDocumentLayerMutationCommand, DocumentMutationFailure> {
        let command = DocumentMutationCommand.layer(index: index, requiresUnlocked: true)
        if let issue = validator.validate(command, in: validationContext(for: state)) {
            return .failure(issue.documentMutationFailure)
        }
        return .success(
            ValidatedDocumentLayerMutationCommand(
                command: command,
                layerIndex: index
            )
        )
    }

    func blurStrokeCommand(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        clearSelectionAfterBlur: Bool,
        in state: DocumentEditingState
    ) -> Result<ValidatedBlurStrokeMutationCommand, DocumentMutationFailure> {
        guard !samples.isEmpty else {
            return .failure(.emptyInput)
        }
        return editableLayerCommand(index: state.canvas.activeLayerIndex, in: state).map { layer in
            ValidatedBlurStrokeMutationCommand(
                layer: layer,
                samples: samples,
                brush: brush,
                clearSelectionAfterBlur: clearSelectionAfterBlur
            )
        }
    }

    func fillCommand(
        sample: StylusSample,
        brush: BrushRuntimeSettings,
        in state: DocumentEditingState
    ) -> Result<ValidatedFillMutationCommand, DocumentMutationFailure> {
        editableLayerCommand(index: state.canvas.activeLayerIndex, in: state).map { layer in
            ValidatedFillMutationCommand(
                layer: layer,
                sample: sample,
                brush: brush
            )
        }
    }

    private func validationContext(for state: DocumentEditingState) -> DocumentMutationValidationContext {
        let lockedLayerIndexes = Set(
            state.layerSidebar.layers
                .filter(\.isLocked)
                .map(\.index)
        )
        return DocumentMutationValidationContext(
            layerCount: state.layerSidebar.layers.count,
            folderIDs: Set(
                state.layerSidebar.rows.compactMap { row in
                    if case let .folder(folder) = row {
                        return folder.id
                    }
                    return nil
                }
            ),
            isLayerLocked: { index in
                lockedLayerIndexes.contains(index)
            }
        )
    }
}

private extension DocumentMutationValidationIssue {
    var documentMutationFailure: DocumentMutationFailure {
        switch self {
        case let .invalidLayerIndex(index):
            return .invalidLayerIndex(index)
        case let .invalidFolderID(folderID):
            return .invalidFolderID(folderID)
        case let .layerLocked(index):
            return .layerLocked(index)
        }
    }
}

private enum DocumentApplicationEnvironmentKey: DependencyKey {
    static var liveValue: DocumentApplicationEnvironment {
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.dateClient) var dateClient
        @Dependency(\.uuidClient) var uuidClient

        return DocumentApplicationEnvironment(
            workflows: DocumentApplicationRuntimeFactory.liveWorkflows(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
    }
}

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

    func lightweightPresentation() -> PaintDocumentPresentation {
        presentationRuntime.lightweightPresentation()
    }

    func presentation() -> PaintDocumentPresentation {
        presentationRuntime.presentation()
    }

    func setPaperStyle(_ paperStyle: CanvasPaperStyle) {
        persistenceRuntime.setPaperStyle(paperStyle)
    }

    func prewarmDrawingResources() {
        persistenceRuntime.prewarmDrawingResources()
    }

    var exportGateway: DocumentExportGateway {
        exportRuntime.gateway
    }

    var renderingWorkflow: DocumentRenderingWorkflow {
        presentationRuntime.renderingWorkflow
    }
}

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

struct DocumentCanvasStrokeWorkflowAccess: CanvasStrokeWorkflowAccess {
    private let strokeRuntime: StrokeEditingRuntime
    private let layerEditingRuntime: LayerEditingRuntime
    private let presentationAccess: DocumentPresentationWorkflowAccess

    init(
        strokeRuntime: StrokeEditingRuntime,
        layerEditingRuntime: LayerEditingRuntime,
        presentationAccess: DocumentPresentationWorkflowAccess
    ) {
        self.strokeRuntime = strokeRuntime
        self.layerEditingRuntime = layerEditingRuntime
        self.presentationAccess = presentationAccess
    }
}

extension StrokeMutationSubmitting {
    func blurStroke(_ command: ValidatedBlurStrokeMutationCommand) -> DocumentMutationResult {
        blurStroke(
            command.samples,
            command.brush,
            command.layer.layerIndex,
            command.clearSelectionAfterBlur
        )
    }

    func fill(_ command: ValidatedFillMutationCommand) -> DocumentMutationResult {
        fill(command.sample, command.brush)
    }
}

extension LayerMutationSubmitting {
    func revealLayerForEditing(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult {
        revealLayerForEditing(command.layerIndex)
    }

    func ensureLayerVisible(_ command: ValidatedDocumentLayerMutationCommand) -> DocumentMutationResult {
        ensureLayerVisible(command.layerIndex)
    }
}

extension LayerContentSubmitting {
    func replaceLayerPixels(_ command: ValidatedLayerContentReplacementCommand) -> DocumentMutationResult {
        replaceLayerPixels(command.layer.layerIndex, command.pixelData)
    }
}

extension StrokeEditingRuntime: StrokePreviewLeasing, StrokePreviewResolving, StrokeMutationSubmitting {}

extension LayerEditingRuntime:
    LayerMutationWorkflowSubmitting,
    LayerContentWorkflowSubmitting,
    LayerMutationSubmitting,
    LayerContentSubmitting,
    CanvasEditingExecuting,
    SelectionWorkflowRequesting
{}

struct DocumentLayerCommandMutationSubmitter: LayerMutationSubmitting {
    let service: DocumentLayerCommandService

    func revealLayerForEditing(_ index: Int) -> DocumentMutationResult {
        service.revealLayerForEditing(index)
    }

    func ensureLayerVisible(_ index: Int) -> DocumentMutationResult {
        service.ensureLayerVisible(index)
    }

    func applyLayerSurfaceMutation(_ index: Int, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult {
        service.applyLayerSurfaceMutation(index, payload)
    }
}

struct DocumentStrokeCommandMutationSubmitter: StrokeMutationSubmitting {
    let service: DocumentStrokeCommandService

    func cancelStroke() {
        service.cancelStroke()
    }

    func blurStroke(
        _ samples: [StylusSample],
        _ brush: BrushRuntimeSettings,
        _ layerIndex: Int,
        _ clearSelectionAfterBlur: Bool
    ) -> DocumentMutationResult {
        service.blurStroke(samples, brush, layerIndex, clearSelectionAfterBlur)
    }

    func endBlurStroke() -> DocumentMutationResult {
        service.endBlurStroke()
    }

    func cancelBlurStroke() {
        service.cancelBlurStroke()
    }

    func fill(_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult {
        service.fill(sample, brush)
    }
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
        strokeRuntime
    }
}

extension DocumentCanvasStrokeWorkflowAccess {
    func lightweightPresentation() -> PaintDocumentPresentation {
        presentationAccess.lightweightPresentation()
    }

    func presentation() -> PaintDocumentPresentation {
        presentationAccess.presentation()
    }

    func setPaperStyle(_ paperStyle: CanvasPaperStyle) {
        presentationAccess.setPaperStyle(paperStyle)
    }

    func prewarmDrawingResources() {
        presentationAccess.prewarmDrawingResources()
    }

    var exportGateway: DocumentExportGateway {
        presentationAccess.exportGateway
    }

    var renderingWorkflow: DocumentRenderingWorkflow {
        presentationAccess.renderingWorkflow
    }

    func cancel() -> GpuStrokeSessionOutcome {
        strokeRuntime.cancel()
    }

    func discardPreviewLease(_ lease: StrokePreviewLease) {
        strokeRuntime.discardPreviewLease(lease)
    }

    func previewLease(for mutation: GpuCommitMutation) -> StrokePreviewLease {
        strokeRuntime.previewLease(for: mutation)
    }

    func beginPreview(
        sample: StylusSample,
        baseSnapshot: MetalDocumentSnapshot?,
        context: DocumentStrokeContext,
        usesResponsivePreview: Bool
    ) -> GpuStrokeSessionOutcome {
        strokeRuntime.beginPreview(
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
        strokeRuntime.appendPreview(
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
        strokeRuntime.finish(
            renderState: renderState,
            baseSnapshot: baseSnapshot,
            renderSnapshot: renderSnapshot,
            samples: samples,
            context: context,
            allowsApproximatePreviewCommit: allowsApproximatePreviewCommit,
            refreshViaDirtyPresentation: refreshViaDirtyPresentation
        )
    }

    func cancelStroke() {
        strokeRuntime.cancelStroke()
    }

    func blurStroke(
        _ samples: [StylusSample],
        _ brush: BrushRuntimeSettings,
        _ layerIndex: Int,
        _ clearSelectionAfterBlur: Bool
    ) -> DocumentMutationResult {
        strokeRuntime.blurStroke(samples, brush, layerIndex, clearSelectionAfterBlur)
    }

    func endBlurStroke() -> DocumentMutationResult {
        strokeRuntime.endBlurStroke()
    }

    func cancelBlurStroke() {
        strokeRuntime.cancelBlurStroke()
    }

    func fill(_ sample: StylusSample, _ brush: BrushRuntimeSettings) -> DocumentMutationResult {
        strokeRuntime.fill(sample, brush)
    }

    func revealLayerForEditing(_ index: Int) -> DocumentMutationResult {
        layerEditingRuntime.revealLayerForEditing(index)
    }

    func ensureLayerVisible(_ index: Int) -> DocumentMutationResult {
        layerEditingRuntime.ensureLayerVisible(index)
    }

    func applyLayerSurfaceMutation(_ index: Int, _ payload: GpuLayerMutationPayload) -> DocumentMutationResult {
        layerEditingRuntime.applyLayerSurfaceMutation(index, payload)
    }

    func pixelDataForLayer(_ index: Int) -> Data {
        layerEditingRuntime.pixelDataForLayer(index)
    }

    func replaceLayerPixels(_ index: Int, _ pixelData: Data) -> DocumentMutationResult {
        layerEditingRuntime.replaceLayerPixels(index, pixelData)
    }

    func execute(_ command: CanvasEditingCommand, state context: CanvasEditingContext) -> CanvasEditingOutcome {
        layerEditingRuntime.execute(command, state: context)
    }

    func invertedSelection(_ selection: CanvasSelection?, canvasSize: CGSize, mode: SelectionToolMode) -> CanvasSelection? {
        layerEditingRuntime.invertedSelection(selection, canvasSize: canvasSize, mode: mode)
    }

    func adjustedSelection(_ selection: CanvasSelection?, canvasSize: CGSize, expansion: Int, isInverted: Bool) -> CanvasSelection? {
        layerEditingRuntime.adjustedSelection(selection, canvasSize: canvasSize, expansion: expansion, isInverted: isInverted)
    }

    func featheredSelection(_ selection: CanvasSelection?, canvasSize: CGSize, radius: Int) -> CanvasSelection? {
        layerEditingRuntime.featheredSelection(selection, canvasSize: canvasSize, radius: radius)
    }

    func makeColorRangeSelection(request: ColorRangeSelectionRequest, snapshot: MetalDocumentSnapshot?, activeLayerIndex: Int, mode: SelectionToolMode) -> CanvasSelection? {
        layerEditingRuntime.makeColorRangeSelection(request: request, snapshot: snapshot, activeLayerIndex: activeLayerIndex, mode: mode)
    }

    func combinedSelection(existing: CanvasSelection?, incoming: CanvasSelection?, mode: SelectionCombineMode, canvasSize: CGSize) -> CanvasSelection? {
        layerEditingRuntime.combinedSelection(existing: existing, incoming: incoming, mode: mode, canvasSize: canvasSize)
    }

    func makeRectangleSelection(from startPoint: CGPoint, to endPoint: CGPoint, canvasSize: CGSize) -> CanvasSelection? {
        layerEditingRuntime.makeRectangleSelection(from: startPoint, to: endPoint, canvasSize: canvasSize)
    }

    func makeLassoSelection(from points: [CGPoint], canvasSize: CGSize) -> CanvasSelection? {
        layerEditingRuntime.makeLassoSelection(from: points, canvasSize: canvasSize)
    }

    func makeAutoSelection(
        at point: CGPoint,
        snapshot: MetalDocumentSnapshot?,
        layerIndex: Int,
        thresholdMode: FillThresholdMode,
        opacityTolerance: Double,
        colorTolerance: Double,
        expansion: Int
    ) -> CanvasSelection? {
        layerEditingRuntime.makeAutoSelection(
            at: point,
            snapshot: snapshot,
            layerIndex: layerIndex,
            thresholdMode: thresholdMode,
            opacityTolerance: opacityTolerance,
            colorTolerance: colorTolerance,
            expansion: expansion
        )
    }

    func expandedMask(from selection: CanvasSelection, canvasWidth: Int, canvasHeight: Int) -> [UInt8]? {
        layerEditingRuntime.expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
    }

    func transformedLayerPixels(
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
        layerEditingRuntime.transformedLayerPixels(
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
        layerEditingRuntime.transformedSelection(
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
        pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> CGRect? {
        layerEditingRuntime.transformationBounds(
            selection: selection,
            pixelData: pixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )
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
            newCanvas: newCanvas,
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

extension DocumentPresentationRuntime {
    var renderingWorkflow: DocumentRenderingWorkflow {
        DocumentRenderingWorkflow(
            compositedPaperPreviewRGBA: compositedPaperPreviewRGBA,
            compositedPreviewPixelData: compositedPreviewPixelData,
            processedLayerPixelData: processedLayerPixelData,
            alphaMask: alphaMask,
            croppedSelectionMask: croppedSelectionMask,
            scaledPixelData: scaledPixelData,
            translatedPixelData: translatedPixelData
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
        runtime.eyedropperLoupeSurface(
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

    func selectionOverlaySurface(maskData: Data, width: Int, height: Int) -> DocumentCompositeSurface? {
        runtime.selectionOverlaySurface(maskData: maskData, width: width, height: height)
    }

    func compositePreviewImageData(snapshot: MetalDocumentSnapshot, activeLayerIndex: Int, adjustedActiveLayerPixels: Data) -> Data? {
        runtime.compositePreviewImageData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels
        )
    }

    func paperCompositeSurface(pixelData: Data, width: Int, height: Int, paperStyle: CanvasPaperStyle) -> DocumentCompositeSurface? {
        runtime.paperCompositeSurface(pixelData: pixelData, width: width, height: height, paperStyle: paperStyle)
    }

    func shapePreviewSurface(stroke: Stroke, style: PreviewStrokeStyle, canvasWidth: Int, canvasHeight: Int) -> DocumentCompositeSurface? {
        runtime.shapePreviewSurface(stroke: stroke, style: style, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
    }

    func transformedTextPreviewSurface(textLayer: TextLayerData, canvasWidth: Int, canvasHeight: Int) -> DocumentCompositeSurface? {
        runtime.transformedTextPreviewSurface(textLayer: textLayer, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
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
        runtime.sampledColor(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            source: source,
            point: point,
            paperStyle: paperStyle
        )
    }
}

private struct CanvasPreviewRuntimeSelectionMaskProcessor: SelectionMaskProcessing {
    let runtime: CanvasPreviewRuntime

    func selectionOverlaySurface(maskData: Data, width: Int, height: Int) -> DocumentCompositeSurface? {
        runtime.selectionOverlaySurface(maskData: maskData, width: width, height: height)
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

struct DocumentApplicationEnvironment: Sendable {
    let presentationWorkflowAccess: any PresentationWorkflowAccess
    let canvasMutationCapability: DocumentCanvasMutationCapability
    let layerMutationCapability: DocumentLayerMutationCapability
    let layerWorkflowEnvironment: LayerWorkflowEnvironment
    let canvasStrokeWorkflowAccess: any CanvasStrokeWorkflowAccess
    let exportCapability: DocumentExportCapability
    let persistenceCapability: DocumentPersistenceCapability
    let previewRenderingCapability: DocumentPreviewRenderingCapability

    init(workflows runtime: DocumentApplicationWorkflowRuntime) {
        let presentationWorkflowAccess = DocumentPresentationWorkflowAccess(
            presentationRuntime: runtime.presentation,
            persistenceRuntime: runtime.persistence,
            exportRuntime: runtime.export
        )
        self.presentationWorkflowAccess = presentationWorkflowAccess
        self.canvasMutationCapability = DocumentCanvasMutationCapability(
            canvasMutationRuntime: runtime.canvasMutation,
            presentationRuntime: runtime.presentation,
            persistenceRuntime: runtime.persistence
        )
        self.layerMutationCapability = DocumentLayerMutationCapability(
            layerEditingRuntime: runtime.layerEditing,
            presentationRuntime: runtime.presentation
        )
        self.layerWorkflowEnvironment = LayerWorkflowEnvironment(
            layerEditingRuntime: runtime.layerEditing,
            presentationRuntime: runtime.presentation,
            strokeRuntime: runtime.strokeEditing
        )
        self.canvasStrokeWorkflowAccess = DocumentCanvasStrokeWorkflowAccess(
            strokeRuntime: runtime.strokeEditing,
            layerEditingRuntime: runtime.layerEditing,
            presentationAccess: presentationWorkflowAccess
        )
        self.exportCapability = DocumentExportCapability(exportRuntime: runtime.export)
        self.persistenceCapability = DocumentPersistenceCapability(persistenceRuntime: runtime.persistence)
        self.previewRenderingCapability = DocumentPreviewRenderingCapability(previewRuntime: runtime.preview)
    }
}

private enum WorkspaceApplicationWorkflowServiceKey: DependencyKey {
    static let liveValue = WorkspaceApplicationWorkflowService()
}

extension DependencyValues {
    var documentApplicationEnvironment: DocumentApplicationEnvironment {
        get { self[DocumentApplicationEnvironmentKey.self] }
        set { self[DocumentApplicationEnvironmentKey.self] = newValue }
    }

    var presentationWorkflowAccess: any PresentationWorkflowAccess {
        documentApplicationEnvironment.presentationWorkflowAccess
    }

    var documentCanvasMutationCapability: DocumentCanvasMutationCapability {
        documentApplicationEnvironment.canvasMutationCapability
    }

    var documentLayerMutationCapability: DocumentLayerMutationCapability {
        documentApplicationEnvironment.layerMutationCapability
    }

    var layerWorkflowEnvironment: LayerWorkflowEnvironment {
        documentApplicationEnvironment.layerWorkflowEnvironment
    }

    var canvasStrokeWorkflowAccess: any CanvasStrokeWorkflowAccess {
        documentApplicationEnvironment.canvasStrokeWorkflowAccess
    }

    var documentExportCapability: DocumentExportCapability {
        documentApplicationEnvironment.exportCapability
    }

    var documentPersistenceCapability: DocumentPersistenceCapability {
        documentApplicationEnvironment.persistenceCapability
    }

    var documentPreviewRenderingCapability: DocumentPreviewRenderingCapability {
        documentApplicationEnvironment.previewRenderingCapability
    }

    var workspaceApplicationWorkflowService: WorkspaceApplicationWorkflowService {
        get { self[WorkspaceApplicationWorkflowServiceKey.self] }
        set { self[WorkspaceApplicationWorkflowServiceKey.self] = newValue }
    }
}
