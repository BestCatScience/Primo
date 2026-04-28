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
    func appDocumentFeatureRootUsesPrimoRootNamesWithoutAppFeatureShims() throws {
        let repoRoot = try Self.repoRoot()
        let documentRoot = repoRoot.appendingPathComponent("App/Features/Document", isDirectory: true)
        let oldCanvasFeature = documentRoot.appendingPathComponent("CanvasFeature.swift", isDirectory: false)

        #expect(!FileManager.default.fileExists(atPath: oldCanvasFeature.path))

        let sources = try Self.swiftSources(under: documentRoot)
        let appFeatureShimFiles = sources.filter { source in
            source.lastPathComponent == "AppFeature.swift" ||
                source.lastPathComponent.hasPrefix("AppFeature+")
        }
        #expect(appFeatureShimFiles.isEmpty, "AppFeature shim files should be removed or renamed to feature-owned roots")

        for source in sources {
            let body = try String(contentsOf: source, encoding: .utf8)
            let banned = [
                "struct AppFeature ",
                "struct AppFeature:",
                "enum AppFeature ",
                "enum AppFeature:",
                "extension AppFeature ",
                "extension AppFeature:",
                "typealias AppFeature =",
                "AppFeature.",
                "PrimoRootIntegrationFeature",
                "IntegrationTypeAliases"
            ]
            for token in banned {
                #expect(!body.contains(token), "\(source.path) should use PrimoRootFeature or CrossFeatureIntegrationReducer instead of \(token)")
            }
        }
    }

    @Test
    func canvasImageRendererDoesNotOwnGpuProcessingServices() throws {
        let repoRoot = try Self.repoRoot()
        let renderer = repoRoot.appendingPathComponent("App/Rendering/MetalCanvasRenderer.swift", isDirectory: false)
        if !FileManager.default.fileExists(atPath: renderer.path) {
            return
        }
        let body = try String(contentsOf: renderer, encoding: .utf8)
        let banned = [
            "CanvasImageRenderer",
            "DocumentGpuOperationGateway",
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
    func canvasSurfaceViewsLiveInPresentationInfrastructure() throws {
        let repoRoot = try Self.repoRoot()
        let appRenderer = repoRoot.appendingPathComponent("App/Rendering/MetalCanvasRenderer.swift", isDirectory: false)
        let moduleRenderer = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoCanvasPresentationInfrastructure/CanvasMetalSurfaceViews.swift",
            isDirectory: false
        )

        #expect(!FileManager.default.fileExists(atPath: appRenderer.path))
        #expect(FileManager.default.fileExists(atPath: moduleRenderer.path))
    }

    @Test
    func appCanvasFeatureDoesNotReachGpuGatewayDocumentMutationOrPixelTransformHotPath() throws {
        let repoRoot = try Self.repoRoot()
        let canvasRoot = repoRoot.appendingPathComponent("App/Features/Canvas", isDirectory: true)
        let banned = [
            "import PrimoDocumentApplication",
            "import PrimoDocumentEngineInfrastructure",
            "import PrimoDocumentRenderingInfrastructure",
            "DocumentGpuOperationGateway",
            "DocumentGpuOperationGatewayFactory",
            "DocumentMutationGateway",
            "DocumentMutationWorkflowService",
            "DocumentMutationContract",
            "DocumentMutationFailure",
            "DocumentCanvasMutation",
            "DocumentPresentationRefresh",
            "LayerMutationFinalization",
            "SelectionWorkflowService",
            "GpuCanvasPreviewRenderer",
            "GpuLayerTransformProcessor",
            "CanvasImageRenderer",
            "PrimoMetalDocumentProcessingClient",
            "MetalRuntimeContext",
            "documentGpuOperationGateway",
            "documentMutationGateway",
            "documentMutationWorkflowService",
            "completeDocumentMutation",
            "performDocumentMutation",
            "alphaMask(",
            "croppedSelectionMask(",
            "transformedLayerPixelData(",
            "AppFeature.",
            "PrimoRootFeature.effectiveTransformQuad",
            "PrimoRootFeature.affineTransformQuad",
            "CrossFeatureIntegrationReducer.effectiveTransformQuad",
            "CrossFeatureIntegrationReducer.affineTransformQuad"
        ]

        let sources = try Self.swiftSources(under: canvasRoot)
        for source in sources {
            let body = try String(contentsOf: source, encoding: .utf8)
            for token in banned {
                #expect(!body.contains(token), "\(source.path) should not reference \(token)")
            }
        }
    }

    @Test
    func canvasPresentationModelsLiveOutsideAppModelLayer() throws {
        let repoRoot = try Self.repoRoot()
        let appModels = repoRoot.appendingPathComponent("App/Models/PaintModels.swift", isDirectory: false)
        let body = try String(contentsOf: appModels, encoding: .utf8)
        let banned = [
            "enum StudioToolKind",
            "enum EyedropperSamplingSource",
            "struct StrokePoint",
            "struct Stroke:",
            "struct PreviewStrokeStyle",
            "struct SampledColor"
        ]
        for token in banned {
            #expect(!body.contains(token), "Canvas presentation model \(token) should live in PrimoDocumentContracts")
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
    func metalShadersAreOwnedByRuntimePackage() throws {
        let repoRoot = try Self.repoRoot()
        let appShader = repoRoot.appendingPathComponent("App/Rendering/PaintShaders.metal", isDirectory: false)
        let runtimeShader = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentMetalRuntimeInfrastructure/Shaders/PaintShaders.metal",
            isDirectory: false
        )

        #expect(!FileManager.default.fileExists(atPath: appShader.path))
        #expect(FileManager.default.fileExists(atPath: runtimeShader.path))
    }

    @Test
    func metalRuntimeDoesNotUseMainBundleDefaultLibrary() throws {
        let repoRoot = try Self.repoRoot()
        let runtimeRoot = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentMetalRuntimeInfrastructure",
            isDirectory: true
        )

        let sources = try Self.swiftSources(under: runtimeRoot)
        for source in sources {
            let body = try String(contentsOf: source, encoding: .utf8)
            #expect(!body.contains(".makeDefaultLibrary()"), "\(source.path) should load the package Metal library explicitly")
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
