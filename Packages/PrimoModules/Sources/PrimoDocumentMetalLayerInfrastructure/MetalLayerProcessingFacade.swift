import Foundation
import PrimoDocumentGPUContracts
import PrimoDocumentRenderingInfrastructure

public struct MetalLayerProcessingFacade: Sendable {
    public let renderingClient: DocumentRenderingClient

    public init(renderingClient: DocumentRenderingClient = .live) {
        self.renderingClient = renderingClient
    }
}
