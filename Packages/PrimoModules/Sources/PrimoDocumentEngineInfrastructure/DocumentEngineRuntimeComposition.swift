import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import PrimoDocumentRenderingInfrastructure
import PrimoDocumentStrokeApplication
import PrimoSystemClients

package struct DocumentEngineRuntimeComposition: Sendable {
    package let queryGateway: DocumentQueryGateway
    package let renderGateway: DocumentRenderGateway
    package let dirtyUpdateQueue: DocumentDirtyUpdateQueue
    package let mutationGateway: DocumentMutationGateway
    package let strokeGateway: StrokeInputGateway
    package let historyGateway: DocumentHistoryGateway
    package let persistenceGateway: DocumentPersistenceGateway
    package let exportGateway: DocumentExportGateway
    package let textLayerGateway: TextLayerGateway
    package let layerEffectsGateway: DocumentLayerEffectsGateway
    package let editingGateway: DocumentEditingGateway
    package let strokeSessionUseCase: DocumentStrokeSessionUseCase
    package let canvasPreviewOperations: DocumentCanvasPreviewRenderingOperations
    package let selectionMaskOperations: DocumentSelectionMaskOperations
    package let layerTransformOperations: DocumentLayerTransformOperations
    package let renderingOperations: DocumentRenderingOperations
    package let surfaceHandleReleaser: DocumentSurfaceHandleReleaser

    package init(
        queryGateway: DocumentQueryGateway,
        renderGateway: DocumentRenderGateway,
        dirtyUpdateQueue: DocumentDirtyUpdateQueue,
        mutationGateway: DocumentMutationGateway,
        strokeGateway: StrokeInputGateway,
        historyGateway: DocumentHistoryGateway,
        persistenceGateway: DocumentPersistenceGateway,
        exportGateway: DocumentExportGateway,
        textLayerGateway: TextLayerGateway,
        layerEffectsGateway: DocumentLayerEffectsGateway,
        editingGateway: DocumentEditingGateway,
        strokeSessionUseCase: DocumentStrokeSessionUseCase,
        canvasPreviewOperations: DocumentCanvasPreviewRenderingOperations,
        selectionMaskOperations: DocumentSelectionMaskOperations,
        layerTransformOperations: DocumentLayerTransformOperations,
        renderingOperations: DocumentRenderingOperations,
        surfaceHandleReleaser: DocumentSurfaceHandleReleaser
    ) {
        self.queryGateway = queryGateway
        self.renderGateway = renderGateway
        self.dirtyUpdateQueue = dirtyUpdateQueue
        self.mutationGateway = mutationGateway
        self.strokeGateway = strokeGateway
        self.historyGateway = historyGateway
        self.persistenceGateway = persistenceGateway
        self.exportGateway = exportGateway
        self.textLayerGateway = textLayerGateway
        self.layerEffectsGateway = layerEffectsGateway
        self.editingGateway = editingGateway
        self.strokeSessionUseCase = strokeSessionUseCase
        self.canvasPreviewOperations = canvasPreviewOperations
        self.selectionMaskOperations = selectionMaskOperations
        self.layerTransformOperations = layerTransformOperations
        self.renderingOperations = renderingOperations
        self.surfaceHandleReleaser = surfaceHandleReleaser
    }

    package func withOverrides(
        queryGateway: DocumentQueryGateway? = nil,
        renderGateway: DocumentRenderGateway? = nil,
        dirtyUpdateQueue: DocumentDirtyUpdateQueue? = nil,
        mutationGateway: DocumentMutationGateway? = nil,
        strokeGateway: StrokeInputGateway? = nil,
        historyGateway: DocumentHistoryGateway? = nil,
        persistenceGateway: DocumentPersistenceGateway? = nil,
        exportGateway: DocumentExportGateway? = nil,
        textLayerGateway: TextLayerGateway? = nil,
        layerEffectsGateway: DocumentLayerEffectsGateway? = nil,
        editingGateway: DocumentEditingGateway? = nil,
        strokeSessionUseCase: DocumentStrokeSessionUseCase? = nil,
        canvasPreviewOperations: DocumentCanvasPreviewRenderingOperations? = nil,
        selectionMaskOperations: DocumentSelectionMaskOperations? = nil,
        layerTransformOperations: DocumentLayerTransformOperations? = nil,
        renderingOperations: DocumentRenderingOperations? = nil,
        surfaceHandleReleaser: DocumentSurfaceHandleReleaser? = nil
    ) -> DocumentEngineRuntimeComposition {
        DocumentEngineRuntimeComposition(
            queryGateway: queryGateway ?? self.queryGateway,
            renderGateway: renderGateway ?? self.renderGateway,
            dirtyUpdateQueue: dirtyUpdateQueue ?? self.dirtyUpdateQueue,
            mutationGateway: mutationGateway ?? self.mutationGateway,
            strokeGateway: strokeGateway ?? self.strokeGateway,
            historyGateway: historyGateway ?? self.historyGateway,
            persistenceGateway: persistenceGateway ?? self.persistenceGateway,
            exportGateway: exportGateway ?? self.exportGateway,
            textLayerGateway: textLayerGateway ?? self.textLayerGateway,
            layerEffectsGateway: layerEffectsGateway ?? self.layerEffectsGateway,
            editingGateway: editingGateway ?? self.editingGateway,
            strokeSessionUseCase: strokeSessionUseCase ?? self.strokeSessionUseCase,
            canvasPreviewOperations: canvasPreviewOperations ?? self.canvasPreviewOperations,
            selectionMaskOperations: selectionMaskOperations ?? self.selectionMaskOperations,
            layerTransformOperations: layerTransformOperations ?? self.layerTransformOperations,
            renderingOperations: renderingOperations ?? self.renderingOperations,
            surfaceHandleReleaser: surfaceHandleReleaser ?? self.surfaceHandleReleaser
        )
    }
}

package enum DocumentEngineRuntimeCompositionFactory {
    package static func live(
        fileClient: PrimoCoreTypes.FileClient = .live,
        dateClient: PrimoCoreTypes.DateClient = .live,
        uuidClient: PrimoCoreTypes.UUIDClient = .live
    ) -> DocumentEngineRuntimeComposition {
        let runtime = DocumentEngineFactory.live(
            fileClient: fileClient,
            dateClient: dateClient,
            uuidClient: uuidClient
        )
        let strokeUseCases = DocumentStrokeUseCasesLive.live()

        let gpuOperations = DocumentGpuOperationGatewayFactory.live()

        return DocumentEngineRuntimeComposition(
            queryGateway: runtime.queryGateway,
            renderGateway: runtime.renderGateway,
            dirtyUpdateQueue: runtime.dirtyUpdateQueue,
            mutationGateway: runtime.mutationGateway,
            strokeGateway: runtime.strokeGateway,
            historyGateway: runtime.historyGateway,
            persistenceGateway: runtime.persistenceGateway,
            exportGateway: runtime.exportGateway,
            textLayerGateway: runtime.textLayerGateway,
            layerEffectsGateway: DocumentLayerEffectsGateway(
                mergeLayerDown: runtime.mergeLayerDown
            ),
            editingGateway: runtime.editingGateway,
            strokeSessionUseCase: strokeUseCases.session,
            canvasPreviewOperations: gpuOperations.canvasPreviewRenderingOperations,
            selectionMaskOperations: gpuOperations.selectionMaskOperations,
            layerTransformOperations: gpuOperations.layerTransformOperations,
            renderingOperations: gpuOperations.renderingOperations,
            surfaceHandleReleaser: gpuOperations.surfaceHandleReleaser
        )
    }
}

extension DocumentEngineLive {
    package func makeEditingGateway() -> DocumentEditingGateway {
        editingGateway
    }
}

