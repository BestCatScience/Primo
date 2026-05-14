import ComposableArchitecture
import Foundation
import PrimoCanvasPresentationDomain
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRuntime
import PrimoDocumentStrokeApplication
import PrimoWorkspaceApplication

private enum DocumentApplicationEnvironmentKey: DependencyKey {
    static var liveValue: DocumentApplicationEnvironment {
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.dateClient) var dateClient
        @Dependency(\.uuidClient) var uuidClient

        return DocumentApplicationEnvironment(
            runtime: DocumentApplicationRuntimeFactory.live(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient
            )
        )
    }
}

struct SelectionWorkflowEnvironment: Sendable {
    let workflow: LayerEditingRuntime

    init(workflow: LayerEditingRuntime) {
        self.workflow = workflow
    }
}

struct DocumentPresentationCapability: Sendable {
    let presentationRuntime: DocumentPresentationRuntime
    let persistenceRuntime: DocumentPersistenceRuntime
    let exportRuntime: DocumentExportRuntime
}

struct PresentationRefreshEnvironment: Sendable {
    let presentationRuntime: DocumentPresentationRuntime
    let persistenceRuntime: DocumentPersistenceRuntime
    let exportRuntime: DocumentExportRuntime
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
    let strokeRuntime: CanvasStrokeRuntime
}

struct DocumentStrokeCapability: Sendable {
    let strokeRuntime: CanvasStrokeRuntime
    let layerEditingRuntime: LayerEditingRuntime
    let presentationRuntime: DocumentPresentationRuntime
    let persistenceRuntime: DocumentPersistenceRuntime
    let selectionWorkflowEnvironment: SelectionWorkflowEnvironment
}

struct CanvasStrokeEnvironment: Sendable {
    let strokeRuntime: CanvasStrokeRuntime
    let layerEditingRuntime: LayerEditingRuntime
    let presentationRuntime: DocumentPresentationRuntime
    let persistenceRuntime: DocumentPersistenceRuntime
    let selectionWorkflowEnvironment: SelectionWorkflowEnvironment
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

extension DocumentPresentationCapability {
    var presentationReader: DocumentPresentationReader {
        DocumentPresentationReader(
            lightweightPresentation: presentationRuntime.lightweightPresentation,
            presentation: presentationRuntime.presentation
        )
    }

    var persistenceGateway: DocumentPersistenceGateway {
        persistenceRuntime.gateway
    }

    var exportGateway: DocumentExportGateway {
        exportRuntime.gateway
    }

    var renderingWorkflow: DocumentRenderingWorkflow {
        presentationRuntime.renderingWorkflow
    }
}

extension PresentationRefreshEnvironment {
    var presentationReader: DocumentPresentationReader {
        DocumentPresentationReader(
            lightweightPresentation: presentationRuntime.lightweightPresentation,
            presentation: presentationRuntime.presentation
        )
    }

    var persistenceGateway: DocumentPersistenceGateway {
        persistenceRuntime.gateway
    }

    var exportGateway: DocumentExportGateway {
        exportRuntime.gateway
    }

    var renderingWorkflow: DocumentRenderingWorkflow {
        presentationRuntime.renderingWorkflow
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

    var mutationWorkflowService: LayerEditingRuntime {
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

    var selectionWorkflowService: LayerEditingRuntime {
        layerEditingRuntime
    }
}

extension LayerWorkflowEnvironment {
    var contentService: LayerEditingRuntime {
        layerEditingRuntime
    }

    var renderingWorkflow: DocumentRenderingWorkflow {
        presentationRuntime.renderingWorkflow
    }

    var mutationWorkflowService: LayerEditingRuntime {
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

    var selectionWorkflowService: LayerEditingRuntime {
        layerEditingRuntime
    }

    var canvasStrokeInteractionService: CanvasStrokeRuntime {
        strokeRuntime
    }
}

extension DocumentStrokeCapability {
    var canvasStrokeInteractionService: CanvasStrokeRuntime {
        strokeRuntime
    }

    var renderingWorkflow: DocumentRenderingWorkflow {
        presentationRuntime.renderingWorkflow
    }

    var layerCommandService: LayerEditingRuntime {
        layerEditingRuntime
    }

    var strokeCommandService: CanvasStrokeRuntime {
        strokeRuntime
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

    var canvasEditingWorkflowService: LayerEditingRuntime {
        layerEditingRuntime
    }

    var contentService: LayerEditingRuntime {
        layerEditingRuntime
    }

    var layerTransformProcessor: LayerEditingRuntime {
        layerEditingRuntime
    }
}

extension CanvasStrokeEnvironment {
    var canvasStrokeInteractionService: CanvasStrokeRuntime {
        strokeRuntime
    }

    var renderingWorkflow: DocumentRenderingWorkflow {
        presentationRuntime.renderingWorkflow
    }

    var layerCommandService: LayerEditingRuntime {
        layerEditingRuntime
    }

    var strokeCommandService: CanvasStrokeRuntime {
        strokeRuntime
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

    var canvasEditingWorkflowService: LayerEditingRuntime {
        layerEditingRuntime
    }

    var contentService: LayerEditingRuntime {
        layerEditingRuntime
    }

    var layerTransformProcessor: LayerEditingRuntime {
        layerEditingRuntime
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
    let presentationCapability: DocumentPresentationCapability
    let presentationRefreshEnvironment: PresentationRefreshEnvironment
    let canvasMutationCapability: DocumentCanvasMutationCapability
    let layerMutationCapability: DocumentLayerMutationCapability
    let layerWorkflowEnvironment: LayerWorkflowEnvironment
    let strokeCapability: DocumentStrokeCapability
    let canvasStrokeEnvironment: CanvasStrokeEnvironment
    let exportCapability: DocumentExportCapability
    let persistenceCapability: DocumentPersistenceCapability
    let previewRenderingCapability: DocumentPreviewRenderingCapability

    init(runtime: DocumentApplicationRuntime) {
        let selectionWorkflowEnvironment = SelectionWorkflowEnvironment(workflow: runtime.layerEditing)
        self.presentationCapability = DocumentPresentationCapability(
            presentationRuntime: runtime.presentation,
            persistenceRuntime: runtime.persistence,
            exportRuntime: runtime.export
        )
        self.presentationRefreshEnvironment = PresentationRefreshEnvironment(
            presentationRuntime: runtime.presentation,
            persistenceRuntime: runtime.persistence,
            exportRuntime: runtime.export
        )
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
            strokeRuntime: runtime.stroke
        )
        self.strokeCapability = DocumentStrokeCapability(
            strokeRuntime: runtime.stroke,
            layerEditingRuntime: runtime.layerEditing,
            presentationRuntime: runtime.presentation,
            persistenceRuntime: runtime.persistence,
            selectionWorkflowEnvironment: selectionWorkflowEnvironment
        )
        self.canvasStrokeEnvironment = CanvasStrokeEnvironment(
            strokeRuntime: runtime.stroke,
            layerEditingRuntime: runtime.layerEditing,
            presentationRuntime: runtime.presentation,
            persistenceRuntime: runtime.persistence,
            selectionWorkflowEnvironment: selectionWorkflowEnvironment
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

    var documentPresentationCapability: DocumentPresentationCapability {
        documentApplicationEnvironment.presentationCapability
    }

    var presentationRefreshEnvironment: PresentationRefreshEnvironment {
        documentApplicationEnvironment.presentationRefreshEnvironment
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

    var documentStrokeCapability: DocumentStrokeCapability {
        documentApplicationEnvironment.strokeCapability
    }

    var canvasStrokeEnvironment: CanvasStrokeEnvironment {
        documentApplicationEnvironment.canvasStrokeEnvironment
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
