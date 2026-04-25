import Foundation
import PrimoDocumentGPUContracts
import PrimoDocumentMetalRuntimeInfrastructure
import PrimoDocumentRenderingInfrastructure

public struct MetalLayerProcessingFacade: Sendable {
    public let layerMutationExecutor: MetalLayerMutationExecutor
    public let materializationGateway: SurfaceMaterializationGateway

    public init(
        layerMutationExecutor: MetalLayerMutationExecutor = MetalLayerMutationExecutor(),
        materializationGateway: SurfaceMaterializationGateway = SurfaceMaterializationGateway()
    ) {
        self.layerMutationExecutor = layerMutationExecutor
        self.materializationGateway = materializationGateway
    }
}
