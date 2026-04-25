import Foundation
import PrimoDocumentGPUContracts
import PrimoDocumentMetalRuntimeInfrastructure

public struct MetalLayerProcessingFacade: Sendable {
    public let layerMutationExecutor: MetalLayerMutationExecutor

    public init(
        layerMutationExecutor: MetalLayerMutationExecutor = MetalLayerMutationExecutor()
    ) {
        self.layerMutationExecutor = layerMutationExecutor
    }
}
