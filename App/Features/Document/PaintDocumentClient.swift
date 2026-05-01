import ComposableArchitecture
import Foundation
import PrimoCanvasPresentationDomain
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentRuntime
import PrimoDocumentStrokeApplication
import PrimoWorkspaceApplication

private enum DocumentRuntimeCompositionKey: DependencyKey {
    static var liveValue: DocumentRuntimeComposition {
        @Dependency(\.fileClient) var fileClient
        @Dependency(\.dateClient) var dateClient
        @Dependency(\.uuidClient) var uuidClient

        return DocumentRuntimeCompositionFactory.live(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
    }
}

private enum DocumentCanvasCommandServiceKey: DependencyKey {
    static var liveValue: DocumentCanvasCommandService {
        @Dependency(\.documentRuntimeComposition) var composition
        return DocumentCanvasCommandService(
            queryGateway: composition.queryGateway,
            mutationGateway: composition.mutationGateway,
            persistenceGateway: composition.persistenceGateway
        )
    }
}

private enum DocumentLayerCommandServiceKey: DependencyKey {
    static var liveValue: DocumentLayerCommandService {
        @Dependency(\.documentRuntimeComposition) var composition
        return DocumentLayerCommandService(mutationGateway: composition.mutationGateway)
    }
}

private enum DocumentStrokeCommandServiceKey: DependencyKey {
    static var liveValue: DocumentStrokeCommandService {
        @Dependency(\.documentRuntimeComposition) var composition
        return DocumentStrokeCommandService(strokeGateway: composition.strokeGateway)
    }
}

private enum CanvasStrokeInteractionServiceKey: DependencyKey {
    static var liveValue: CanvasStrokeInteractionService {
        @Dependency(\.documentRuntimeComposition) var composition
        return CanvasStrokeInteractionService(sessionUseCase: composition.strokeSessionUseCase)
    }
}

private enum DocumentHistoryCommandServiceKey: DependencyKey {
    static var liveValue: DocumentHistoryCommandService {
        @Dependency(\.documentRuntimeComposition) var composition
        return DocumentHistoryCommandService(historyGateway: composition.historyGateway)
    }
}

private enum DocumentMutationWorkflowServiceKey: DependencyKey {
    static var liveValue: DocumentMutationWorkflowService {
        @Dependency(\.documentRuntimeComposition) var composition
        return DocumentMutationWorkflowService(
            documentEditingGateway: composition.editingGateway,
            documentLayerEffectsGateway: composition.layerEffectsGateway,
            documentMutationGateway: composition.mutationGateway,
            textLayerGateway: composition.textLayerGateway
        )
    }
}

private enum SelectionWorkflowServiceKey: DependencyKey {
    static var liveValue: SelectionWorkflowService {
        @Dependency(\.documentRuntimeComposition) var composition
        return SelectionWorkflowService(gpuOperations: composition.gpuOperationGateway)
    }
}

private enum WorkspaceApplicationWorkflowServiceKey: DependencyKey {
    static let liveValue = WorkspaceApplicationWorkflowService()
}

private enum CanvasPreviewRendererKey: DependencyKey {
    static var liveValue: any CanvasPreviewRendering {
        @Dependency(\.documentRuntimeComposition) var composition
        return GpuCanvasPreviewRenderer(gpuOperations: composition.gpuOperationGateway)
    }
}

private enum LayerTransformProcessorKey: DependencyKey {
    static var liveValue: any LayerTransformProcessing {
        @Dependency(\.documentRuntimeComposition) var composition
        return GpuLayerTransformProcessor(gpuOperations: composition.gpuOperationGateway)
    }
}

private enum SelectionMaskProcessorKey: DependencyKey {
    static var liveValue: any SelectionMaskProcessing {
        @Dependency(\.documentRuntimeComposition) var composition
        return GpuCanvasPreviewRenderer(gpuOperations: composition.gpuOperationGateway)
    }
}

private enum CanvasEyedropperSamplerKey: DependencyKey {
    static var liveValue: any CanvasEyedropperSampling {
        GpuCanvasEyedropperSampler()
    }
}

private enum CanvasPresentationEnvironmentKey: DependencyKey {
    static var liveValue: CanvasPresentationEnvironment {
        @Dependency(\.canvasPreviewRenderer) var previewRenderer
        @Dependency(\.canvasEyedropperSampler) var eyedropperSampler
        @Dependency(\.selectionMaskProcessor) var selectionMaskProcessor
        @Dependency(\.layerTransformProcessor) var layerTransformProcessor
        return CanvasPresentationEnvironment(
            previewRenderer: previewRenderer,
            eyedropperSampler: eyedropperSampler,
            selectionProcessor: selectionMaskProcessor,
            layerTransformProcessor: layerTransformProcessor
        )
    }
}

private extension DependencyValues {
    mutating func setDocumentGpuOperationGatewayAndRefreshDerivedDependencies(
        _ gpuOperationGateway: DocumentGpuOperationGateway
    ) {
        let canvasPreviewRenderer = GpuCanvasPreviewRenderer(gpuOperations: gpuOperationGateway)
        let selectionMaskProcessor = GpuCanvasPreviewRenderer(gpuOperations: gpuOperationGateway)
        let layerTransformProcessor = GpuLayerTransformProcessor(gpuOperations: gpuOperationGateway)
        self[CanvasPreviewRendererKey.self] = canvasPreviewRenderer
        self[SelectionMaskProcessorKey.self] = selectionMaskProcessor
        self[LayerTransformProcessorKey.self] = layerTransformProcessor
        self[CanvasPresentationEnvironmentKey.self] = CanvasPresentationEnvironment(
            previewRenderer: canvasPreviewRenderer,
            eyedropperSampler: self[CanvasEyedropperSamplerKey.self],
            selectionProcessor: selectionMaskProcessor,
            layerTransformProcessor: layerTransformProcessor
        )
        self[SelectionWorkflowServiceKey.self] = SelectionWorkflowService(
            gpuOperations: gpuOperationGateway
        )
    }

    mutating func setDocumentRuntimeCompositionAndRefreshCommandServices(
        _ composition: DocumentRuntimeComposition
    ) {
        self[DocumentRuntimeCompositionKey.self] = composition
        self[DocumentCanvasCommandServiceKey.self] = DocumentCanvasCommandService(
            queryGateway: composition.queryGateway,
            mutationGateway: composition.mutationGateway,
            persistenceGateway: composition.persistenceGateway
        )
        self[DocumentLayerCommandServiceKey.self] = DocumentLayerCommandService(
            mutationGateway: composition.mutationGateway
        )
        self[DocumentStrokeCommandServiceKey.self] = DocumentStrokeCommandService(
            strokeGateway: composition.strokeGateway
        )
        self[CanvasStrokeInteractionServiceKey.self] = CanvasStrokeInteractionService(
            sessionUseCase: composition.strokeSessionUseCase
        )
        self[DocumentHistoryCommandServiceKey.self] = DocumentHistoryCommandService(
            historyGateway: composition.historyGateway
        )
        self[DocumentMutationWorkflowServiceKey.self] = DocumentMutationWorkflowService(
            documentEditingGateway: composition.editingGateway,
            documentLayerEffectsGateway: composition.layerEffectsGateway,
            documentMutationGateway: composition.mutationGateway,
            textLayerGateway: composition.textLayerGateway
        )
        setDocumentGpuOperationGatewayAndRefreshDerivedDependencies(composition.gpuOperationGateway)
    }
}

extension DependencyValues {
    var documentRuntimeComposition: DocumentRuntimeComposition {
        get { self[DocumentRuntimeCompositionKey.self] }
        set { setDocumentRuntimeCompositionAndRefreshCommandServices(newValue) }
    }

    var documentQueryGateway: DocumentQueryGateway {
        get { documentRuntimeComposition.queryGateway }
        set {
            setDocumentRuntimeCompositionAndRefreshCommandServices(
                documentRuntimeComposition.withOverrides(queryGateway: newValue)
            )
        }
    }

    var documentMutationGateway: DocumentMutationGateway {
        get { documentRuntimeComposition.mutationGateway }
        set {
            setDocumentRuntimeCompositionAndRefreshCommandServices(
                documentRuntimeComposition.withOverrides(mutationGateway: newValue)
            )
        }
    }

    var strokeInputGateway: StrokeInputGateway {
        get { documentRuntimeComposition.strokeGateway }
        set {
            setDocumentRuntimeCompositionAndRefreshCommandServices(
                documentRuntimeComposition.withOverrides(strokeGateway: newValue)
            )
        }
    }

    var documentHistoryGateway: DocumentHistoryGateway {
        get { documentRuntimeComposition.historyGateway }
        set {
            setDocumentRuntimeCompositionAndRefreshCommandServices(
                documentRuntimeComposition.withOverrides(historyGateway: newValue)
            )
        }
    }

    var documentPersistenceGateway: DocumentPersistenceGateway {
        get { documentRuntimeComposition.persistenceGateway }
        set {
            setDocumentRuntimeCompositionAndRefreshCommandServices(
                documentRuntimeComposition.withOverrides(persistenceGateway: newValue)
            )
        }
    }

    var documentExportGateway: DocumentExportGateway {
        get { documentRuntimeComposition.exportGateway }
        set {
            documentRuntimeComposition = documentRuntimeComposition.withOverrides(exportGateway: newValue)
        }
    }

    var textLayerGateway: TextLayerGateway {
        get { documentRuntimeComposition.textLayerGateway }
        set {
            documentRuntimeComposition = documentRuntimeComposition.withOverrides(textLayerGateway: newValue)
        }
    }

    var documentLayerEffectsGateway: DocumentLayerEffectsGateway {
        get { documentRuntimeComposition.layerEffectsGateway }
        set {
            documentRuntimeComposition = documentRuntimeComposition.withOverrides(layerEffectsGateway: newValue)
        }
    }

    var documentEditingGateway: DocumentEditingGateway {
        get { documentRuntimeComposition.editingGateway }
        set {
            documentRuntimeComposition = documentRuntimeComposition.withOverrides(editingGateway: newValue)
        }
    }

    var documentStrokeSessionUseCase: DocumentStrokeSessionUseCase {
        get { documentRuntimeComposition.strokeSessionUseCase }
        set {
            documentRuntimeComposition = documentRuntimeComposition.withOverrides(strokeSessionUseCase: newValue)
        }
    }

    var canvasStrokeInteractionService: CanvasStrokeInteractionService {
        get { self[CanvasStrokeInteractionServiceKey.self] }
        set { self[CanvasStrokeInteractionServiceKey.self] = newValue }
    }

    var documentGpuOperationGateway: DocumentGpuOperationGateway {
        get { documentRuntimeComposition.gpuOperationGateway }
        set {
            self[DocumentRuntimeCompositionKey.self] = documentRuntimeComposition.withOverrides(gpuOperationGateway: newValue)
            setDocumentGpuOperationGatewayAndRefreshDerivedDependencies(newValue)
        }
    }

    var canvasPreviewRenderer: any CanvasPreviewRendering {
        get { self[CanvasPreviewRendererKey.self] }
        set { self[CanvasPreviewRendererKey.self] = newValue }
    }

    var layerTransformProcessor: any LayerTransformProcessing {
        get { self[LayerTransformProcessorKey.self] }
        set { self[LayerTransformProcessorKey.self] = newValue }
    }

    var canvasEyedropperSampler: any CanvasEyedropperSampling {
        get { self[CanvasEyedropperSamplerKey.self] }
        set { self[CanvasEyedropperSamplerKey.self] = newValue }
    }

    var selectionMaskProcessor: any SelectionMaskProcessing {
        get { self[SelectionMaskProcessorKey.self] }
        set { self[SelectionMaskProcessorKey.self] = newValue }
    }

    var canvasPresentationEnvironment: CanvasPresentationEnvironment {
        get { self[CanvasPresentationEnvironmentKey.self] }
        set { self[CanvasPresentationEnvironmentKey.self] = newValue }
    }

    var documentCanvasCommandService: DocumentCanvasCommandService {
        get { self[DocumentCanvasCommandServiceKey.self] }
        set { self[DocumentCanvasCommandServiceKey.self] = newValue }
    }

    var documentLayerCommandService: DocumentLayerCommandService {
        get { self[DocumentLayerCommandServiceKey.self] }
        set { self[DocumentLayerCommandServiceKey.self] = newValue }
    }

    var documentStrokeCommandService: DocumentStrokeCommandService {
        get { self[DocumentStrokeCommandServiceKey.self] }
        set { self[DocumentStrokeCommandServiceKey.self] = newValue }
    }

    var documentHistoryCommandService: DocumentHistoryCommandService {
        get { self[DocumentHistoryCommandServiceKey.self] }
        set { self[DocumentHistoryCommandServiceKey.self] = newValue }
    }

    var documentMutationWorkflowService: DocumentMutationWorkflowService {
        get { self[DocumentMutationWorkflowServiceKey.self] }
        set { self[DocumentMutationWorkflowServiceKey.self] = newValue }
    }

    var selectionWorkflowService: SelectionWorkflowService {
        get { self[SelectionWorkflowServiceKey.self] }
        set { self[SelectionWorkflowServiceKey.self] = newValue }
    }

    var workspaceApplicationWorkflowService: WorkspaceApplicationWorkflowService {
        get { self[WorkspaceApplicationWorkflowServiceKey.self] }
        set { self[WorkspaceApplicationWorkflowServiceKey.self] = newValue }
    }
}
