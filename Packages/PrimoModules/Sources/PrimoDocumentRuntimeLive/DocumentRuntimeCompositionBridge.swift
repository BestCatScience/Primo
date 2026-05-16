import PrimoCoreTypes
import PrimoDocumentEngineInfrastructure
import PrimoDocumentMetalRuntimeInfrastructure
import PrimoDocumentRenderingInfrastructure
import PrimoDocumentRuntime
import PrimoSystemClients

package extension PrimoDocumentRuntime.DocumentRuntimeComposition {
    init(_ infrastructure: PrimoDocumentEngineInfrastructure.DocumentEngineRuntimeComposition) {
        self.init(
            queryGateway: infrastructure.queryGateway,
            renderGateway: infrastructure.renderGateway,
            dirtyUpdateQueue: infrastructure.dirtyUpdateQueue,
            mutationGateway: infrastructure.mutationGateway,
            strokeGateway: infrastructure.strokeGateway,
            historyGateway: infrastructure.historyGateway,
            persistenceGateway: infrastructure.persistenceGateway,
            exportGateway: infrastructure.exportGateway,
            textLayerGateway: infrastructure.textLayerGateway,
            layerEffectsGateway: infrastructure.layerEffectsGateway,
            editingGateway: infrastructure.editingGateway,
            strokeSessionUseCase: infrastructure.strokeSessionUseCase,
            canvasPreviewOperations: infrastructure.canvasPreviewOperations,
            selectionMaskOperations: infrastructure.selectionMaskOperations,
            layerTransformOperations: infrastructure.layerTransformOperations,
            renderingOperations: infrastructure.renderingOperations,
            surfaceHandleReleaser: infrastructure.surfaceHandleReleaser
        )
    }
}

package enum DocumentEngineRuntimeCompositionFactory {
    package static func live(
        fileClient: FileClient = .live,
        dateClient: DateClient = .live,
        uuidClient: UUIDClient = .live
    ) -> PrimoDocumentRuntime.DocumentRuntimeComposition {
        PrimoDocumentRuntime.DocumentRuntimeComposition(
            PrimoDocumentEngineInfrastructure.DocumentEngineRuntimeCompositionFactory.live(
                fileClient: fileClient,
                dateClient: dateClient,
                uuidClient: uuidClient,
                gpuOperations: DocumentGpuOperationGatewayFactory.live()
            )
        )
    }
}
