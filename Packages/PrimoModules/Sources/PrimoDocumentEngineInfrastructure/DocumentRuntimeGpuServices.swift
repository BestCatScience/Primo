import PrimoDocumentMetalRuntimeInfrastructure

struct DocumentRuntimeGpuServices: @unchecked Sendable {
    let resources: MetalResourceStore
    let strokes: MetalStrokeExecutionService
    let composites: MetalCompositingService
    let layers: MetalLayerMutationService
    let text: MetalTextService
}

enum DocumentRuntimeGpuServicesFactory {
    static func live() -> DocumentRuntimeGpuServices {
        DocumentRuntimeGpuServices(
            resources: MetalResourceStore(),
            strokes: MetalStrokeExecutionService(),
            composites: MetalCompositingService(),
            layers: MetalLayerMutationService(),
            text: MetalTextService()
        )
    }
}
