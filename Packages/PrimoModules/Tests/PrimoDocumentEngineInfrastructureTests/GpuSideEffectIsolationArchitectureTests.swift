import Foundation
import Testing

struct GpuSideEffectIsolationArchitectureTests {
    @Test
    func appDocumentFeaturesDoNotReachLegacyRenderingFacades() throws {
        let repoRoot = try Self.repoRoot()
        let featureRoot = repoRoot.appendingPathComponent("App/Features/Document", isDirectory: true)
        let banned = [
            "DocumentRenderingClient",
            "DocumentRenderingClient.live",
            "StrokeRenderingGateway",
            "LayerCompositingGateway",
            "OverlayRenderingGateway",
            "MetalResourceStore",
            "MetalLayerMutationService",
            "MetalStrokeExecutor",
            "MetalCompositor",
            "MetalRuntimeContext",
            "rasterizedStrokePixelData",
            "CanvasDocumentRenderingServices",
            "applySoftwareStroke"
        ]

        let sources = try Self.swiftSources(under: featureRoot)
        for source in sources {
            let body = try String(contentsOf: source, encoding: .utf8)
            for token in banned {
                #expect(!body.contains(token), "\(source.path) should not reference \(token)")
            }
        }
    }

    @Test
    func canvasImageRendererDoesNotOwnGpuProcessingServices() throws {
        let repoRoot = try Self.repoRoot()
        let renderer = repoRoot.appendingPathComponent("App/Rendering/MetalCanvasRenderer.swift", isDirectory: false)
        let body = try String(contentsOf: renderer, encoding: .utf8)
        let banned = [
            "StrokeRenderingGateway",
            "LayerCompositingGateway",
            "OverlayRenderingGateway",
            "MetalTextService",
            "rasterizedStrokePixelData"
        ]
        for token in banned {
            #expect(!body.contains(token), "CanvasImageRenderer should not reference \(token)")
        }
    }

    @Test
    func swiftDocumentRuntimeDoesNotConstructMetalServicesOrUseSharedSingleton() throws {
        let repoRoot = try Self.repoRoot()
        let runtime = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/SwiftDocumentRuntime.swift",
            isDirectory: false
        )
        let body = try String(contentsOf: runtime, encoding: .utf8)
        let banned = [
            "PrimoMetalDocumentProcessingClient.shared",
            "PrimoDocumentMetalRuntimeInfrastructure",
            "MetalRuntimeContext",
            "MetalResourceStore",
            "MetalStrokeExecutionService",
            "MetalCompositingService",
            "MetalLayerMutationService",
            "MetalTextService",
            "MetalStrokeExecutionRequest"
        ]
        for token in banned {
            #expect(!body.contains(token), "SwiftDocumentRuntime should not construct or reach \(token)")
        }
    }

    @Test
    func renderingInfrastructureDoesNotExposeLegacyFacadeNamesOrStrokeDataHotPath() throws {
        let repoRoot = try Self.repoRoot()
        let renderingRoot = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentRenderingInfrastructure",
            isDirectory: true
        )
        let banned = [
            "DocumentRenderingClient",
            "StrokeRenderingGateway",
            "LayerCompositingGateway",
            "OverlayRenderingGateway",
            "MetalRuntimeContext",
            "rasterizedStrokePixelData"
        ]

        let sources = try Self.swiftSources(under: renderingRoot)
        for source in sources {
            let body = try String(contentsOf: source, encoding: .utf8)
            for token in banned {
                #expect(!body.contains(token), "\(source.path) should not expose \(token)")
            }
        }
    }

    @Test
    func publicGpuOperationGatewayFactoryDoesNotConstructMetalServices() throws {
        let repoRoot = try Self.repoRoot()
        let factory = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentRenderingInfrastructure/DocumentGpuOperationGatewayFactory.swift",
            isDirectory: false
        )
        let body = try String(contentsOf: factory, encoding: .utf8)
        let banned = [
            "PrimoDocumentMetalRuntimeInfrastructure",
            "PrimoMetalDocumentProcessingClient",
            "MetalResourceStore",
            "MetalLayerMutationService",
            "MetalTextService",
            "PrimoMetalStrokeExecutionRequest"
        ]
        for token in banned {
            #expect(!body.contains(token), "DocumentGpuOperationGatewayFactory should not construct \(token)")
        }
    }

    @Test
    func metalStrokeAndLayerInfrastructureDoNotDependOnRenderingInfrastructure() throws {
        let repoRoot = try Self.repoRoot()
        let manifest = repoRoot.appendingPathComponent("Packages/PrimoModules/Package.swift", isDirectory: false)
        let body = try String(contentsOf: manifest, encoding: .utf8)
        let bannedEdges = [
            "\"PrimoDocumentMetalStrokeInfrastructure\",\n            dependencies: [\n                \"PrimoDocumentGPUContracts\",\n                \"PrimoDocumentMetalSurfaceInfrastructure\",\n                \"PrimoDocumentRenderingInfrastructure\"",
            "\"PrimoDocumentMetalLayerInfrastructure\",\n            dependencies: [\n                \"PrimoDocumentGPUContracts\",\n                \"PrimoDocumentMetalRuntimeInfrastructure\",\n                \"PrimoDocumentRenderingInfrastructure\""
        ]
        for edge in bannedEdges {
            #expect(!body.contains(edge), "Metal infrastructure must not depend on rendering infrastructure")
        }
    }

    @Test
    func testSupportUsesGpuStrokeSurfaceContractName() throws {
        let repoRoot = try Self.repoRoot()
        let support = repoRoot.appendingPathComponent("PrimoTests/TestSupport.swift", isDirectory: false)
        let body = try String(contentsOf: support, encoding: .utf8)
        #expect(!body.contains("applySoftwareStroke"))
        #expect(body.contains("applyGpuStrokeSurface"))
    }

    private static func repoRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "PrimoModules" {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path {
                throw CocoaError(.fileReadNoSuchFile)
            }
            url = parent
        }
        return url.deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func swiftSources(under root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return try enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true ? url : nil
        }
    }
}
