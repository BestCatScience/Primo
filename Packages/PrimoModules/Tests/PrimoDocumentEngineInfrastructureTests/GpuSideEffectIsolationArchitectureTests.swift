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
    func appFeatureRuntimeReducerShimsAreRemoved() throws {
        let repoRoot = try Self.repoRoot()
        let documentRoot = repoRoot.appendingPathComponent("App/Features/Document", isDirectory: true)
        let sources = try Self.swiftSources(under: documentRoot)
        let filenames = Set(sources.map(\.lastPathComponent))
        let rootWorkflowPrefix = "RootFeature" + "Workflow"

        #expect(!filenames.contains("FeatureRuntimeReducers.swift"))
        #expect(!filenames.contains("DocumentFeatureRuntimeReducer.swift"))
        #expect(filenames.allSatisfy { !$0.hasPrefix(rootWorkflowPrefix) })
        #expect(filenames.allSatisfy { !$0.hasPrefix("CrossFeatureIntegrationReducer+") })
        #expect(filenames.allSatisfy { !$0.hasPrefix("PrimoRootFeature+") || !$0.contains("Workflow") })
        #expect(filenames.allSatisfy { !$0.hasPrefix("PrimoRootFeature+") || !$0.contains("Routing") })

        let banned = [
            "DocumentFeatureRuntimeReducer",
            "PrimoFeatureRuntimeReducer",
            "ApplicationFeatureRuntimeReducer",
            "WorkspaceFeatureRuntimeReducer",
            "ImportExportFeatureRuntimeReducer"
        ]
        for source in sources {
            let body = try String(contentsOf: source, encoding: .utf8)
            for token in banned {
                #expect(!body.contains(token), "\(source.path) should not contain \(token)")
            }
        }
    }

    @Test
    func crossFeatureIntegrationReducerOwnsNoDependencies() throws {
        let repoRoot = try Self.repoRoot()
        let integrationSources = [
            "App/Features/Document/CrossFeatureIntegrationReducer.swift",
            "App/Features/Document/ApplicationWorkspaceBridge.swift",
            "App/Features/Document/WorkspaceDocumentBridge.swift",
            "App/Features/Document/ImportExportWorkspaceBridge.swift",
            "App/Features/Document/AIImageDocumentBridge.swift",
            "App/Features/Document/DocumentApplicationFeedbackBridge.swift"
        ]
        let rootWorkflowReducerName = "RootFeature" + "WorkflowReducer"
        for sourcePath in integrationSources {
            let source = repoRoot.appendingPathComponent(sourcePath, isDirectory: false)
            let body = try String(contentsOf: source, encoding: .utf8)
            #expect(Self.dependencyKeys(in: body).isEmpty, "\(sourcePath) should be dependency-free")
            #expect(!body.contains("state."), "\(sourcePath) should relay feature actions without direct root state access")
            #expect(!body.contains(rootWorkflowReducerName), "\(sourcePath) should not delegate to root workflow execution")
            #expect(!body.contains("func handle"), "\(sourcePath) should not own workflow handlers")
            #expect(!body.contains("func route"), "\(sourcePath) should not own workflow routing helpers")
        }

        let rootWorkflowReducer = repoRoot.appendingPathComponent(
            "App/Features/Document/\(rootWorkflowReducerName).swift",
            isDirectory: false
        )
        #expect(!FileManager.default.fileExists(atPath: rootWorkflowReducer.path), "\(rootWorkflowReducerName).swift should be removed")

        let documentRoot = repoRoot.appendingPathComponent("App/Features/Document", isDirectory: true)
        let rootWorkflowPrefix = "RootFeature" + "Workflow"
        let rootWorkflowSources = try Self.swiftSources(under: documentRoot)
            .filter { source in
                let filename = source.lastPathComponent
                return filename.hasPrefix(rootWorkflowPrefix + "+")
            }
        #expect(rootWorkflowSources.isEmpty, "\(rootWorkflowPrefix)+*.swift should be removed")

        let checkedRoots = [
            "App",
            "PrimoTests",
            "Packages/PrimoModules/Tests"
        ]
        for checkedRoot in checkedRoots {
            let sourceRoot = repoRoot.appendingPathComponent(checkedRoot, isDirectory: true)
            for source in try Self.swiftSources(under: sourceRoot) {
                let sourceBody = try String(contentsOf: source, encoding: .utf8)
                #expect(!sourceBody.contains(rootWorkflowReducerName), "\(source.path) should not reference \(rootWorkflowReducerName)")
            }
        }
    }

    @Test
    func rootWorkflowDoesNotMutateApplicationStateDirectly() throws {
        let repoRoot = try Self.repoRoot()
        let documentRoot = repoRoot.appendingPathComponent("App/Features/Document", isDirectory: true)
        let rootWorkflowSources = try Self.swiftSources(under: documentRoot)
            .filter { source in
                let filename = source.lastPathComponent
                let rootWorkflowPrefix = "RootFeature" + "Workflow"
                return filename == "\(rootWorkflowPrefix)Reducer.swift"
                    || filename.hasPrefix(rootWorkflowPrefix + "+")
                    || filename == "CrossFeatureIntegrationReducer.swift"
                    || filename.hasSuffix("Bridge.swift")
            }
        let banned = [
            "state.application.beginStartup(",
            "state.application.beginHydration(",
            "state.application.finishHydration(",
            "state.application.failHydration(",
            "state.application.completeWorkspaceProjectLoad(",
            "state.application.presentBanner(",
            "state.application.presentFeedback(",
            "state.application.showHome(",
            "state.application.showWorkspace(",
            "state.application.clearBanner(",
            "state.application.recovery.",
            "state.application.recovery.removeItem(",
            "state.application.recovery.completeRestore(",
            "state.application.recovery.dismiss("
        ]
        for source in rootWorkflowSources {
            let body = try String(contentsOf: source, encoding: .utf8)
            for token in banned {
                #expect(!body.contains(token), "\(source.path) should relay \(token) through ApplicationFeature actions")
            }
        }
    }

    @Test
    func primoRootStateDoesNotExposeFeatureSlicePassthroughs() throws {
        let repoRoot = try Self.repoRoot()
        let stateFile = repoRoot.appendingPathComponent(
            "App/Features/Document/PrimoRootFeature+State.swift",
            isDirectory: false
        )
        let body = try String(contentsOf: stateFile, encoding: .utf8)
        let banned = [
            "var saveHistory:",
            "var export:",
            "var brushPalette:",
            "var layerSidebar:",
            "var canvas:",
            "var brushPanel:",
            "var layerPanel:"
        ]
        for token in banned {
            #expect(!body.contains(token), "PrimoRootFeature.State should not expose \(token) passthrough")
        }
    }

    @Test
    func topLevelFeaturesHaveReducerBodiesAndDelegateSurfaces() throws {
        let repoRoot = try Self.repoRoot()
        let featureFiles = [
            "ApplicationFeature.swift",
            "WorkspaceFeature.swift",
            "DocumentFeature.swift",
            "ImportExportFeature.swift"
        ]
        for filename in featureFiles {
            let url = repoRoot.appendingPathComponent("App/Features/Document/\(filename)")
            let body = try String(contentsOf: url, encoding: .utf8)
            #expect(!body.contains("Reduce { _, _ in .none }"), "\(filename) should not be an empty reducer shell")
            #expect(body.contains("case delegate(") || body.contains("case delegate"), "\(filename) should expose delegate action surface")
        }
    }

    @Test
    func documentFeatureDelegatesEditorWorkflowsToFocusedReducers() throws {
        let repoRoot = try Self.repoRoot()
        let documentRoot = repoRoot.appendingPathComponent("App/Features/Document", isDirectory: true)
        let documentFeature = documentRoot.appendingPathComponent("DocumentFeature.swift", isDirectory: false)
        let documentEditingRouter = documentRoot.appendingPathComponent("DocumentEditingRouter.swift", isDirectory: false)
        let body = try String(contentsOf: documentFeature, encoding: .utf8)
        let routerBody = try String(contentsOf: documentEditingRouter, encoding: .utf8)
        let workflowReducers = [
            ("PresentationRefreshReducer", "presentation"),
            ("DocumentLifecycleReducer", "lifecycle"),
            ("CanvasEditingWorkflowReducer", "canvasEditing"),
            ("LayerWorkflowReducer", "layerWorkflow"),
            ("AdjustmentWorkflowReducer", "adjustment")
        ]

        for (reducer, action) in workflowReducers {
            let reducerFile = documentRoot.appendingPathComponent("\(reducer).swift", isDirectory: false)
            #expect(FileManager.default.fileExists(atPath: reducerFile.path), "\(reducer).swift should own a focused document workflow")
            #expect(
                body.contains("Scope(state: \\.editing, action: \\.\(action))") && body.contains("\(reducer)()"),
                "DocumentFeature should compose \(reducer) through the shared editing workflow scope"
            )
        }
        #expect(
            body.contains("Scope(state: \\.self, action: \\.aiImageWorkflow)") && body.contains("AIImageWorkflowReducer()"),
            "AIImageWorkflowReducer should remain the only parent-state workflow while it owns job identity"
        )
        #expect(body.contains("DocumentEditingRouter()"), "DocumentFeature should delegate editing action fan-out to DocumentEditingRouter")
        #expect(routerBody.contains("struct DocumentEditingRouter: Reducer"), "DocumentEditingRouter should own parent-level routing")
        #expect(routerBody.contains(".send(.canvasEditing(.brushPalette(brushPaletteAction)))"))
        #expect(routerBody.contains(".send(.layerWorkflow(.brushPalette(brushPaletteAction)))"))
        #expect(routerBody.contains(".send(.canvasEditing(.layerSidebar(layerSidebarAction)))"))
        #expect(routerBody.contains(".send(.layerWorkflow(.layerSidebar(layerSidebarAction)))"))
        #expect(!body.contains(".send(.canvasEditing(.brushPalette("), "DocumentFeature should not own brush palette fan-out")
        #expect(!body.contains(".send(.layerWorkflow(.brushPalette("), "DocumentFeature should not own brush palette fan-out")

        #expect(Self.dependencyKeys(in: body).isEmpty, "DocumentFeature.swift should not own workflow dependencies")
        #expect(!body.contains("DocumentFeature()"), "DocumentFeature.swift should not instantiate itself as a workflow shell")
        #expect(!body.contains("DocumentWorkflowExecutor"), "DocumentFeature.swift should not reference a shared workflow shell")
        #expect(!body.contains("func handle"), "DocumentFeature.swift should not own workflow handlers")
        #expect(!body.contains("case .editing"), "DocumentFeature.swift should route editing actions through workflow reducers")
        #expect(!body.contains("case .photoImportReceived"), "DocumentFeature.swift should route layer import through LayerWorkflowReducer")
        #expect(!body.contains("case .aiImageEditRequested"), "DocumentFeature.swift should route AI image edits through AIImageWorkflowReducer")
        #expect(body.contains("var editing = DocumentEditingState()"), "DocumentFeature.State should own editing state through a single aggregate")
        #expect(!body.contains("var brushPalette:"), "DocumentFeature.State should not re-expose brush palette passthrough state")
        #expect(!body.contains("var layerSidebar:"), "DocumentFeature.State should not re-expose layer sidebar passthrough state")
        #expect(!body.contains("var canvas:"), "DocumentFeature.State should not re-expose canvas passthrough state")
        #expect(!body.contains("var brushPanel:"), "DocumentFeature.State should not re-expose brush panel passthrough state")
        #expect(!body.contains("var layerPanel:"), "DocumentFeature.State should not re-expose layer panel passthrough state")

        let executorFile = documentRoot.appendingPathComponent("DocumentWorkflowExecutor.swift", isDirectory: false)
        #expect(!FileManager.default.fileExists(atPath: executorFile.path), "DocumentWorkflowExecutor.swift should not exist")

        let oldWorkflowFilenames = [
            "DocumentFeature+Workflow.swift",
            "DocumentFeature+CanvasLifecycleWorkflow.swift",
            "DocumentFeature+CanvasStrokeWorkflow.swift",
            "DocumentFeature+SelectionWorkflow.swift",
            "DocumentFeature+SelectionTransformWorkflow.swift",
            "DocumentFeature+DocumentMutationWorkflow.swift",
            "DocumentFeature+AdjustmentPreviewWorkflow.swift",
            "DocumentFeature+AIImageWorkflow.swift"
        ]
        for filename in oldWorkflowFilenames {
            let oldFile = documentRoot.appendingPathComponent(filename, isDirectory: false)
            #expect(!FileManager.default.fileExists(atPath: oldFile.path), "\(filename) should be renamed to its workflow reducer owner")
        }

        for (reducer, _) in workflowReducers + [("AIImageWorkflowReducer", "aiImageWorkflow")] {
            let reducerBody = try String(
                contentsOf: documentRoot.appendingPathComponent("\(reducer).swift", isDirectory: false),
                encoding: .utf8
            )
            #expect(!reducerBody.contains("typealias ParentAction"), "\(reducer).swift should reduce its workflow action directly")
            #expect(!reducerBody.contains("typealias Action = DocumentFeature.Action"), "\(reducer).swift should not alias the parent action")
            #expect(!reducerBody.contains("guard case let ."), "\(reducer).swift should not unwrap parent action cases")
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
        let bannedImports = Set([
            "PrimoDocumentApplication",
            "PrimoDocumentEngineInfrastructure",
            "PrimoDocumentRenderingInfrastructure"
        ])
        let banned = [
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
            "PrimoRootFeature.affineTransformQuad"
        ]

        let sources = try Self.swiftSources(under: canvasRoot)
        for source in sources {
            let body = try String(contentsOf: source, encoding: .utf8)
            let imports = Self.swiftImports(in: body)
            #expect(
                imports.isDisjoint(with: bannedImports),
                "\(source.path) should not import app workflow or concrete document runtime modules"
            )
            for token in banned {
                #expect(!body.contains(token), "\(source.path) should not reference \(token)")
            }
        }
    }

    @Test
    func appAndRootTestsUseRuntimeFacadesInsteadOfInfrastructureProducts() throws {
        let repoRoot = try Self.repoRoot()
        let bannedImports = Set([
            "PrimoAIImageInfrastructure",
            "PrimoBrushInfrastructure",
            "PrimoCanvasPresentationInfrastructure",
            "PrimoDocumentEngineInfrastructure",
            "PrimoDocumentInfrastructure",
            "PrimoDocumentMetalLayerInfrastructure",
            "PrimoDocumentMetalRuntimeInfrastructure",
            "PrimoDocumentMetalStrokeInfrastructure",
            "PrimoDocumentMetalSurfaceInfrastructure",
            "PrimoDocumentPersistenceInfrastructure",
            "PrimoDocumentMetalRuntimeInfrastructure",
            "PrimoDocumentRenderingInfrastructure",
            "PrimoDocumentRuntimeLive",
            "PrimoDocumentStrokeInfrastructure",
            "PrimoDocumentTimelapseInfrastructure",
            "PrimoWorkspaceInfrastructure"
        ])
        for rootName in ["App", "PrimoTests"] {
            let root = repoRoot.appendingPathComponent(rootName, isDirectory: true)
            for source in try Self.swiftSources(under: root) {
                let body = try String(contentsOf: source, encoding: .utf8)
                let imports = Self.swiftImports(in: body)
                #expect(
                    imports.isDisjoint(with: bannedImports),
                    "\(source.path) should import runtime/application facades instead of concrete infrastructure modules"
                )
            }
        }
        let appRoot = repoRoot.appendingPathComponent("App", isDirectory: true)
        for source in try Self.swiftSources(under: appRoot) {
            let body = try String(contentsOf: source, encoding: .utf8)
            let imports = Self.swiftImports(in: body)
            #expect(
                !imports.contains("PrimoDocumentRuntimeLive"),
                "\(source.path) should route live document runtime wiring through PrimoDocumentAppSupport"
            )
        }

        let projectYML = try String(
            contentsOf: repoRoot.appendingPathComponent("project.yml", isDirectory: false),
            encoding: .utf8
        )
        let appTargetBlock = try #require(Self.yamlTargetBlock(named: "Primo", in: projectYML))
        let bannedProducts = [
            "product: PrimoAIImageInfrastructure",
            "product: PrimoBrushInfrastructure",
            "product: PrimoCanvasPresentationInfrastructure",
            "product: PrimoDocumentEngineInfrastructure",
            "product: PrimoDocumentInfrastructure",
            "product: PrimoDocumentMetalLayerInfrastructure",
            "product: PrimoDocumentMetalRuntimeInfrastructure",
            "product: PrimoDocumentMetalStrokeInfrastructure",
            "product: PrimoDocumentMetalSurfaceInfrastructure",
            "product: PrimoDocumentPersistenceInfrastructure",
            "product: PrimoDocumentRenderingInfrastructure",
            "product: PrimoDocumentRuntimeLive",
            "product: PrimoDocumentStrokeInfrastructure",
            "product: PrimoDocumentTimelapseInfrastructure",
            "product: PrimoWorkspaceInfrastructure"
        ]
        #expect(appTargetBlock.contains("product: PrimoDocumentRuntime"))
        #expect(appTargetBlock.contains("product: PrimoDocumentAppSupport"))
        #expect(!appTargetBlock.contains("product: PrimoDocumentRuntimeLive"))
        for product in bannedProducts {
            #expect(!projectYML.contains(product), "External targets should depend on runtime facades instead of \(product)")
        }
    }

    @Test
    func projectTargetGraphRoutesRuntimeWiringThroughAppSupport() throws {
        let repoRoot = try Self.repoRoot()
        let projectYML = try String(
            contentsOf: repoRoot.appendingPathComponent("project.yml", isDirectory: false),
            encoding: .utf8
        )
        let package = try String(
            contentsOf: repoRoot.appendingPathComponent("Packages/PrimoModules/Package.swift", isDirectory: false),
            encoding: .utf8
        )
        let appSupportBlock = try #require(Self.yamlTargetBlock(named: "PrimoAppSupport", in: projectYML))
        let appTargetBlock = try #require(Self.yamlTargetBlock(named: "Primo", in: projectYML))

        #expect(appSupportBlock.contains("type: framework"))
        #expect(appSupportBlock.contains("path: App/Support"))
        #expect(appTargetBlock.contains("- target: PrimoAppSupport"))
        #expect(appTargetBlock.contains("product: PrimoDocumentAppSupport"))
        #expect(!appTargetBlock.contains("product: PrimoDocumentRuntimeLive"))
        let productNames = PackageManifestProductParser.libraryProductNames(in: package)
        #expect(productNames.contains("PrimoDocumentAppSupport"))
        #expect(!productNames.contains("PrimoDocumentRuntimeLive"))
        let graph = try Self.packageTargetGraph()
        let appSupportDependencies = try #require(graph["PrimoDocumentAppSupport"])
        #expect(
            appSupportDependencies.contains("PrimoDocumentRuntimeLive"),
            "PrimoDocumentAppSupport should depend on the internal PrimoDocumentRuntimeLive target"
        )

        let runtimeWiringProducts = [
            "PrimoBrushRuntime",
            "PrimoWorkspaceRuntime",
            "PrimoAIImageRuntime"
        ]
        for product in runtimeWiringProducts {
            #expect(
                appSupportBlock.contains("product: \(product)"),
                "PrimoAppSupport should own live runtime wiring dependency \(product)"
            )
            #expect(
                !appTargetBlock.contains("product: \(product)"),
                "Primo app target should depend on \(product) through PrimoAppSupport"
            )
        }

        let stillAppFacingProducts = [
            "PrimoWorkspaceApplication",
            "PrimoCanvasInputDomain",
            "PrimoCanvasPresentationDomain",
            "PrimoDocumentRuntime",
            "PrimoDocumentAppSupport",
            "PrimoDocumentStrokeApplication",
            "PrimoAIImageDomain",
            "PrimoAIImageApplication"
        ]
        for product in stillAppFacingProducts {
            #expect(
                appTargetBlock.contains("product: \(product)"),
                "Primo app target should keep direct access only to App-facing product \(product)"
            )
        }
    }

    @Test
    func packageDoesNotPublishInfrastructureProducts() throws {
        let repoRoot = try Self.repoRoot()
        let package = try String(
            contentsOf: repoRoot.appendingPathComponent("Packages/PrimoModules/Package.swift", isDirectory: false),
            encoding: .utf8
        )
        for product in Self.infrastructureProductNames(in: package) {
            #expect(!product.hasSuffix("Infrastructure"), "\(product) should remain an internal target, not a library product")
        }
        let productNames = PackageManifestProductParser.libraryProductNames(in: package)
        #expect(
            !productNames.contains("PrimoDocumentRuntimeLive"),
            "PrimoDocumentRuntimeLive should remain an internal target, not a library product"
        )
    }

    @Test
    func packageDoesNotPublishRuntimeContractsAliasBackedByFacade() throws {
        let repoRoot = try Self.repoRoot()
        let package = try String(
            contentsOf: repoRoot.appendingPathComponent("Packages/PrimoModules/Package.swift", isDirectory: false),
            encoding: .utf8
        )

        #expect(!package.contains(".library(name: \"PrimoDocumentRuntimeContracts\""))
        #expect(package.contains(".library(name: \"PrimoDocumentRuntime\", targets: [\"PrimoDocumentRuntime\"])"))
    }

    @Test
    func architectureSourceParsersIgnoreNonSemanticTokens() {
        let imports = Self.swiftImports(
            in: """
            // import PrimoDocumentEngineInfrastructure
            let example = "import PrimoDocumentRenderingInfrastructure"
            @testable import PrimoCanvasPresentationRuntime
            import PrimoDocumentRuntime
            import PrimoDocumentRuntimeLive
            @_exported import PrimoWorkspaceRuntime
            import struct Foundation.URL
            import PrimoDocumentApplication
            """
        )

        #expect(imports == Set([
            "PrimoCanvasPresentationRuntime",
            "PrimoDocumentRuntime",
            "PrimoDocumentRuntimeLive",
            "PrimoWorkspaceRuntime",
            "Foundation",
            "PrimoDocumentApplication"
        ]))

        let products = Self.infrastructureProductNames(
            in: """
            // .library(name: "PrimoDocumentEngineInfrastructure", targets: ["Ignored"])
            let ignored = ".library(name: \\"PrimoWorkspaceInfrastructure\\", targets: [])"
            products: [
                .library(
                    name: "PrimoDocumentRuntime",
                    targets: ["PrimoDocumentRuntime"]
                ),
                .library(name: "PrimoWorkspaceInfrastructure", targets: ["PrimoWorkspaceInfrastructure"]),
            ]
            """
        )

        #expect(products == ["PrimoWorkspaceInfrastructure"])
    }

    #if os(macOS)
        @Test
        func publicRuntimeFacadeSymbolGraphsMatchSnapshots() throws {
            let repoRoot = try Self.repoRoot()
            let moduleNames = [
                "PrimoDocumentRuntime",
                "PrimoDocumentMutationContracts",
                "PrimoDocumentApplication",
                "PrimoWorkspaceRuntime"
            ]
            let generatedSnapshots = try Self.generatedPublicSymbolSnapshots(
                for: moduleNames,
                repoRoot: repoRoot
            )

            for moduleName in moduleNames {
                let expectedURL = repoRoot.appendingPathComponent(
                    "Packages/PrimoModules/Tests/PrimoDocumentEngineInfrastructureTests/__Snapshots__/SymbolGraphs/\(moduleName).symbols.tsv",
                    isDirectory: false
                )
                let expected = try String(contentsOf: expectedURL, encoding: .utf8)
                let actual = try #require(generatedSnapshots[moduleName])
                #expect(
                    actual == expected,
                    "\(moduleName) public symbol graph drifted. Run scripts/update-symbol-snapshots.sh if the API change is intentional."
                )
                let publicInfrastructureSymbols = SymbolSnapshotRecord.records(in: actual)
                    .filter(\.referencesInfrastructureTypeName)
                #expect(
                    publicInfrastructureSymbols.isEmpty,
                    "\(moduleName) public symbol graph should not expose infrastructure type names: \(publicInfrastructureSymbols.map(\.line))"
                )
            }
        }
    #endif

    @Test
    func documentMutationGatewayDoesNotExposePublicRawMutationClosuresToApp() throws {
        let repoRoot = try Self.repoRoot()
        let contract = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentMutationContracts/DocumentMutationRuntimeContracts.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let gatewayBody = try #require(Self.declarationBody(named: "DocumentMutationGateway", in: contract))
        #expect(
            !Self.publicTopLevelSymbols(in: contract).contains("DocumentMutationGateway"),
            "DocumentMutationGateway is raw mutation authority and should not be public API"
        )
        #expect(
            Self.initializerSignatures(accessLevel: "public", in: gatewayBody).isEmpty,
            "DocumentMutationGateway should not expose public raw closure initializers"
        )
        #expect(
            Self.storedPropertyNames(accessLevel: "public", in: gatewayBody).isEmpty,
            "DocumentMutationGateway raw closure storage should not be public API"
        )
        #expect(
            Self.storedPropertyNames(accessLevel: "package", in: gatewayBody).isEmpty,
            "DocumentMutationGateway raw closure storage should be private, not package API"
        )
        let packageMethods = Set(Self.functionSignatures(accessLevel: "package", in: gatewayBody).map(Self.normalizedSignature))
        let rawMutationMethods: Set<String> = [
            "package func deleteLayer(_ index: Int)",
            "package func setActiveLayer(_ index: Int)",
            "package func replaceLayerPixels(_ index: Int, _ pixelData: Data)",
            "package func replaceLayerPixelsInRect(_ index: Int, _ rect: LayerPixelRect, _ pixelData: Data)",
            "package func applyLayerProcessing(_ index: Int, _ request: LayerProcessingRequest)",
            "package func clearLayer(_ index: Int)",
            "package func replaceLayerMask(_ index: Int, _ mask: Data)"
        ]
        #expect(
            rawMutationMethods.isSubset(of: packageMethods),
            "DocumentMutationGateway raw operations should be exposed only as package methods"
        )

        let appRoot = repoRoot.appendingPathComponent("App", isDirectory: true)
        for source in try Self.swiftSources(under: appRoot) {
            let body = try String(contentsOf: source, encoding: .utf8)
            #expect(
                !Self.dependencyKeys(in: body).contains("documentMutationGateway"),
                "\(source.path) reachability guard: App should use validated command/workflow services instead of raw DocumentMutationGateway"
            )
        }
    }

    @Test
    func documentMutationWorkflowServicePublicContentMethodsUseValidatedCommands() throws {
        let repoRoot = try Self.repoRoot()
        let workflow = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentApplication/DocumentMutationWorkflow.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let contentContracts = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentApplication/DocumentLayerContentMutationContracts.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )

        for token in [
            "package enum LayerContentMutationCommand",
            "public enum ValidatedLayerContentMutationCommand",
            "public protocol LayerContentGateway",
            "package struct LayerContentMutationUseCase"
        ] {
            #expect(contentContracts.contains(token))
        }

        for token in [
            "private func executeContent(_ command: LayerContentMutationCommand)",
            "execute(.content(command))"
        ] {
            #expect(workflow.contains(token))
        }
        #expect(!workflow.contains("documentMutationGateway"))
        #expect(!workflow.contains("textLayerGateway"))

        let publicContentMethods = [
            "replaceLayerPixels(_ command: LayerPixelReplacementCommand)",
            "applyLayerProcessing(_ index: EditableLayerIndex, request: LayerProcessingRequest)",
            "setTextLayer(_ index: EditableLayerIndex, textLayer: TextLayerData)",
            "clearLayer(_ index: EditableLayerIndex)",
            "replaceLayerMask(_ index: EditableLayerIndex, mask: LayerMaskData)",
            "clearLayerMask(_ index: EditableLayerIndex)",
            "applyLayerMask(_ index: EditableLayerIndex)"
        ]
        for signature in publicContentMethods {
            let body = try #require(Self.functionBody(matching: "public func \(signature)", in: workflow))
            #expect(body.contains(".rawValue") || body.contains("LayerPixelReplacementCommand"))
            #expect(!body.contains("documentMutationGateway."))
            #expect(!body.contains("textLayerGateway."))
        }
        for signature in [
            "replaceLayerPixels(_ index: Int, pixelData: Data)",
            "applyLayerProcessing(_ index: Int, request: LayerProcessingRequest)",
            "setTextLayer(_ index: Int, textLayer: TextLayerData)",
            "clearLayer(_ index: Int)",
            "replaceLayerMask(_ index: Int, maskData: Data)",
            "clearLayerMask(_ index: Int)",
            "applyLayerMask(_ index: Int)"
        ] {
            #expect(
                Self.functionBody(matching: "public func \(signature)", in: workflow) == nil,
                "\(signature) should not remain public after typed content commands exist"
            )
        }
        #expect(!workflow.contains("LayerPixelData(width: geometry.width, height: geometry.height, rgba: pixelData)"))
        #expect(!workflow.contains("LayerMaskData(width: geometry.width, height: geometry.height, bytes: maskData)"))
    }

    @Test
    func documentRuntimeFacadeDoesNotReexportConcreteInfrastructureModules() throws {
        let repoRoot = try Self.repoRoot()
        let facade = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentRuntime/DocumentRuntimeFacade.swift",
            isDirectory: false
        )
        let body = try String(contentsOf: facade, encoding: .utf8)
        #expect(Self.exportedImports(in: body).isEmpty, "PrimoDocumentRuntime should expose explicit App-facing wrappers instead of reexporting infrastructure modules")
        #expect(Self.publicTopLevelTypealiases(in: body).isEmpty, "PrimoDocumentRuntime should wrap App-facing infrastructure APIs instead of typealiasing them")
        let publicStoredProperties = Set(Self.storedPropertyNames(accessLevel: "public", in: body))
        let bannedPublicStoredProperties: Set<String> = [
            "queryGateway",
            "gpuOperationGateway",
            "textLayerGateway",
            "mutationGateway",
            "canvasCommands",
            "layerCommands",
            "strokeCommands",
            "historyCommands",
            "mutationWorkflow",
            "contentService",
            "canvasEditingWorkflow",
            "selectionWorkflow",
            "renderingWorkflow",
            "textLayerService",
            "exportClient",
            "persistenceClient"
        ]
        #expect(
            publicStoredProperties.isDisjoint(with: bannedPublicStoredProperties),
            "Runtime facade wrappers should expose behavior through methods/properties, not public raw service storage"
        )
        #expect(!body.contains("releaseSurfaceHandleHandler"), "DocumentRenderingWorkflow should not carry resource-release authority")
        #expect(!body.contains("init(gpuOperations:"), "Runtime facade wrappers should not expose raw GPU gateway injection; live modules own that wiring")
        #expect(
            body.contains("public func replaceLayerPixels(_ command: LayerPixelReplacementCommand) -> DocumentMutationResult"),
            "LayerEditingRuntime should expose typed pixel replacement"
        )
        let publicFunctionCallables = Self.callables(accessLevel: "public", in: body)
            .filter { $0.kind == "func" }
        #expect(
            !publicFunctionCallables.contains { callable in
                callable.name == "replaceLayerPixels" &&
                    callable.hasParameter(named: "index", type: "Int") &&
                    callable.hasParameter(named: "pixelData", type: "Data")
            }
        )

        let renderingWorkflowBody = try #require(Self.typeBody(named: "DocumentRenderingWorkflow", in: body))
        let publicRenderingInitializers = Self.initializerSignatures(accessLevel: "public", in: renderingWorkflowBody)
        #expect(
            publicRenderingInitializers.allSatisfy { !$0.contains("compositedPaperPreviewRGBA") },
            "DocumentRenderingWorkflow should not publicly accept raw rendering closure tables"
        )
        #expect(
            Self.initializerSignatures(accessLevel: "package", in: renderingWorkflowBody)
                .contains(where: { $0.contains("compositedPaperPreviewRGBA") }),
            "Raw rendering closure construction should stay package-scoped"
        )

        let publicSymbols = Set(Self.publicTopLevelSymbols(in: body))
        let expectedSymbols: Set<String> = [
            "DocumentRuntime",
            "DocumentApplicationRuntime",
            "DocumentApplicationWorkflowRuntime",
            "DocumentPresentationRuntime",
            "CanvasMutationRuntime",
            "StrokeEditingRuntime",
            "LayerEditingRuntime",
            "LayerStructureEditingRuntime",
            "LayerContentEditingRuntime",
            "TextLayerEditingRuntime",
            "LayerSelectionEditingRuntime",
            "LayerTransformEditingRuntime",
            "CanvasEditingRuntime",
            "LayerPreviewLeaseRuntime",
            "DocumentPersistenceRuntime",
            "DocumentExportRuntime",
            "CanvasPreviewRuntime",
            "DocumentCommand",
            "DocumentCommandOutcome",
            "DocumentCanvasCommand",
            "DocumentLayerCommand",
            "DocumentStrokeCommand",
            "DocumentHistoryCommand",
            "DocumentPresentationRequest",
            "DocumentMutationSuccess",
            "DocumentHistoryState",
            "DocumentPresentationReader",
            "DocumentRenderingWorkflow",
            "DocumentTextLayerService",
            "DocumentPersistenceClient",
            "DocumentExportClient",
            "DocumentProjectPreview",
            "TimelapseExportProgress",
            "TimelapseExportResult",
            "TimelapseExportError"
        ]
        #expect(publicSymbols == expectedSymbols)
    }

    @Test
    func documentRuntimeFacadeStaysFreeOfLiveInfrastructureWiring() throws {
        let repoRoot = try Self.repoRoot()
        let runtimeRoot = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentRuntime",
            isDirectory: true
        )
        let graph = try Self.packageTargetGraph()
        let runtimeDependencies = try #require(graph["PrimoDocumentRuntime"])
        let bannedDependencySuffixes = ["Infrastructure", "RuntimeLive"]
        for dependency in runtimeDependencies {
            #expect(
                bannedDependencySuffixes.allSatisfy { !dependency.hasSuffix($0) },
                "PrimoDocumentRuntime should remain App-facing and not depend on live/infrastructure target \(dependency)"
            )
        }

        let bannedImports: Set<String> = [
            "PrimoDocumentRuntimeLive",
            "PrimoDocumentEngineInfrastructure",
            "PrimoDocumentMetalRuntimeInfrastructure",
            "PrimoDocumentMetalStrokeInfrastructure",
            "PrimoDocumentRenderingInfrastructure",
            "PrimoDocumentStrokeInfrastructure"
        ]
        let bannedWiringTokens = [
            "Factory.live(",
            ".live(",
            "DocumentEngineRuntimeCompositionFactory.live",
            "DocumentGpuOperationGatewayFactory.live",
            "PrimoDocumentEngineInfrastructure."
        ]
        for source in try Self.swiftSources(under: runtimeRoot) {
            let body = try String(contentsOf: source, encoding: .utf8)
            let imports = Self.swiftImports(in: body)
            #expect(
                imports.isDisjoint(with: bannedImports),
                "\(source.path) should stay free of live/infrastructure imports"
            )
            let semanticBody = Self.swiftCodeWithCommentsAndStringsBlanked(in: body)
            for token in bannedWiringTokens {
                #expect(
                    !semanticBody.contains(token),
                    "\(source.path) should not own live factory or infrastructure wiring token \(token)"
                )
            }
        }
    }

    @Test
    func documentRuntimeLiveOwnsLiveFactoriesAndInfrastructureWrappers() throws {
        let repoRoot = try Self.repoRoot()
        let liveRoot = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentRuntimeLive",
            isDirectory: true
        )
        let liveBodies = try Self.swiftSources(under: liveRoot).map {
            try String(contentsOf: $0, encoding: .utf8)
        }
        let liveBody = liveBodies.joined(separator: "\n")
        let liveImports = Set(liveBodies.flatMap(Self.swiftImports(in:)))
        let expectedInfrastructureImports: Set<String> = [
            "PrimoDocumentEngineInfrastructure",
            "PrimoDocumentMetalRuntimeInfrastructure",
            "PrimoDocumentMetalStrokeInfrastructure",
            "PrimoDocumentRenderingInfrastructure",
            "PrimoDocumentStrokeInfrastructure"
        ]
        #expect(liveImports.contains("PrimoDocumentRuntime"))
        #expect(
            expectedInfrastructureImports.isSubset(of: liveImports),
            "PrimoDocumentRuntimeLive should be the module that imports concrete infrastructure"
        )

        let graph = try Self.packageTargetGraph()
        let liveDependencies = try #require(graph["PrimoDocumentRuntimeLive"])
        #expect(liveDependencies.contains("PrimoDocumentRuntime"))
        for dependency in expectedInfrastructureImports {
            #expect(
                liveDependencies.contains(dependency),
                "PrimoDocumentRuntimeLive should own the live dependency on \(dependency)"
            )
        }

        let publicLiveSymbols = Set(Self.publicTopLevelSymbols(in: liveBody))
        #expect(publicLiveSymbols.contains("DocumentApplicationRuntimeFactory"))
        #expect(publicLiveSymbols.contains("DocumentRuntimeFactory"))
        #expect(publicLiveSymbols.contains("DocumentProjectPreviewLoader"))
        #expect(publicLiveSymbols.contains("TimelapseExportService"))
        #expect(liveBody.contains("package enum DocumentRuntimeLiveCompositionFactory"))
        #expect(liveBody.contains("PrimoDocumentEngineInfrastructure.DocumentEngineRuntimeCompositionFactory.live("))
        #expect(liveBody.contains("PrimoDocumentEngineInfrastructure.DocumentProjectPreviewLoader.loadPreview("))
        #expect(liveBody.contains("PrimoDocumentEngineInfrastructure.TimelapseExportService.exportVideo("))
        #expect(liveBody.contains("package init(gpuOperations: DocumentGpuOperationGateway)"))
        #expect(liveBody.contains("DocumentRuntimeLiveCompositionFactory.live("))
    }

    @Test
    func nonDocumentRuntimeFacadesKeepInfrastructureOutOfPublicSurface() throws {
        let repoRoot = try Self.repoRoot()
        let runtimeSources = [
            "Packages/PrimoModules/Sources/PrimoAIImageRuntime/AIImageRuntimeFacade.swift",
            "Packages/PrimoModules/Sources/PrimoWorkspaceRuntime/WorkspaceRuntimeFacade.swift",
            "Packages/PrimoModules/Sources/PrimoBrushRuntime/BrushRuntimeFacade.swift"
        ]
        let leakedImplementationTokens = [
            "PrimoAIImageInfrastructure",
            "PrimoBrushInfrastructure",
            "PrimoWorkspaceInfrastructure",
            "PrimoDocumentRuntimeLive"
        ]

        for relativePath in runtimeSources {
            let body = try String(
                contentsOf: repoRoot.appendingPathComponent(relativePath, isDirectory: false),
                encoding: .utf8
            )
            #expect(Self.exportedImports(in: body).isEmpty, "\(relativePath) should not re-export implementation modules")
            #expect(Self.publicTopLevelTypealiases(in: body).isEmpty, "\(relativePath) should not publish typealiases to implementation types")

            let publicSurface = Self.callables(accessLevel: "public", in: body).map(\.signature) +
                Self.storedProperties(accessLevel: "public", in: body).compactMap(\.type)
            for token in leakedImplementationTokens {
                #expect(
                    publicSurface.allSatisfy { !$0.contains(token) },
                    "\(relativePath) public signatures and stored properties should not expose \(token)"
                )
            }
        }
    }

    @Test
    func nonDocumentRuntimeFacadesOwnTheirLiveWiringBoundaries() throws {
        let repoRoot = try Self.repoRoot()
        let graph = try Self.packageTargetGraph()
        let runtimeExpectations = [
            (
                target: "PrimoAIImageRuntime",
                sourcePath: "Packages/PrimoModules/Sources/PrimoAIImageRuntime/AIImageRuntimeFacade.swift",
                expectedDependencies: Set(["PrimoAIImageApplication", "PrimoAIImageInfrastructure"]),
                allowedImplementationImports: Set(["PrimoAIImageInfrastructure"]),
                liveTokens: [
                    "AIImageRuntimeFactory.settingsClient(",
                    "AIImageRuntimeFactory.commerceClient(",
                    "AIImageRuntimeFactory.remoteEditClient("
                ]
            ),
            (
                target: "PrimoWorkspaceRuntime",
                sourcePath: "Packages/PrimoModules/Sources/PrimoWorkspaceRuntime/WorkspaceRuntimeFacade.swift",
                expectedDependencies: Set(["PrimoWorkspaceApplication", "PrimoWorkspaceInfrastructure", "PrimoDocumentRuntime", "PrimoDocumentRuntimeLive"]),
                allowedImplementationImports: Set(["PrimoWorkspaceInfrastructure", "PrimoDocumentRuntimeLive"]),
                liveTokens: [
                    "DocumentWorkspaceClient.infrastructureLive(",
                    "DocumentImportClient.infrastructureLive(",
                    "DocumentProjectPreviewLoader.loadPreview(",
                    "WorkspaceApplicationServices("
                ]
            ),
            (
                target: "PrimoBrushRuntime",
                sourcePath: "Packages/PrimoModules/Sources/PrimoBrushRuntime/BrushRuntimeFacade.swift",
                expectedDependencies: Set(["PrimoBrushRuntimeContracts", "PrimoBrushInfrastructure", "PrimoBrushFileFormats"]),
                allowedImplementationImports: Set(["PrimoBrushInfrastructure", "PrimoBrushFileFormats"]),
                liveTokens: [
                    "PrimoBrushInfrastructure.BrushTipLibraryClient.live(",
                    "PrimoBrushInfrastructure.TextFontLibraryClient.live(",
                    "PrimoBrushInfrastructure.BrushImportService.live("
                ]
            )
        ]
        let allImplementationModules: Set<String> = [
            "PrimoAIImageInfrastructure",
            "PrimoBrushInfrastructure",
            "PrimoBrushFileFormats",
            "PrimoDocumentRuntimeLive",
            "PrimoWorkspaceInfrastructure"
        ]

        for expectation in runtimeExpectations {
            let dependencies = try #require(graph[expectation.target])
            for dependency in expectation.expectedDependencies {
                #expect(
                    dependencies.contains(dependency),
                    "\(expectation.target) should own the live boundary dependency on \(dependency)"
                )
            }
            #expect(
                dependencies.intersection(allImplementationModules).isSubset(of: expectation.allowedImplementationImports),
                "\(expectation.target) should not reach unrelated implementation modules"
            )

            let body = try String(
                contentsOf: repoRoot.appendingPathComponent(expectation.sourcePath, isDirectory: false),
                encoding: .utf8
            )
            let imports = Self.swiftImports(in: body)
            #expect(
                imports.intersection(allImplementationModules) == expectation.allowedImplementationImports,
                "\(expectation.sourcePath) should make its implementation imports explicit and local"
            )
            let semanticBody = Self.swiftCodeWithCommentsAndStringsBlanked(in: body)
            for token in expectation.liveTokens {
                #expect(semanticBody.contains(token), "\(expectation.sourcePath) should own live wiring token \(token)")
            }
        }
    }

    @Test
    func appUsesAIWorkspaceAndBrushRuntimeFacadesInsteadOfConcreteInfrastructure() throws {
        let repoRoot = try Self.repoRoot()
        let appRoot = repoRoot.appendingPathComponent("App", isDirectory: true)
        let appSources = try Self.swiftSources(under: appRoot)
        let appBodies = try appSources.map { try String(contentsOf: $0, encoding: .utf8) }
        let appImports = Set(appBodies.flatMap(Self.swiftImports(in:)))
        let requiredRuntimeFacades: Set<String> = [
            "PrimoAIImageRuntime",
            "PrimoBrushRuntime",
            "PrimoWorkspaceRuntime"
        ]
        let bannedImplementationImports: Set<String> = [
            "PrimoAIImageInfrastructure",
            "PrimoBrushInfrastructure",
            "PrimoWorkspaceInfrastructure",
            "PrimoDocumentRuntimeLive"
        ]

        #expect(
            requiredRuntimeFacades.isSubset(of: appImports),
            "App should import non-document runtime facades for live AI image, workspace, and brush dependencies"
        )
        #expect(
            appImports.isDisjoint(with: bannedImplementationImports),
            "App should not import concrete AI image, workspace, brush, or document live infrastructure"
        )

        let requiredRuntimeCallSites = [
            (
                path: "App/Features/Document/AIImageDependencies.swift",
                imports: Set(["PrimoAIImageRuntime"]),
                tokens: [
                    "AIImageSettingsClient.live(",
                    "AIImageCommerceClient.live(",
                    "AIImageRemoteEditClient.live("
                ]
            ),
            (
                path: "App/Features/Document/DocumentWorkspaceClient.swift",
                imports: Set(["PrimoWorkspaceRuntime"]),
                tokens: [
                    "static var liveValue: DocumentWorkspaceClient",
                    "return .live("
                ]
            ),
            (
                path: "App/Support/DocumentImportClient.swift",
                imports: Set(["PrimoWorkspaceRuntime"]),
                tokens: [
                    "static var liveValue: DocumentImportClient",
                    "return .live("
                ]
            ),
            (
                path: "App/Support/BrushTipFile.swift",
                imports: Set(["PrimoBrushRuntime"]),
                tokens: [
                    "PrimoBrushRuntime.BrushTipLibraryClient.live("
                ]
            ),
            (
                path: "App/Support/BrushImportClient.swift",
                imports: Set(["PrimoBrushRuntime"]),
                tokens: [
                    "PrimoBrushRuntime.BrushImportService.live("
                ]
            )
        ]
        for callSite in requiredRuntimeCallSites {
            let body = try String(
                contentsOf: repoRoot.appendingPathComponent(callSite.path, isDirectory: false),
                encoding: .utf8
            )
            let imports = Self.swiftImports(in: body)
            #expect(callSite.imports.isSubset(of: imports), "\(callSite.path) should import its runtime facade")
            for token in callSite.tokens {
                #expect(body.contains(token), "\(callSite.path) should route live dependency construction through \(token)")
            }
        }
    }

    @Test
    func publicGpuPreviewAdaptersRequireInjectedOperations() throws {
        let repoRoot = try Self.repoRoot()
        let checkedFiles = [
            (
                path: "Packages/PrimoModules/Sources/PrimoDocumentRenderingInfrastructure/GpuCanvasPresentationServices.swift",
                accessLevel: "public"
            ),
            (
                path: "Packages/PrimoModules/Sources/PrimoDocumentRuntimeLive/GpuPreviewAdapters.swift",
                accessLevel: "package"
            ),
            (
                path: "Packages/PrimoModules/Sources/PrimoDocumentRuntimeLive/GpuCanvasPreviewRendererAdapter.swift",
                accessLevel: "package"
            )
        ]
        let adapterNames = [
            "GpuCanvasPreviewRenderer",
            "GpuLayerTransformProcessor"
        ]
        var checkedAdapterCount = 0

        for file in checkedFiles {
            let source = try String(
                contentsOf: repoRoot.appendingPathComponent(file.path, isDirectory: false),
                encoding: .utf8
            )
            for adapterName in adapterNames {
                guard let body = Self.declarationBody(named: adapterName, in: source) else { continue }
                checkedAdapterCount += 1
                let injectedInitializers = Self.initializerDeclarations(accessLevel: file.accessLevel, in: body)
                    .map(Self.normalizedSignature)
                #expect(!injectedInitializers.isEmpty, "\(file.path) should expose explicit injection initializers for \(adapterName)")
                #expect(
                    injectedInitializers.allSatisfy { signature in
                        signature != "\(file.accessLevel) init()" &&
                            !signature.contains(" = ") &&
                            !signature.contains("DocumentGpuOperationGatewayFactory.live")
                    },
                    "\(file.path) should require explicit GPU operation dependencies for \(adapterName)"
                )
                let publicInitializers = Self.initializerDeclarations(accessLevel: "public", in: body)
                    .map(Self.normalizedSignature)
                #expect(!publicInitializers.contains("public init()"), "\(file.path) should not expose a public default initializer for \(adapterName)")
            }
        }
        #expect(checkedAdapterCount == 4, "GPU preview adapter guard should cover infrastructure and RuntimeLive adapters")
    }

    @Test
    func documentRuntimeFacadeHasTypedEntrypointsWithoutRawRenderingCompatibilityShims() throws {
        let repoRoot = try Self.repoRoot()
        let facade = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentRuntime/DocumentRuntimeFacade.swift",
            isDirectory: false
        )
        let body = try String(contentsOf: facade, encoding: .utf8)
        let renderingWorkflowBody = try #require(Self.typeBody(named: "DocumentRenderingWorkflow", in: body))
        let publicCallables = Self.callables(accessLevel: "public", in: body)
        let signatures = Set(publicCallables.map(\.signature).map(Self.normalizedSignature))

        let typedSignatures: Set<String> = [
            "public func createCanvas(_ size: ValidCanvasSize)",
            "public func resizeCanvas(_ size: ValidCanvasSize)",
            "public func resizeCanvasExtent(_ size: ValidCanvasSize)",
            "public func compositedPaperPreviewRGBA( _ surface: RgbaSurface, _ paperStyle: CanvasPaperStyle )",
            "public func compositedPreviewPixelData( _ snapshot: MetalDocumentSnapshot, activeLayerIndex: ExistingLayerIndex, adjustedActiveLayerPixels: RgbaSurface )",
            "public func processedLayerPixelData( _ source: RgbaSurface, _ request: LayerProcessingRequest )",
            "public func alphaMask(_ surface: RgbaSurface)",
            "public func croppedSelectionMask(_ mask: MaskSurface)",
            "public func scaledPixelData(_ source: RgbaSurface, targetGeometry: PixelGeometry)",
            "public func translatedPixelData( _ source: RgbaSurface, targetGeometry: PixelGeometry, offsetX: Int, offsetY: Int )",
            "public func createFolder(named name: String, afterLayerAt anchorLayerIndex: LayerAnchorIndex)",
            "public func deleteFolder(_ folderID: ExistingFolderID)",
            "public func deleteLayer(_ index: ExistingLayerIndex)",
            "public func setLayerOpacity(_ index: ExistingLayerIndex, opacity: UnitInterval)",
            "public func setFolderVisibility(_ folderID: ExistingFolderID, visible: Bool)",
            "public func replaceLayerMask(_ index: EditableLayerIndex, mask: LayerMaskData)",
            "public func replaceLayerPixelsInRect(_ index: EditableLayerIndex, _ rect: LayerPixelRect, _ pixelData: LayerPixelData)",
            "public func applyGpuStrokeSurface(_ samples: [StylusSample], _ brush: BrushRuntimeSettings, layerIndex: EditableLayerIndex)",
            "public func blurStroke(_ samples: [StylusSample], _ brush: BrushRuntimeSettings, layerIndex: EditableLayerIndex, clearSelectionAfterBlur: Bool)",
            "public func textLayerData(_ index: ExistingLayerIndex)",
            "public func setTextLayer(_ index: EditableLayerIndex, _ textLayer: TextLayerData)",
            "public func clearTextLayerData(_ index: EditableLayerIndex)",
            "public func transformedLayerPixels( source: RgbaSurface, selection: CanvasSelection?, translation: CGSize, scaleX: CGFloat, scaleY: CGFloat, rotationDegrees: Double, pivot: CGPoint?, mode: CanvasTransformMode, quadOffsets: TransformQuadOffsets )",
            "public func transformedSelection( _ selection: CanvasSelection?, translation: CGSize, scaleX: CGFloat, scaleY: CGFloat, rotationDegrees: Double, pivot: CGPoint?, mode: CanvasTransformMode, quadOffsets: TransformQuadOffsets, canvasGeometry: PixelGeometry )",
            "public func transformationBounds(selection: CanvasSelection?, surface: RgbaSurface)",
            "public func combinedSelection(existing: CanvasSelection?, incoming: CanvasSelection?, mode: SelectionCombineMode, canvasGeometry: PixelGeometry)",
            "public func makeRectangleSelection(from startPoint: CGPoint, to endPoint: CGPoint, canvasGeometry: PixelGeometry)",
            "public func expandedMask(from selection: CanvasSelection, canvasGeometry: PixelGeometry)",
            "public func adjustedSelection(_ selection: CanvasSelection?, canvasGeometry: PixelGeometry, expansion: Int, isInverted: Bool)",
            "public func invertedSelection(_ selection: CanvasSelection?, canvasGeometry: PixelGeometry, mode: SelectionToolMode)",
            "public func featheredSelection(_ selection: CanvasSelection?, canvasGeometry: PixelGeometry, radius: Int)",
            "public func makeLassoSelection(from points: [CGPoint], canvasGeometry: PixelGeometry)",
            "public func makeAutoSelection(at point: CGPoint, snapshot: MetalDocumentSnapshot?, layerIndex: ExistingLayerIndex, thresholdMode: FillThresholdMode, opacityTolerance: Double, colorTolerance: Double, expansion: Int)",
            "public func makeColorRangeSelection(request: ColorRangeSelectionRequest, snapshot: MetalDocumentSnapshot?, activeLayerIndex: ExistingLayerIndex, mode: SelectionToolMode)",
            "public func expandedSelectionMask(_ source: MaskSurface, expansion: Int)",
            "public func contractedSelectionMask(_ source: MaskSurface, contraction: Int)",
            "public func featheredSelectionMask(_ source: MaskSurface, radius: Int)",
            "public func invertedSelectionMask(_ source: MaskSurface)",
            "public func croppedSelection(from source: MaskSurface, mode: SelectionToolMode)",
            "public func eyedropperLoupeSurface( source: RgbaSurface, centerX: Int, centerY: Int, gridSize: Int, paperStyle: CanvasPaperStyle, blendWithPaper: Bool )",
            "public func paperCompositeSurface(_ surface: RgbaSurface, paperStyle: CanvasPaperStyle)",
            "public func shapePreviewSurface(stroke: Stroke, style: PreviewStrokeStyle, canvasGeometry: PixelGeometry)",
            "public func transformedTextPreviewSurface(textLayer: TextLayerData, canvasGeometry: PixelGeometry)",
            "public func sampledColor( snapshot: MetalDocumentSnapshot, activeLayerIndex: ExistingLayerIndex, source: EyedropperSamplingSource, point: CGPoint, paperStyle: CanvasPaperStyle )",
            "public func selectionOverlaySurface(_ mask: MaskSurface)"
        ]
        for signature in typedSignatures {
            #expect(signatures.contains(signature), "Missing typed public facade overload: \(signature)")
        }

        let removedRawSurfaceFunctionNames: Set<String> = [
            "compositedPaperPreviewRGBA",
            "compositedPreviewPixelData",
            "processedLayerPixelData",
            "alphaMask",
            "croppedSelectionMask",
            "scaledPixelData",
            "translatedPixelData",
            "transformedLayerPixels",
            "transformationBounds",
            "expandedMask",
            "expandedSelectionMask",
            "contractedSelectionMask",
            "featheredSelectionMask",
            "croppedSelection",
            "eyedropperLoupeSurface",
            "paperCompositeSurface",
            "shapePreviewSurface",
            "transformedTextPreviewSurface",
            "selectionOverlaySurface"
        ]
        let publicRawSurfaceFunctions = publicCallables.filter { callable in
            callable.kind == "func" &&
                removedRawSurfaceFunctionNames.contains(callable.name) &&
                callable.hasParameter(named: "width", type: "Int") &&
                callable.hasParameter(named: "height", type: "Int")
        }
        #expect(
            publicRawSurfaceFunctions.isEmpty,
            "Public raw Data + width + height rendering APIs should be removed once typed RgbaSurface/MaskSurface overloads exist: \(publicRawSurfaceFunctions.map(\.signature))"
        )
        #expect(
            !publicCallables.contains {
                $0.name == "compositedPreviewPixelData" &&
                    $0.hasParameter(named: "activeLayerIndex", type: "Int") &&
                    $0.hasParameter(named: "adjustedActiveLayerPixels", type: "Data")
            },
            "Public composited preview rendering should accept ExistingLayerIndex and RgbaSurface instead of raw Int/Data"
        )
        #expect(
            !renderingWorkflowBody.contains("(MetalDocumentSnapshot, Int, Data) -> DocumentRenderingResult<Data>"),
            "DocumentRenderingWorkflow should store typed composited preview handlers and bridge raw rendering operations at construction"
        )
        let rasterSelectionFunctionNames: Set<String> = [
            "combinedSelection",
            "makeRectangleSelection",
            "adjustedSelection",
            "invertedSelection",
            "featheredSelection",
            "makeLassoSelection",
            "closedPolygon",
            "transformedSelection"
        ]
        let publicSelectionCGSizeFunctions = publicCallables.filter { callable in
            callable.kind == "func" &&
                rasterSelectionFunctionNames.contains(callable.name) &&
                callable.hasParameter(named: "canvasSize", type: "CGSize")
        }
        #expect(
            publicSelectionCGSizeFunctions.isEmpty,
            "Public raster selection APIs should accept PixelGeometry instead of presentation CGSize: \(publicSelectionCGSizeFunctions.map(\.signature))"
        )
        #expect(
            renderingWorkflowBody.contains("(MetalDocumentSnapshot, ExistingLayerIndex, RgbaSurface) -> DocumentRenderingResult<Data>"),
            "DocumentRenderingWorkflow composited preview handler should accept ExistingLayerIndex and RgbaSurface"
        )
        #expect(
            !publicCallables.contains { $0.name == "makeColorRangeSelection" && $0.hasParameter(named: "activeLayerIndex", type: "Int") },
            "Public color-range selection should accept ExistingLayerIndex instead of raw Int"
        )
        #expect(
            !publicCallables.contains { $0.name == "sampledColor" && $0.hasParameter(named: "activeLayerIndex", type: "Int") },
            "Public eyedropper sampling should accept ExistingLayerIndex instead of raw Int"
        )
        #expect(
            !publicCallables.contains { $0.name == "shapePreviewSurface" && $0.hasParameter(named: "canvasWidth", type: "Int") },
            "Public shape preview should accept PixelGeometry instead of raw canvas dimensions"
        )
        #expect(
            !publicCallables.contains { $0.name == "transformedTextPreviewSurface" && $0.hasParameter(named: "canvasWidth", type: "Int") },
            "Public text preview should accept PixelGeometry instead of raw canvas dimensions"
        )

        let textLayerServiceBody = try #require(Self.typeBody(named: "DocumentTextLayerService", in: body))
        let publicTextLayerCallables = Self.callables(accessLevel: "public", in: textLayerServiceBody)
        #expect(!publicTextLayerCallables.contains { $0.hasParameter(named: "index", type: "Int") })
        let publicTextLayerInitializers = Self.initializerSignatures(accessLevel: "public", in: textLayerServiceBody)
        #expect(
            publicTextLayerInitializers.allSatisfy { !$0.contains("Int") },
            "DocumentTextLayerService public initializer should accept typed layer index closures"
        )
    }

    @Test
    func documentRuntimePublicMutationFacadeRejectsRawLayerIndexesAndPixelPayloads() throws {
        let repoRoot = try Self.repoRoot()
        let facade = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentRuntime/DocumentRuntimeFacade.swift",
            isDirectory: false
        )
        let body = try String(contentsOf: facade, encoding: .utf8)
        let layerEditingBody = try #require(Self.typeBody(named: "LayerEditingRuntime", in: body))
        let strokeEditingBody = try #require(Self.typeBody(named: "StrokeEditingRuntime", in: body))
        let layerCommandBody = try #require(Self.typeBody(named: "DocumentLayerCommand", in: body))

        for typedCase in [
            "case mergeExistingLayerDown(ExistingLayerIndex)",
            "case setEditableTextLayer(index: EditableLayerIndex, TextLayerData)",
            "case applyEditableProcessing(index: EditableLayerIndex, LayerProcessingRequest)"
        ] {
            #expect(layerCommandBody.contains(typedCase), "DocumentLayerCommand should preserve typed public case \(typedCase)")
        }
        for rawCase in [
            "case edit(DocumentEditingRequest)",
            "case mergeLayerDown(Int)",
            "case setTextLayer(index: Int, TextLayerData)",
            "case applyProcessing(index: Int, LayerProcessingRequest)"
        ] {
            #expect(!layerCommandBody.contains(rawCase), "DocumentLayerCommand should not expose raw layer index case \(rawCase)")
        }

        let layerMutationPrefixes = [
            "public func createFolder(",
            "public func deleteFolder(",
            "public func deleteLayer(",
            "public func duplicateLayer(",
            "public func moveLayer(",
            "public func assignLayer(",
            "public func mergeLayerDown(",
            "public func setLayer",
            "public func setFolder",
            "public func replaceLayerPixels(",
            "public func applyLayerProcessing(",
            "public func setTextLayer(",
            "public func clearLayer(",
            "public func replaceLayerMask(",
            "public func clearLayerMask(",
            "public func applyLayerMask(",
            "public func revealLayerForEditing(",
            "public func ensureLayerVisible(",
            "public func applyLayerSurfaceMutation(",
            "public func applyLayerMutation(",
            "public func applyTextLayerMutation("
        ]
        let bannedRawIndexParameterNames: Set<String> = [
            "index",
            "layerIndex",
            "activeLayerIndex",
            "destinationIndex",
            "folderID"
        ]
        let bannedRawPayloadParameterNames: Set<String> = [
            "pixelData",
            "maskData"
        ]

        for callable in Self.callables(accessLevel: "public", in: layerEditingBody)
            where layerMutationPrefixes.contains(where: callable.signature.hasPrefix)
        {
            let rawIndexParameter = callable.parameters.first { parameter in
                bannedRawIndexParameterNames.contains(parameter.semanticName) && parameter.type == "Int"
            }
            #expect(rawIndexParameter == nil, "\(callable.signature) should use typed layer/folder value objects")
            let rawPayloadParameter = callable.parameters.first { parameter in
                bannedRawPayloadParameterNames.contains(parameter.semanticName) && parameter.type == "Data"
            }
            #expect(rawPayloadParameter == nil, "\(callable.signature) should use typed layer pixel/mask payloads")
        }

        for callable in Self.callables(accessLevel: "public", in: strokeEditingBody)
            where callable.signature.hasPrefix("public func applyGpuStrokeSurface(") || callable.signature.hasPrefix("public func blurStroke(")
        {
            #expect(!callable.hasParameter(named: "layerIndex", type: "Int"))
            #expect(callable.hasParameter(named: "layerIndex", type: "EditableLayerIndex"))
        }

        let removedPackageRawLayerSignatures = [
            "package func deleteLayer(_ index: Int)",
            "package func mergeLayerDown(_ index: Int)",
            "package func replaceLayerPixels(_ index: Int, pixelData: Data)",
            "package func replaceLayerPixels(_ index: Int, _ pixelData: Data)",
            "package func applyLayerProcessing(_ index: Int, request: LayerProcessingRequest)",
            "package func setTextLayer(_ index: Int, textLayer: TextLayerData)"
        ]
        let packageLayerSignatures = Set(
            Self.callables(accessLevel: "package", in: layerEditingBody)
                .map(\.signature)
                .map(Self.normalizedSignature)
        )
        for signature in removedPackageRawLayerSignatures {
            #expect(
                !packageLayerSignatures.contains(signature),
                "\(signature) should be removed instead of kept as a deprecated raw compatibility shim"
            )
        }

        let removedPackageRawStrokeSignatures = [
            "package func applyGpuStrokeSurface(_ samples: [StylusSample], _ brush: BrushRuntimeSettings, _ layerIndex: Int)",
            "package func blurStroke(_ samples: [StylusSample], _ brush: BrushRuntimeSettings, _ layerIndex: Int, _ clearSelectionAfterBlur: Bool)"
        ]
        let packageStrokeSignatures = Set(
            Self.callables(accessLevel: "package", in: strokeEditingBody)
                .map(\.signature)
                .map(Self.normalizedSignature)
        )
        for signature in removedPackageRawStrokeSignatures {
            #expect(
                !packageStrokeSignatures.contains(signature),
                "\(signature) should be removed instead of kept as a deprecated raw compatibility shim"
            )
        }
    }

    @Test
    func residualPackageRawLayerAPIBaselineDoesNotGrow() throws {
        let repoRoot = try Self.repoRoot()
        let facadeBody = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentRuntime/DocumentRuntimeFacade.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let workflowBody = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentApplication/DocumentMutationWorkflow.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )

        let layerEditingBody = try #require(Self.typeBody(named: "LayerEditingRuntime", in: facadeBody))
        let textLayerServiceBody = try #require(Self.typeBody(named: "DocumentTextLayerService", in: facadeBody))
        let mutationWorkflowBody = try #require(Self.typeBody(named: "DocumentMutationWorkflowService", in: workflowBody))

        let layerEditingRawPackage = Set(Self.rawLayerPackageCallableSignatures(in: layerEditingBody))
        let expectedLayerEditingRawPackage: Set<String> = []
        #expect(
            layerEditingRawPackage == expectedLayerEditingRawPackage,
            "LayerEditingRuntime raw package API baseline changed. Remove or rename raw shims intentionally; do not add new ones. Actual: \(layerEditingRawPackage.sorted())"
        )

        let textLayerRawPackage = Set(Self.rawLayerPackageCallableSignatures(in: textLayerServiceBody))
        let expectedTextLayerRawPackage: Set<String> = []
        #expect(
            textLayerRawPackage == expectedTextLayerRawPackage,
            "DocumentTextLayerService raw package API baseline changed. Actual: \(textLayerRawPackage.sorted())"
        )

        let workflowRawPackage = Set(Self.rawLayerPackageCallableSignatures(in: mutationWorkflowBody))
        let expectedWorkflowRawPackage: Set<String> = []
        #expect(
            workflowRawPackage == expectedWorkflowRawPackage,
            "DocumentMutationWorkflowService raw package API should stay removed. Actual: \(workflowRawPackage.sorted())"
        )
    }

    @Test
    func documentDTOsExposeInvariantValueObjects() throws {
        let repoRoot = try Self.repoRoot()
        let valueObjects = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentDomain/DocumentValueObjects.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let paperStyle = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentDomain/WorkspaceDocumentTypes.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let textLayer = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentDomain/TextLayerTypes.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let presentation = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentPresentationContracts/DocumentPresentationModels.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let persistence = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentPersistenceInfrastructure/PaintDocumentPersistenceService.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )

        for symbol in ["UnitInterval", "PositiveFiniteDouble", "FiniteDouble", "TextContent", "CanvasColor"] {
            #expect(valueObjects.contains("public struct \(symbol)"), "Document DTO value object \(symbol) should exist")
        }
        #expect(paperStyle.contains("public let color: CanvasColor"))
        #expect(paperStyle.contains("public init(color: CanvasColor, isTransparent: Bool)"))
        #expect(paperStyle.contains("public var validatedColor: CanvasColor?"))
        #expect(textLayer.contains("public let textContent: TextContent"))
        #expect(textLayer.contains("public let fontSizeValue: PositiveFiniteDouble"))
        #expect(textLayer.contains("public let scaleValue: PositiveFiniteDouble"))
        #expect(textLayer.contains("public let color: CanvasColor"))
        #expect(textLayer.contains("public let rotationDegreesValue: FiniteDouble"))
        #expect(textLayer.contains("public var validatedFontSize: PositiveFiniteDouble?"))
        #expect(textLayer.contains("public var validatedColor: CanvasColor?"))
        #expect(!textLayer.contains("set {\n            guard let content = TextContent"), "TextLayerData text should not silently ignore invalid public mutation")
        #expect(!textLayer.contains("public var fontSize: Double {\n        get"), "TextLayerData should expose raw scalars as read-only projections")
        #expect(presentation.contains("public let geometry: PixelGeometry"))
        #expect(presentation.contains("public let layerPresentation: ValidatedLayerPresentation"))
        #expect(presentation.contains("public var validatedOpacity: UnitInterval?"))
        #expect(presentation.contains("validatingCanvasSize canvasSize: CGSize"))
        #expect(!presentation.contains("public init(\n        canvasSize: CGSize"), "PaintDocumentPresentation raw initializer should not be public")
        #expect(!persistence.contains("isUnitInterval("), "Persistence validation should use DTO value objects instead of ad hoc unit interval checks")
        #expect(persistence.contains("textLayer.validatedColor"))
        #expect(persistence.contains("UnitInterval(layer.opacity)"))
    }

    @Test
    func runtimeCompositionStoresNarrowGpuCapabilities() throws {
        let repoRoot = try Self.repoRoot()
        let compositionFiles = [
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineRuntimeComposition.swift",
            "Packages/PrimoModules/Sources/PrimoDocumentRuntime/DocumentRuntimeFacade.swift"
        ]

        for file in compositionFiles {
            let url = repoRoot.appendingPathComponent(file, isDirectory: false)
            let body = try String(contentsOf: url, encoding: .utf8)

            #expect(!body.contains("package let gpuOperationGateway"), "\(file) should not store the broad GPU gateway")
            #expect(body.contains("canvasPreviewOperations"), "\(file) should store preview GPU capability explicitly")
            #expect(body.contains("selectionMaskOperations"), "\(file) should store selection-mask GPU capability explicitly")
            #expect(body.contains("layerTransformOperations"), "\(file) should store layer-transform GPU capability explicitly")
            #expect(body.contains("surfaceHandleReleaser"), "\(file) should keep resource release as a separate capability")
        }
    }

    @Test
    func noDuplicateCompositionTypeNamesAcrossRuntimeAndInfrastructure() throws {
        let repoRoot = try Self.repoRoot()
        let sourceRoots = [
            "PrimoDocumentRuntime": repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentRuntime",
                isDirectory: true
            ),
            "PrimoDocumentEngineInfrastructure": repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure",
                isDirectory: true
            )
        ]

        var declarationsByName: [String: [String]] = [:]
        for (targetName, sourceRoot) in sourceRoots {
            for source in try Self.swiftSources(under: sourceRoot) {
                let body = try String(contentsOf: source, encoding: .utf8)
                let relativePath = source.path
                    .replacingOccurrences(of: repoRoot.path + "/", with: "")
                for declaration in ArchitectureSourceInspector(source: body).topLevelDeclarations
                    where declaration.name.contains("Composition") {
                    declarationsByName[declaration.name, default: []].append("\(targetName):\(relativePath)")
                }
            }
        }

        let duplicates = declarationsByName
            .filter { _, locations in Set(locations.map(Self.targetName(in:))).count > 1 }
            .map { name, locations in "\(name): \(locations.sorted().joined(separator: ", "))" }
            .sorted()

        #expect(
            duplicates.isEmpty,
            "Composition type names must stay unique across PrimoDocumentRuntime and PrimoDocumentEngineInfrastructure: \(duplicates.joined(separator: "; "))"
        )
        #expect(declarationsByName["DocumentRuntimeComposition"]?.count == 1)
        #expect(declarationsByName["DocumentEngineRuntimeComposition"]?.count == 1)
    }

    @Test
    func appStrokeWorkflowUsesPreviewLeaseInsteadOfMetalHandles() throws {
        let repoRoot = try Self.repoRoot()
        let appStrokeFiles = [
            "App/Features/Document/CanvasEditingWorkflowReducer+StrokeWorkflow.swift",
            "App/Features/Document/DocumentFeature+CanvasToolStateCoordinator.swift"
        ]

        for file in appStrokeFiles {
            let url = repoRoot.appendingPathComponent(file, isDirectory: false)
            let body = try String(contentsOf: url, encoding: .utf8)

            #expect(!body.contains("MetalBufferHandle"), "\(file) should not pass rendering resource handles through App workflow")
            #expect(!body.contains("releaseSurfaceHandle"), "\(file) should release preview resources through lease abstractions")
            #expect(!body.contains("SurfaceHandleReleasing"), "\(file) should not depend on rendering-resource release capability")
            #expect(body.contains("StrokePreviewLease"), "\(file) should use the App-facing preview lease abstraction")
        }
    }

    @Test
    func appWorkflowsDependOnCapabilitySplitRuntimeFacades() throws {
        let repoRoot = try Self.repoRoot()
        let strokeWorkflowFiles = [
            "App/Features/Document/CanvasEditingWorkflowReducer.swift",
            "App/Features/Document/LayerWorkflowReducer.swift",
            "App/Features/Document/PaintDocumentClient.swift"
        ]

        for file in strokeWorkflowFiles {
            let url = repoRoot.appendingPathComponent(file, isDirectory: false)
            let body = try String(contentsOf: url, encoding: .utf8)

            #expect(!body.contains("CanvasStrokeRuntime"), "\(file) should depend on StrokeEditingRuntime or narrow stroke protocols")
        }

        let layerWorkflowFiles = [
            "App/Features/Document/LayerWorkflowReducer.swift",
            "App/Features/Document/AIImageWorkflowReducer.swift",
            "App/Features/Document/AdjustmentWorkflowReducer.swift"
        ]

        for file in layerWorkflowFiles {
            let url = repoRoot.appendingPathComponent(file, isDirectory: false)
            let body = try String(contentsOf: url, encoding: .utf8)

            #expect(!body.contains("documentMutationWorkflowService: LayerEditingRuntime"), "\(file) should expose narrow layer mutation workflow access")
            #expect(!body.contains("documentContentService: LayerEditingRuntime"), "\(file) should expose narrow layer content workflow access")
            #expect(!body.contains("selectionWorkflowService: LayerEditingRuntime"), "\(file) should expose narrow selection workflow access")
        }
    }

    @Test
    func appDocumentDependenciesAreAggregatedThroughRuntimeEnvironment() throws {
        let repoRoot = try Self.repoRoot()
        let dependencyComposition = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "App/Features/Document/DocumentDependencyKeys.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let applicationEnvironment = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "App/Features/Document/DocumentApplicationEnvironment.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let capabilityAccess = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "App/Features/Document/DocumentRuntimeCapabilities.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let adapters = try Self.documentRuntimeAdapterSources(repoRoot: repoRoot)
        let validation = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "App/Features/Document/DocumentWorkflowValidation.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let body = [dependencyComposition, applicationEnvironment, capabilityAccess, adapters, validation].joined(separator: "\n")
        let paintDocumentClient = repoRoot.appendingPathComponent(
            "App/Features/Document/PaintDocumentClient.swift",
            isDirectory: false
        )
        let paintDocumentClientBody = try String(contentsOf: paintDocumentClient, encoding: .utf8)
        let bannedKeys = [
            "DocumentCanvasCommandServiceKey",
            "DocumentLayerCommandServiceKey",
            "DocumentStrokeCommandServiceKey",
            "DocumentHistoryCommandServiceKey",
            "DocumentMutationWorkflowServiceKey",
            "DocumentContentServiceKey",
            "SelectionWorkflowServiceKey",
            "DocumentPresentationReaderKey",
            "DocumentPersistenceGatewayKey",
            "DocumentExportGatewayKey",
            "DocumentRenderingWorkflowKey"
        ]

        #expect(body.contains("struct DocumentApplicationEnvironment: Sendable"))
        #expect(body.contains("struct PresentationEnvironment: Sendable"))
        #expect(body.contains("struct CanvasEditingEnvironment: Sendable"))
        #expect(body.contains("struct LayerWorkflowEnvironment: Sendable"))
        #expect(body.contains("struct PersistenceEnvironment: Sendable"))
        let applicationEnvironmentBody = try #require(Self.typeBody(named: "DocumentApplicationEnvironment", in: applicationEnvironment))
        #expect(applicationEnvironmentBody.contains("let presentationEnvironment: PresentationEnvironment"))
        #expect(applicationEnvironmentBody.contains("let canvasEditingEnvironment: CanvasEditingEnvironment"))
        #expect(applicationEnvironmentBody.contains("let layerWorkflowEnvironment: LayerWorkflowEnvironment"))
        #expect(applicationEnvironmentBody.contains("let persistenceEnvironment: PersistenceEnvironment"))
        for directCapability in [
            "let strokePreviewPort",
            "let strokeCommitPort",
            "let layerVisibilityPort",
            "let layerContentPort",
            "let selectionProcessingPort",
            "let canvasTransformPort",
            "let canvasEditingPresentationPort",
            "let paperStylePort",
            "let exportCapability",
            "let persistenceCapability",
            "let previewRenderingCapability"
        ] {
            #expect(!applicationEnvironmentBody.contains(directCapability), "DocumentApplicationEnvironment should store feature environments instead of \(directCapability)")
        }
        #expect(body.contains("protocol SelectionWorkflowRequesting: Sendable"))
        #expect(body.contains("protocol StrokePreviewPort"))
        #expect(body.contains("protocol CanvasEditingPresentationPort"))
        #expect(!body.contains("typealias CanvasStrokeWorkflowAccess"))
        #expect(body.contains("private enum DocumentApplicationEnvironmentKey: DependencyKey"))
        #expect(validation.contains("struct DocumentWorkflowCommandValidator: Sendable"))
        #expect(!paintDocumentClientBody.contains("struct DocumentWorkflowCommandValidator"))
        #expect(!paintDocumentClientBody.contains("private enum DocumentApplicationEnvironmentKey"))
        #expect(validation.contains("preflight / fast feedback"))
        #expect(validation.contains("DocumentEditingState"))
        #expect(!validation.contains("authoritative"))
        for key in bannedKeys {
            #expect(!body.contains(key), "PaintDocumentClient should derive \(key) from DocumentApplicationEnvironment")
        }
    }

    @Test
    func canvasEditingReducerUsesNarrowPortsInsteadOfBroadWorkflowAccess() throws {
        let repoRoot = try Self.repoRoot()
        let capabilities = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "App/Features/Document/DocumentRuntimeCapabilities.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let reducer = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "App/Features/Document/CanvasEditingWorkflowReducer.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let strokeWorkflow = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "App/Features/Document/CanvasEditingWorkflowReducer+StrokeWorkflow.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let workflowObjects = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "App/Features/Document/CanvasEditingWorkflowReducer+WorkflowObjects.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let transformWorkflow = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "App/Features/Document/CanvasEditingWorkflowReducer+TransformWorkflow.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let dependencies = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "App/Features/Document/DocumentDependencyKeys.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let environment = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "App/Features/Document/DocumentApplicationEnvironment.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let adapters = try Self.documentRuntimeAdapterSources(repoRoot: repoRoot)

        for port in [
            "protocol StrokePreviewPort",
            "protocol StrokeCommitPort",
            "protocol LayerVisibilityPort",
            "protocol LayerContentPort",
            "protocol SelectionProcessingPort",
            "protocol CanvasTransformPort",
            "protocol CanvasEditingPresentationPort",
            "protocol PaperStylePort"
        ] {
            #expect(capabilities.contains(port), "Missing narrow canvas editing port \(port)")
        }
        #expect(!capabilities.contains("CanvasStrokeWorkflowAccess"))
        #expect(!adapters.contains("DocumentCanvasEditingAccess"))
        #expect(!environment.contains("DocumentCanvasEditingAccess"))
        #expect(!reducer.contains("canvasStrokeWorkflowAccess"))
        #expect(!dependencies.contains("canvasStrokeWorkflowAccess"))

        for dependency in [
            "@Dependency(\\.strokePreviewPort)",
            "@Dependency(\\.strokeCommitPort)",
            "@Dependency(\\.layerVisibilityPort)",
            "@Dependency(\\.layerContentPort)",
            "@Dependency(\\.selectionProcessingPort)",
            "@Dependency(\\.canvasTransformPort)",
            "@Dependency(\\.canvasEditingPresentationPort)",
            "@Dependency(\\.paperStylePort)"
        ] {
            #expect(reducer.contains(dependency), "Canvas editing reducer should inject \(dependency)")
        }
        for workflow in [
            "struct CanvasStrokeWorkflow",
            "struct CanvasSelectionWorkflow",
            "struct CanvasTransformWorkflow",
            "struct CanvasPaperSyncWorkflow"
        ] {
            #expect(workflowObjects.contains(workflow), "Canvas editing workflow routing should be split into \(workflow)")
        }
        #expect(reducer.contains("strokeWorkflow.reduce(state: &state, action: action)"))
        #expect(reducer.contains("selectionWorkflow.reduce(state: &state, action: action)"))
        #expect(workflowObjects.contains(".run { [paperStylePort] _ in"))
        #expect(transformWorkflow.contains("handlePreviewLayerMoveWithTransform"))
        #expect(transformWorkflow.contains("handleApplyLayerMoveWithTransform"))
        #expect(!strokeWorkflow.contains(".run { [canvasStrokeWorkflowAccess]"))

        let adapterExpectations: [(String, String, [String])] = [
            ("DocumentStrokePreviewAdapter", "StrokeEditingRuntime", ["LayerEditingRuntime", "DocumentPresentationRuntime", "DocumentPersistenceRuntime"]),
            ("DocumentStrokeCommitAdapter", "StrokeEditingRuntime", ["LayerEditingRuntime", "DocumentPresentationRuntime", "DocumentPersistenceRuntime"]),
            ("DocumentLayerVisibilityAdapter", "LayerStructureEditingRuntime", ["StrokeEditingRuntime", "LayerEditingRuntime", "DocumentPresentationRuntime", "DocumentPersistenceRuntime"]),
            ("DocumentLayerContentAdapter", "LayerContentEditingRuntime", ["StrokeEditingRuntime", "LayerEditingRuntime", "DocumentPresentationRuntime", "DocumentPersistenceRuntime"]),
            ("DocumentSelectionProcessingAdapter", "LayerSelectionEditingRuntime", ["StrokeEditingRuntime", "LayerEditingRuntime", "DocumentPresentationRuntime", "DocumentPersistenceRuntime"]),
            ("DocumentCanvasTransformAdapter", "LayerTransformEditingRuntime", ["StrokeEditingRuntime", "LayerEditingRuntime", "DocumentPresentationRuntime", "DocumentPersistenceRuntime"]),
            ("DocumentCanvasEditingPresentationAdapter", "DocumentPresentationRuntime", ["StrokeEditingRuntime", "LayerEditingRuntime", "DocumentPersistenceRuntime"]),
            ("DocumentPaperStyleAdapter", "DocumentPersistenceRuntime", ["StrokeEditingRuntime", "LayerEditingRuntime", "DocumentPresentationRuntime"])
        ]
        for (adapterName, requiredRuntime, bannedRuntimes) in adapterExpectations {
            let body = try #require(Self.typeBody(named: adapterName, in: adapters))
            #expect(body.contains(requiredRuntime), "\(adapterName) should hold only its required runtime")
            for bannedRuntime in bannedRuntimes {
                #expect(!body.contains(bannedRuntime), "\(adapterName) should not hold \(bannedRuntime)")
            }
        }
        #expect(environment.contains("DocumentStrokePreviewAdapter(runtime: runtime.strokeEditing)"))
        #expect(environment.contains("DocumentStrokeCommitAdapter(runtime: runtime.strokeEditing)"))
        #expect(environment.contains("DocumentLayerVisibilityAdapter(runtime: runtime.layerEditing.structure)"))
        #expect(environment.contains("DocumentLayerContentAdapter(runtime: runtime.layerEditing.content)"))
        #expect(environment.contains("DocumentSelectionProcessingAdapter(runtime: runtime.layerEditing.selection)"))
        #expect(environment.contains("canvasEditingRuntime: runtime.layerEditing.canvasEditing"))
        #expect(environment.contains("transformRuntime: runtime.layerEditing.transform"))
        #expect(environment.contains("DocumentCanvasEditingPresentationAdapter(runtime: runtime.presentation)"))
        #expect(environment.contains("DocumentPaperStyleAdapter(runtime: runtime.persistence)"))
    }

    @Test
    func documentReducersUseRuntimeCapabilitiesInsteadOfRawServices() throws {
        let repoRoot = try Self.repoRoot()
        let reducerSources = [
            "App/Features/Document/WorkspaceFeature.swift",
            "App/Features/Document/PresentationRefreshReducer.swift",
            "App/Features/Document/DocumentLifecycleReducer.swift",
            "App/Features/Document/CanvasEditingWorkflowReducer.swift",
            "App/Features/Document/LayerWorkflowReducer.swift",
            "App/Features/Document/AdjustmentWorkflowReducer.swift",
            "App/Features/Document/AIImageWorkflowReducer.swift",
            "App/Features/Document/ImportExportFeature.swift"
        ]
        let bannedDependencyKeys = [
            "documentRuntime",
            "documentPresentationReader",
            "documentPersistenceGateway",
            "documentExportGateway",
            "documentRenderingWorkflow",
            "documentCanvasCommandService",
            "documentLayerCommandService",
            "documentStrokeCommandService",
            "documentHistoryCommandService",
            "documentMutationWorkflowService",
            "documentContentService",
            "documentTextLayerService",
            "canvasStrokeInteractionService",
            "canvasEditingWorkflowService",
            "layerTransformProcessor",
            "selectionWorkflowService",
            "selectionWorkflowEnvironment"
        ]

        for sourcePath in reducerSources {
            let source = repoRoot.appendingPathComponent(sourcePath, isDirectory: false)
            let body = try String(contentsOf: source, encoding: .utf8)
            for key in bannedDependencyKeys {
                #expect(
                    !Self.dependencyKeys(in: body).contains(key),
                    "\(sourcePath) should depend on document runtime capabilities instead of \\.\(key)"
                )
            }
        }
    }

    @Test
    func appReducersDoNotDependOnRawFileOrWorkspaceClients() throws {
        let repoRoot = try Self.repoRoot()
        let featureSources = [
            "App/Features/Document/ApplicationFeature.swift",
            "App/Features/Document/WorkspaceFeature.swift",
            "App/Features/Document/DocumentFeature.swift",
            "App/Features/Document/ImportExportFeature.swift"
        ]

        for sourcePath in featureSources {
            let source = repoRoot.appendingPathComponent(sourcePath, isDirectory: false)
            let body = try String(contentsOf: source, encoding: .utf8)
            #expect(
                !Self.dependencyKeys(in: body).contains("fileClient"),
                "\(sourcePath) should use narrow capabilities instead of raw FileClient"
            )
            #expect(
                !Self.dependencyKeys(in: body).contains("documentWorkspaceClient"),
                "\(sourcePath) should use narrow workspace capabilities instead of DocumentWorkspaceClient"
            )
        }

        let dependencyProvider = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "App/Features/Document/DocumentWorkspaceClient.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        #expect(dependencyProvider.contains("struct WorkspaceApplicationCapability: Sendable"))
        #expect(dependencyProvider.contains("struct WorkspaceArtifactCapability: Sendable"))
        #expect(dependencyProvider.contains("struct TimelapseExportCapability: Sendable"))
    }

    @Test
    func appDoesNotUseRawDocumentGatewayDependencies() throws {
        let repoRoot = try Self.repoRoot()
        let appRoot = repoRoot.appendingPathComponent("App", isDirectory: true)
        let banned = [
            "documentGpuOperationGateway",
            "documentQueryGateway",
            "textLayerGateway",
            "DocumentGpuOperationGateway",
            "DocumentQueryGateway",
            "TextLayerGateway",
            "DocumentMutationGateway"
        ]

        for source in try Self.swiftSources(under: appRoot) {
            let body = try String(contentsOf: source, encoding: .utf8)
            for token in banned {
                #expect(!body.contains(token), "\(source.path) should depend on runtime/application facades instead of \(token)")
            }
        }
    }

    @Test
    func strokeSessionStateDoesNotExposePublicMutableCoreState() throws {
        let repoRoot = try Self.repoRoot()
        let strokeState = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentStrokeApplication/StrokeSessionState.swift",
            isDirectory: false
        )
        let strokeUseCases = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentStrokeApplication/DocumentStrokeApplication.swift",
            isDirectory: false
        )
        let stateBody = try String(contentsOf: strokeState, encoding: .utf8)
        let useCaseBody = try String(contentsOf: strokeUseCases, encoding: .utf8)

        let bannedStateFields = [
            "public var baseSnapshot",
            "public var renderState",
            "public var pendingIncrementalUpdate",
            "public var committedPointCount"
        ]
        for field in bannedStateFields {
            #expect(!stateBody.contains(field), "StrokeSessionState should mutate \(field) only through explicit methods")
        }

        let bannedUseCaseFields = [
            "public var planner",
            "public var renderer"
        ]
        for field in bannedUseCaseFields {
            #expect(!useCaseBody.contains(field), "Stroke use cases should not expose \(field) as mutable public state")
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
    func documentRuntimeContractsStaysUmbrellaOnly() throws {
        let repoRoot = try Self.repoRoot()
        let runtimeContracts = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentContracts/DocumentRuntimeContracts.swift",
            isDirectory: false
        )
        let body = try String(contentsOf: runtimeContracts, encoding: .utf8)
        let lineCount = body.split(separator: "\n", omittingEmptySubsequences: false).count
        let banned = [
            "struct BrushRuntimeSettings",
            "struct DocumentGpuOperationGateway",
            "struct DocumentMutationGateway",
            "struct DocumentPersistenceGateway",
            "struct DocumentExportGateway",
            "struct CanvasSelection",
            "enum LayerProcessingRequest",
            "struct TimelapseCapture"
        ]

        #expect(lineCount < 100, "DocumentRuntimeContracts.swift should stay a thin compatibility umbrella")
        #expect(Self.exportedImports(in: body).isEmpty, "DocumentRuntimeContracts.swift should not hide dependency boundaries through re-exported imports")
        for token in banned {
            #expect(!body.contains(token), "Runtime contract type \(token) should live in a narrow contract target")
        }
    }

    @Test
    func layerProcessingTransformRequestUsesTypedValueObjectsAtPublicBoundary() throws {
        let repoRoot = try Self.repoRoot()
        let mutationContracts = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentMutationContracts/DocumentMutationRuntimeContracts.swift",
            isDirectory: false
        )
        let body = try String(contentsOf: mutationContracts, encoding: .utf8)
        let processingRequest = try #require(Self.typeBody(named: "LayerProcessingRequest", in: body))
        let transformRequest = try #require(Self.typeBody(named: "LayerTransformProcessingRequest", in: body))

        #expect(processingRequest.contains("case transform(LayerTransformProcessingRequest)"))
        #expect(!processingRequest.contains("case transform(translation: CGSize"))
        #expect(transformRequest.contains("public let translation: FiniteTranslation"))
        #expect(transformRequest.contains("public let scale: TransformScale"))
        #expect(transformRequest.contains("public let rotationDegrees: RotationDegrees"))
        #expect(!transformRequest.contains("public let translation: CGSize"))
        #expect(!transformRequest.contains("public let scale: CGFloat"))
        #expect(!transformRequest.contains("public let rotationDegrees: Double"))
    }

    @Test
    func appContractImportsStayExplicit() throws {
        let repoRoot = try Self.repoRoot()
        let appExportFiles = [
            "App/Support/PrimoModuleExports.swift",
            "App/Support/PrimoAIImageModules.swift"
        ]
        for file in appExportFiles {
            let url = repoRoot.appendingPathComponent(file, isDirectory: false)
            let body = try String(contentsOf: url, encoding: .utf8)

            #expect(
                Self.exportedImports(in: body).isEmpty,
                "App files should import narrow Primo modules explicitly instead of relying on App-wide re-exports"
            )
        }
    }

    @Test
    func layerMutationGatewaysRequireValidatedIdentifiers() throws {
        let repoRoot = try Self.repoRoot()
        let contracts = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentApplication/DocumentLayerMutationContracts.swift",
            isDirectory: false
        )
        let body = try String(contentsOf: contracts, encoding: .utf8)
        let contentContracts = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentApplication/DocumentLayerContentMutationContracts.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let structureGateway = try #require(Self.declarationBody(named: "LayerStructureGateway", in: body))
        let attributeGateway = try #require(Self.declarationBody(named: "LayerAttributeGateway", in: body))
        let contentGateway = try #require(Self.declarationBody(named: "LayerContentGateway", in: contentContracts))
        let layerAnchorIndex = try #require(Self.typeBody(named: "LayerAnchorIndex", in: body))

        let structureSignatures = Set(Self.functionSignatures(in: structureGateway))
        let attributeSignatures = Set(Self.functionSignatures(in: attributeGateway))
        let contentSignatures = Set(Self.functionSignatures(in: contentGateway))
        let expectedStructureSignatures: Set<String> = [
            "func addLayerAndSelect(name: String)",
            "func duplicateLayer(index: ExistingLayerIndex, name: String)",
            "func deleteLayer(index: ExistingLayerIndex)",
            "func moveLayer(from index: ExistingLayerIndex, to destinationIndex: ExistingLayerIndex)",
            "func createFolder(name: String, anchorLayerIndex: LayerAnchorIndex)",
            "func deleteFolder(id folderID: ExistingFolderID)",
            "func assignLayer(index: ExistingLayerIndex, toFolder folderID: ExistingFolderID?)"
        ]
        let expectedAttributeSignatures: Set<String> = [
            "func setActiveLayerIndex(_ index: ExistingLayerIndex)",
            "func setLayerName(_ name: String, index: ExistingLayerIndex)",
            "func setLayerVisible(_ isVisible: Bool, index: ExistingLayerIndex)",
            "func setLayerLocked(_ isLocked: Bool, index: ExistingLayerIndex)",
            "func setLayerAlphaLocked(_ isAlphaLocked: Bool, index: ExistingLayerIndex)",
            "func setLayerClipped(_ isClipped: Bool, index: ExistingLayerIndex)",
            "func setLayerOpacity(_ opacity: ValidatedLayerOpacity, index: ExistingLayerIndex)",
            "func setLayerBlendMode(_ blendMode: LayerBlendMode, index: ExistingLayerIndex)",
            "func setFolderExpanded(_ isExpanded: Bool, folderID: ExistingFolderID)",
            "func setFolderVisible(_ isVisible: Bool, folderID: ExistingFolderID)",
            "func setFolderName(_ name: String, folderID: ExistingFolderID)"
        ]
        let expectedContentSignatures: Set<String> = [
            "func replaceLayerPixels(index: EditableLayerIndex, pixelData: LayerPixelData)",
            "func setTextLayer(index: EditableLayerIndex, textLayer: TextLayerData)",
            "func clearLayer(index: EditableLayerIndex)",
            "func applyLayerProcessing(index: EditableLayerIndex, request: ValidatedLayerProcessingRequest)",
            "func replaceLayerMask(index: EditableLayerIndex, mask: LayerMaskData)",
            "func clearLayerMask(index: EditableLayerIndex)",
            "func applyLayerMask(index: EditableLayerIndex)"
        ]

        #expect(structureSignatures == expectedStructureSignatures)
        #expect(attributeSignatures == expectedAttributeSignatures)
        #expect(contentSignatures == expectedContentSignatures)
        #expect(layerAnchorIndex.contains("public let rawValue: Int?"))
        #expect(layerAnchorIndex.contains("public let revision: DocumentRevision"))
        let gatewayCallables = [
            structureGateway,
            attributeGateway,
            contentGateway
        ].flatMap { Self.callables(in: $0) }
        for callable in gatewayCallables {
            let rawLayerParameter = callable.parameters.first { parameter in
                parameter.semanticName == "index" && parameter.type == "Int"
            }
            #expect(rawLayerParameter == nil, "Layer mutation gateways should accept validated layer indexes: \(callable.signature)")
            let rawFolderParameter = callable.parameters.first { parameter in
                parameter.semanticName == "folderID" && parameter.type == "Int"
            }
            #expect(rawFolderParameter == nil, "Layer mutation gateways should accept validated folder identifiers: \(callable.signature)")
            let rawOpacityParameter = callable.parameters.first { parameter in
                parameter.semanticName == "opacity" && parameter.type == "Double"
            }
            #expect(rawOpacityParameter == nil, "Layer mutation gateways should accept validated opacity: \(callable.signature)")
        }
        #expect(!body.contains("rawValueOrSentinel"), "LayerAnchorIndex should not expose a public sentinel conversion")
    }

    @Test
    func appWorkflowValidationReturnsEditableLayerCapability() throws {
        let repoRoot = try Self.repoRoot()
        let mutationContracts = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentMutationContracts/DocumentMutationRuntimeContracts.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let validation = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "App/Features/Document/DocumentWorkflowValidation.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let adapters = try Self.documentRuntimeAdapterSources(repoRoot: repoRoot)

        #expect(mutationContracts.contains("public struct EditableLayerIndex"))
        let editableLayerIndex = try #require(Self.declarationBody(named: "EditableLayerIndex", in: mutationContracts))
        #expect(
            Self.initializerSignatures(accessLevel: "public", in: editableLayerIndex).isEmpty,
            "EditableLayerIndex should not be publicly constructible outside validation code"
        )
        #expect(
            Self.initializerSignatures(accessLevel: "package", in: editableLayerIndex)
                .contains(where: { $0.contains("validating rawValue: Int") }),
            "EditableLayerIndex validating construction should stay package-scoped"
        )
        #expect(
            !Self.functionSignatures(accessLevel: "public", in: editableLayerIndex)
                .contains(where: { $0.hasPrefix("public static func validated(") }),
            "EditableLayerIndex validating construction should not be public minting authority"
        )
        #expect(
            Self.functionSignatures(accessLevel: "package", in: editableLayerIndex)
                .contains(where: { $0.hasPrefix("package static func validated(") }),
            "EditableLayerIndex validating construction should stay package-scoped"
        )
        #expect(Self.storedPropertyNames(accessLevel: "public", in: editableLayerIndex) == ["rawValue", "revision"])
        #expect(Self.initializerSignatures(accessLevel: "package", in: editableLayerIndex).contains("package init(_ rawValue: Int)"))
        let layerEditAuthorization = try #require(Self.declarationBody(named: "LayerEditAuthorization", in: validation))
        let validatedCommand = try #require(Self.declarationBody(named: "ValidatedDocumentLayerMutationCommand", in: validation))
        #expect(layerEditAuthorization.contains("let existingLayerIndex: ExistingLayerIndex"))
        #expect(layerEditAuthorization.contains("let editableLayerIndex: EditableLayerIndex"))
        #expect(layerEditAuthorization.contains("existingLayerIndex.rawValue == editableLayerIndex.rawValue"))
        #expect(layerEditAuthorization.contains("existingLayerIndex.revision == editableLayerIndex.revision"))
        #expect(validatedCommand.contains("let layer: LayerEditAuthorization"))
        #expect(!validatedCommand.contains("let existingLayerIndex: ExistingLayerIndex"))
        #expect(!validatedCommand.contains("let layerIndex: EditableLayerIndex"))
        #expect(!validation.contains("let layerIndex: Int"))
        #expect(adapters.contains("layerIndex: command.layer.editableLayerIndex"))
        #expect(adapters.contains("command.existingLayerIndex"))
    }

    @Test
    func runtimeValidationIsDocumentedAsAuthoritativeRevisionAwareContract() throws {
        let repoRoot = try Self.repoRoot()
        let read: (String) throws -> String = { relativePath in
            try String(
                contentsOf: repoRoot.appendingPathComponent(relativePath, isDirectory: false),
                encoding: .utf8
            )
        }
        let layerContracts = try read("Packages/PrimoModules/Sources/PrimoDocumentApplication/DocumentLayerMutationContracts.swift")
        let contentContracts = try read("Packages/PrimoModules/Sources/PrimoDocumentApplication/DocumentLayerContentMutationContracts.swift")
        let editorUseCase = try read("Packages/PrimoModules/Sources/PrimoDocumentApplication/DocumentEditorUseCase.swift")
        let editingGateway = try read("Packages/PrimoModules/Sources/PrimoDocumentApplication/DocumentEditingGateway.swift")
        let engineLive = try read("Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift")
        let readme = try read("README.md")

        #expect(layerContracts.contains("authoritative contract boundary"))
        #expect(layerContracts.contains("validated indexes carry the document revision"))
        #expect(layerContracts.contains("public struct ExistingLayerIndex"))
        #expect(layerContracts.contains("public let revision: DocumentRevision"))
        #expect(contentContracts.contains("same authoritative validation path as structure"))
        #expect(contentContracts.contains("revision-aware EditableLayerIndex"))
        #expect(editorUseCase.contains("authoritative application contract"))
        #expect(editorUseCase.contains("fresh mutation context"))
        #expect(engineLive.contains("Authoritative stale validation"))
        #expect(engineLive.contains("private func validateFreshLayerIndex(_ index: ExistingLayerIndex)"))
        #expect(engineLive.contains("private func validateFreshLayerIndex(_ index: EditableLayerIndex)"))
        #expect(layerContracts.contains("package enum LayerStructureCommand"))
        #expect(layerContracts.contains("package enum LayerAttributeCommand"))
        #expect(contentContracts.contains("package enum LayerContentMutationCommand"))
        #expect(editorUseCase.contains("package enum DocumentEditorRequest"))
        #expect(editingGateway.contains("package typealias DocumentEditingRequest"))
        #expect(!layerContracts.contains("public enum LayerStructureCommand"))
        #expect(!layerContracts.contains("public enum LayerAttributeCommand"))
        #expect(!contentContracts.contains("public enum LayerContentMutationCommand"))
        #expect(readme.contains("App validation は preflight、runtime validation は本契約"))
        #expect(readme.contains("authoritative validation"))
    }

    @Test
    func runtimeLayerMutationGatewayKeepsTypedFolderBoundaries() throws {
        let repoRoot = try Self.repoRoot()
        let engineLive = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        #expect(engineLive.contains("@Sendable (String, LayerAnchorIndex) -> DocumentCreatedFolderMutationResult"))
        #expect(engineLive.contains("@Sendable (Int, String) -> DocumentCreatedLayerMutationResult"))
        #expect(engineLive.contains("@Sendable (ExistingLayerIndex, ExistingFolderID?) -> DocumentMutationResult"))

        let runtimeComposition = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineRuntimeComposition.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        for token in [
            "anchorLayerIndex.rawValueOrSentinel",
            "folderID?.rawValue ?? -1",
            "runtime.assignLayerToFolder(index.rawValue"
        ] {
            #expect(!runtimeComposition.contains(token), "Runtime composition should keep folder mutation identifiers typed instead of \(token)")
        }
    }

    @Test
    func documentReadGatewayStaysPureFromRenderAndDirtyUpdateEffects() throws {
        let repoRoot = try Self.repoRoot()
        let contracts = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentRenderingContracts/DocumentRenderingRuntimeContracts.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let readGateway = try #require(Self.declarationBody(named: "DocumentReadGateway", in: contracts))
        let publicReadFunctions = Set(Self.functionSignatures(accessLevel: "public", in: readGateway))
        #expect(publicReadFunctions.isEmpty, "DocumentReadGateway should expose presentation reads through gateway methods, not public raw fields")
        let readGatewayStorage = Set(Self.storedPropertyNames(accessLevel: "package", in: readGateway))
        #expect(readGatewayStorage == ["lightweightPresentation", "presentation"])
        #expect(contracts.contains("public struct DocumentRenderGateway"))
        #expect(contracts.contains("public struct DocumentDirtyUpdateQueue"))

        let composition = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineRuntimeComposition.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        #expect(composition.contains("package let queryGateway: DocumentQueryGateway"))
        #expect(composition.contains("package let renderGateway: DocumentRenderGateway"))
        #expect(composition.contains("package let dirtyUpdateQueue: DocumentDirtyUpdateQueue"))
        #expect(!composition.contains("public let queryGateway: DocumentQueryGateway"))
        #expect(!composition.contains("public let renderGateway: DocumentRenderGateway"))
        #expect(!composition.contains("public let dirtyUpdateQueue: DocumentDirtyUpdateQueue"))
    }

    @Test
    func rawDocumentGatewaysDoNotExposePublicClosureFields() throws {
        let repoRoot = try Self.repoRoot()
        let renderingContracts = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentRenderingContracts/DocumentRenderingRuntimeContracts.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let mutationContracts = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentMutationContracts/DocumentMutationRuntimeContracts.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )

        let rawGatewayExpectations: [(name: String, source: String, packageFields: Set<String>)] = [
            (
                "DocumentReadGateway",
                renderingContracts,
                ["lightweightPresentation", "presentation"]
            ),
            (
                "DocumentRenderGateway",
                renderingContracts,
                ["compositePixelData", "compositeSurface", "pixelDataForLayer"]
            ),
            (
                "DocumentDirtyUpdateQueue",
                renderingContracts,
                ["consumeDirtyUpdate"]
            ),
            (
                "DocumentGpuOperationGateway",
                renderingContracts,
                [
                    "compositedPreviewPixelData",
                    "compositedPreviewIncrementalUpdate",
                    "shapePreviewSurface",
                    "textLayerSurface",
                    "textLayoutRect",
                    "selectionOverlayRGBA",
                    "eyedropperLoupeRGBA",
                    "processedLayerPixelData",
                    "alphaMask",
                    "croppedSelectionMask",
                    "expandedSelectionMask",
                    "combinedSelectionMask",
                    "invertMask",
                    "expandedMask",
                    "contractedMask",
                    "featheredMask",
                    "transformedSelectionMask",
                    "transformedLayerPixelData",
                    "translatedPixelData",
                    "scaledPixelData",
                    "lassoSelection",
                    "colorRangeSelection",
                    "autoSelection",
                    "compositedPaperPreviewRGBA",
                    "releaseSurfaceHandle"
                ]
            ),
            (
                "DocumentCanvasPreviewRenderingOperations",
                renderingContracts,
                [
                    "compositedPreviewPixelData",
                    "shapePreviewSurface",
                    "textLayerSurface",
                    "textLayoutRect",
                    "selectionOverlayRGBA",
                    "eyedropperLoupeRGBA",
                    "compositedPaperPreviewRGBA"
                ]
            ),
            (
                "DocumentSelectionMaskOperations",
                renderingContracts,
                [
                    "croppedSelectionMask",
                    "expandedSelectionMask",
                    "combinedSelectionMask",
                    "invertMask",
                    "expandedMask",
                    "contractedMask",
                    "featheredMask",
                    "transformedSelectionMask",
                    "lassoSelection",
                    "colorRangeSelection",
                    "autoSelection",
                    "alphaMask"
                ]
            ),
            (
                "DocumentLayerTransformOperations",
                renderingContracts,
                ["transformedLayerPixelData"]
            ),
            (
                "DocumentRenderingOperations",
                renderingContracts,
                [
                    "compositedPreviewPixelData",
                    "processedLayerPixelData",
                    "alphaMask",
                    "croppedSelectionMask",
                    "translatedPixelData",
                    "scaledPixelData",
                    "compositedPaperPreviewRGBA"
                ]
            ),
            (
                "StrokeInputGateway",
                mutationContracts,
                ["beginStroke", "appendStroke", "endStroke", "cancelStroke", "blurStroke", "endBlurStroke", "cancelBlurStroke", "fill", "applyGpuStrokeSurface"]
            ),
            (
                "DocumentHistoryGateway",
                mutationContracts,
                ["canUndo", "canRedo", "undo", "redo", "trimForMemoryPressure"]
            ),
            (
                "TextLayerGateway",
                mutationContracts,
                ["textLayerData", "setTextLayer", "clearTextLayerData"]
            ),
            (
                "DocumentLayerEffectsGateway",
                mutationContracts,
                []
            )
        ]

        for expectation in rawGatewayExpectations {
            let body = try #require(Self.declarationBody(named: expectation.name, in: expectation.source))
            #expect(
                Self.storedPropertyNames(accessLevel: "public", in: body).isEmpty,
                "\(expectation.name) raw closure storage should not be public API"
            )
            #expect(
                Set(Self.storedPropertyNames(accessLevel: "package", in: body)) == expectation.packageFields,
                "\(expectation.name) raw closure storage should stay package-scoped and explicit"
            )
        }

        let gpuGatewayBody = try #require(Self.declarationBody(named: "DocumentGpuOperationGateway", in: renderingContracts))
        let surfaceReleaserBody = try #require(Self.declarationBody(named: "DocumentSurfaceHandleReleaser", in: renderingContracts))
        #expect(!gpuGatewayBody.contains("public init("), "DocumentGpuOperationGateway should not publicly accept raw GPU function tables")
        #expect(!surfaceReleaserBody.contains("public init(releaseSurfaceHandle"), "Raw surface-handle release authority should be constructed inside the package")
        #expect(Self.functionSignatures(accessLevel: "public", in: surfaceReleaserBody).contains("public func releaseSurfaceLease(_ lease: StrokePreviewLease)"))
        #expect(renderingContracts.contains("public protocol SurfaceHandleReleasing"))
    }

    @Test
    func rawMutationGatewayAuthorityStaysInLiveCompositionAndFocusedTests() throws {
        let repoRoot = try Self.repoRoot()
        let roots = [
            repoRoot.appendingPathComponent("Packages/PrimoModules/Sources", isDirectory: true),
            repoRoot.appendingPathComponent("Packages/PrimoModules/Tests", isDirectory: true),
            repoRoot.appendingPathComponent("App", isDirectory: true),
            repoRoot.appendingPathComponent("PrimoTests", isDirectory: true),
        ].filter { FileManager.default.fileExists(atPath: $0.path) }
        let allowedGatewayConstructionFiles: Set<String> = [
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift",
            "Packages/PrimoModules/Tests/PrimoDocumentApplicationTests/DocumentContentServiceTests.swift",
            "Packages/PrimoModules/Tests/PrimoDocumentApplicationTests/DocumentInteractionServiceTests.swift",
            "Packages/PrimoModules/Tests/PrimoDocumentApplicationTests/DocumentMutationWorkflowServiceTests.swift",
        ]
        let allowedMutationGatewayUseFiles: Set<String> = [
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineRuntimeComposition.swift",
            "Packages/PrimoModules/Tests/PrimoDocumentEngineInfrastructureTests/DocumentProjectPreviewLoaderTests.swift",
            "Packages/PrimoModules/Tests/PrimoDocumentEngineInfrastructureTests/PaintDocumentMutationContractTests.swift",
            "Packages/PrimoModules/Tests/PrimoDocumentEngineInfrastructureTests/SwiftDocumentRuntimeUndoTests.swift",
        ]

        for root in roots {
            for source in try Self.swiftSources(under: root) {
                let relativePath = source.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
                let body = Self.swiftCodeWithCommentsAndStringsBlanked(
                    in: try String(contentsOf: source, encoding: .utf8)
                )
                if body.contains("DocumentMutationGateway(") {
                    #expect(
                        allowedGatewayConstructionFiles.contains(relativePath),
                        "\(relativePath) should not construct raw DocumentMutationGateway authority"
                    )
                }
                if body.contains(".mutationGateway.") {
                    #expect(
                        allowedMutationGatewayUseFiles.contains(relativePath),
                        "\(relativePath) should not bypass typed application/runtime mutation facades"
                    )
                }
            }
        }
    }

    @Test
    func adjustmentSettingsStoreValidatedValueObjectsInsteadOfRawPublicDoubles() throws {
        let repoRoot = try Self.repoRoot()
        let mutationContracts = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentMutationContracts/DocumentMutationRuntimeContracts.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let contentViewMenus = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "App/Application/ContentView+Menus.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )

        for typeName in [
            "HueSaturationBrightnessSettings",
            "BrightnessContrastSettings",
            "LevelsAdjustmentSettings",
            "ToneCurveSettings",
            "ColorBalanceSettings",
            "ThresholdSettings",
            "PosterizeSettings"
        ] {
            let body = try #require(Self.typeBody(named: typeName, in: mutationContracts))
            let storedProperties = Set(Self.storedPropertyNames(accessLevel: "public", in: body))
            let rawScalarStorage = storedProperties.intersection([
                "hueDegrees",
                "saturation",
                "brightness",
                "contrast",
                "inputBlack",
                "inputWhite",
                "gamma",
                "outputBlack",
                "outputWhite",
                "shadows",
                "midtones",
                "highlights",
                "redCyan",
                "greenMagenta",
                "blueYellow",
                "threshold",
                "levels",
                "position"
            ])
            #expect(rawScalarStorage.isEmpty, "\(typeName) should expose raw scalars as read-only computed projections")
        }
        #expect(mutationContracts.contains("public struct HueAdjustmentDegrees"))
        #expect(mutationContracts.contains("public struct AdjustmentScale"))
        #expect(mutationContracts.contains("public struct AdjustmentOffset"))
        #expect(mutationContracts.contains("public struct ThresholdValue"))
        #expect(mutationContracts.contains("public struct PosterizeLevels"))
        #expect(mutationContracts.contains("public typealias PosterizeLevelCount = PosterizeLevels"))
        #expect(mutationContracts.contains("public struct GradientStopPosition"))
        #expect(mutationContracts.contains("public let gammaValue: PositiveFiniteDouble"))
        #expect(mutationContracts.contains("public let thresholdValue: ThresholdValue"))
        #expect(mutationContracts.contains("public let levelsValue: PosterizeLevels"))
        #expect(mutationContracts.contains("public let positionValue: GradientStopPosition"))
        let gradientStopBody = try #require(Self.typeBody(named: "GradientMapStopSettings", in: mutationContracts))
        let gradientStopStorage = Set(Self.storedPropertyNames(accessLevel: "public", in: gradientStopBody))
        #expect(gradientStopStorage == ["id", "positionValue", "colorValue"])
        #expect(!gradientStopStorage.contains("red"))
        #expect(!gradientStopStorage.contains("green"))
        #expect(!gradientStopStorage.contains("blue"))
        #expect(Self.computedPropertyNames(accessLevel: "public", in: gradientStopBody).isSuperset(of: ["position", "red", "green", "blue"]))
        #expect(!contentViewMenus.contains("stop.wrappedValue.red ="))
        #expect(!contentViewMenus.contains("stop.wrappedValue.green ="))
        #expect(!contentViewMenus.contains("stop.wrappedValue.blue ="))
    }

    @Test
    func layerContentPayloadsAreValueObjectsInsteadOfDataAliases() throws {
        let repoRoot = try Self.repoRoot()
        let contentContracts = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentApplication/DocumentLayerContentMutationContracts.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )

        let inspector = ArchitectureSourceInspector(source: contentContracts)
        let publicTypealiases = inspector.typealiases.filter { $0.accessLevel == "public" }
        #expect(!publicTypealiases.contains(.init(name: "LayerPixelData", accessLevel: "public", assignedType: "Data")))
        #expect(!publicTypealiases.contains(.init(name: "LayerMaskData", accessLevel: "public", assignedType: "Data")))
        #expect(inspector.topLevelDeclarations.contains(.init(
            name: "LayerPixelReplacementCommand",
            kind: "struct",
            accessLevel: "public"
        )))
        let pixelData = try #require(Self.declarationBody(named: "LayerPixelData", in: contentContracts))
        let maskData = try #require(Self.declarationBody(named: "LayerMaskData", in: contentContracts))
        let replacementCommand = try #require(Self.declarationBody(named: "LayerPixelReplacementCommand", in: contentContracts))
        #expect(Set(Self.storedPropertyNames(accessLevel: "public", in: pixelData)) == ["width", "height", "rgba"])
        #expect(Set(Self.storedPropertyNames(accessLevel: "public", in: maskData)) == ["width", "height", "bytes"])
        #expect(Set(Self.storedPropertyNames(accessLevel: "public", in: replacementCommand)) == ["index", "pixelData"])
        #expect(Self.initializerSignatures(accessLevel: "public", in: pixelData).contains("public init?(width: Int, height: Int, rgba: Data)"))
        #expect(Self.initializerSignatures(accessLevel: "public", in: maskData).contains("public init?(width: Int, height: Int, bytes: Data)"))
        #expect(Self.initializerSignatures(accessLevel: "public", in: replacementCommand).contains("public init(index: EditableLayerIndex, pixelData: LayerPixelData)"))
    }

    @Test
    func domainUncheckedConstructorsStayPackageScoped() throws {
        let repoRoot = try Self.repoRoot()
        let domainRoot = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentDomain",
            isDirectory: true
        )
        let sources = try Self.swiftSources(under: domainRoot)
        for source in sources {
            let body = try String(contentsOf: source, encoding: .utf8)
            let inspector = ArchitectureSourceInspector(source: body)
            #expect(
                !inspector.initializerSignatures.contains { signature in
                    signature.hasPrefix("public init(unchecked")
                },
                "\(source.path) should keep unsafe constructors package-scoped"
            )
            #expect(
                !inspector.callables.contains { callable in
                    callable.accessLevel == "public" && callable.name == "unchecked"
                },
                "\(source.path) should keep unsafe factories package-scoped"
            )
        }

        let workspaceDocumentTypes = try String(
            contentsOf: domainRoot.appendingPathComponent("WorkspaceDocumentTypes.swift"),
            encoding: .utf8
        )
        let relativePath = try #require(Self.typeBody(named: "RelativeProjectFolderPath", in: workspaceDocumentTypes))
        #expect(
            Self.initializerSignatures(accessLevel: "public", in: relativePath).contains("public init(validatingComponents components: [String])"),
            "RelativeProjectFolderPath component construction should stay validating"
        )
        #expect(
            Self.callables(in: relativePath).contains { callable in
                callable.accessLevel == "package" &&
                    callable.name == "unsafeUnchecked" &&
                    callable.parameters.first?.type == "[String]"
            },
            "RelativeProjectFolderPath unchecked component construction should stay package-scoped"
        )
        #expect(
            !relativePath.contains("public init?(components: [String])") &&
            !relativePath.contains("public init(components: [String])"),
            "RelativeProjectFolderPath should not reintroduce a non-validating component initializer"
        )
    }

    @Test
    func swiftDocumentRuntimeDoesNotConstructMetalServicesOrUseSharedSingleton() throws {
        let repoRoot = try Self.repoRoot()
        let runtime = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/SwiftDocumentRuntime.swift",
            isDirectory: false
        )
        let body = try String(contentsOf: runtime, encoding: .utf8)
        let imports = Self.swiftImports(in: body)
        let bannedImports = Set([
            "PrimoDocumentMetalRuntimeInfrastructure",
            "PrimoDocumentRenderingInfrastructure"
        ])
        let banned = [
            "PrimoMetalDocumentProcessingClient.shared",
            "MetalRuntimeContext",
            "MetalResourceStore",
            "MetalStrokeExecutionService",
            "MetalCompositingService",
            "MetalLayerMutationService",
            "MetalTextService",
            "MetalStrokeExecutionRequest"
        ]
        #expect(
            imports.isDisjoint(with: bannedImports),
            "SwiftDocumentRuntime should depend on injected GPU services instead of concrete Metal/rendering modules"
        )
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
    func renderingInfrastructurePublicSurfaceStaysNarrow() throws {
        let repoRoot = try Self.repoRoot()
        let renderingRoot = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentRenderingInfrastructure",
            isDirectory: true
        )
        let actualSymbols = try Set(
            Self.swiftSources(under: renderingRoot)
                .flatMap { source in
                    Self.publicTopLevelSymbols(in: try String(contentsOf: source, encoding: .utf8))
                }
        )
        let expectedSymbols: Set<String> = [
            "DocumentGpuOperationGatewayFactory",
            "GpuCanvasEyedropperSampler",
            "GpuCanvasPreviewRenderer",
            "GpuLayerTransformProcessor"
        ]

        #expect(actualSymbols == expectedSymbols)
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
        let graph = try Self.packageTargetGraph()
        let bannedEdges: [(source: String, dependency: String)] = [
            ("PrimoDocumentMetalStrokeInfrastructure", "PrimoDocumentRenderingInfrastructure"),
            ("PrimoDocumentMetalLayerInfrastructure", "PrimoDocumentRenderingInfrastructure")
        ]
        for edge in bannedEdges {
            #expect(
                graph[edge.source]?.contains(edge.dependency) != true,
                "\(edge.source) must not depend on \(edge.dependency)"
            )
        }
    }

    @Test
    func packageDependencyGraphKeepsStableLayersFreeOfInfrastructureEdges() throws {
        let graph = try Self.packageTargetGraph()
        for (target, dependencies) in graph {
            let isStableLayer = target.hasSuffix("Domain") ||
                target.hasSuffix("Application") ||
                target.hasSuffix("Contracts")
            guard isStableLayer else { continue }

            for dependency in dependencies {
                #expect(
                    !dependency.contains("Infrastructure"),
                    "\(target) must not depend on concrete infrastructure target \(dependency)"
                )
                #expect(
                    !Self.isForbiddenContractBoundaryDependency(dependency),
                    "\(target) must not depend on \(dependency); keep infrastructure, system clients, and file-format parsers behind runtime/application facades"
                )
            }
        }
    }

    @Test
    func stableLayersDoNotReachInfrastructureSystemClientsOrFileFormatsTransitively() throws {
        let graph = try Self.packageTargetGraph()

        for target in graph.keys {
            let isStableLayer = target.hasSuffix("Domain") ||
                target.hasSuffix("Application") ||
                target.hasSuffix("Contracts")
            guard isStableLayer else { continue }

            for dependency in Self.transitiveDependencies(of: target, in: graph) {
                #expect(
                    !Self.isForbiddenContractBoundaryDependency(dependency),
                    "\(target) must not transitively reach \(dependency); route live/file-format concerns through runtime or infrastructure assembly"
                )
            }
        }
    }

    @Test
    func brushFileFormatsDoNotOwnLiveSystemClients() throws {
        let repoRoot = try Self.repoRoot()
        let source = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoBrushFileFormats/PhotoshopBrushFile.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let body = Self.swiftCodeWithCommentsAndStringsBlanked(in: source)

        #expect(!body.contains("import PrimoSystemClients"))
        #expect(!body.contains(".live"))
    }

    @Test
    func packageContractTargetsDoNotDependOnInfrastructureOrSystemClients() throws {
        let graph = try Self.packageTargetGraph()

        for (target, dependencies) in graph {
            guard target.hasSuffix("Contracts") || target.hasSuffix("Domain") else { continue }

            for dependency in dependencies {
                guard Self.isForbiddenContractBoundaryDependency(dependency) else { continue }
                #expect(
                    Bool(false),
                    "\(target) must not depend on \(dependency); keep infrastructure, system clients, and file-format parsers behind runtime/application facades"
                )
            }
        }
    }

    @Test
    func validatedMutationTokensAreNotPubliclyForgeable() throws {
        let repoRoot = try Self.repoRoot()
        let mutationContracts = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentMutationContracts/DocumentMutationRuntimeContracts.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let layerContracts = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentApplication/DocumentLayerMutationContracts.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )

        let tokenBodies = [
            "EditableLayerIndex": mutationContracts,
            "ExistingLayerIndex": layerContracts,
            "ExistingFolderID": layerContracts,
            "LayerAnchorIndex": layerContracts
        ].compactMap { name, source in
            Self.declarationBody(named: name, in: source).map { (name, $0) }
        }
        #expect(tokenBodies.count == 4)

        for (name, body) in tokenBodies {
            #expect(
                Self.initializerSignatures(accessLevel: "public", in: body).isEmpty,
                "\(name) must not be publicly constructible"
            )
            #expect(
                !Self.functionSignatures(accessLevel: "public", in: body).contains { signature in
                    signature.contains("validated(") || signature.contains("unchecked") || signature.contains("unsafe")
                },
                "\(name) must not expose public minting or unchecked factories"
            )
        }
        #expect(layerContracts.contains("public func editableLayerIndex(_ rawValue: Int) -> EditableLayerIndex?"))
        #expect(!mutationContracts.contains("public static func validated("))
    }

    @Test
    func layerMutationContextsValidateAgainstLayerIndexSetInsteadOfLayerCountRange() throws {
        let repoRoot = try Self.repoRoot()
        let mutationContracts = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentMutationContracts/DocumentMutationRuntimeContracts.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let layerContracts = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentApplication/DocumentLayerMutationContracts.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let validationContracts = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentApplication/DocumentMutationContracts.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let workflowValidation = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "App/Features/Document/DocumentWorkflowValidation.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )
        let engineLive = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )

        let layerIndexSet = try #require(Self.declarationBody(named: "LayerIndexSet", in: mutationContracts))
        #expect(layerIndexSet.contains("public let rawValues: Set<Int>"))
        #expect(layerIndexSet.contains("public static func contiguous(count: Int) -> LayerIndexSet"))
        #expect(layerIndexSet.contains("public func contains(_ rawValue: Int) -> Bool"))

        let editableLayerIndex = try #require(Self.declarationBody(named: "EditableLayerIndex", in: mutationContracts))
        #expect(editableLayerIndex.contains("layerIndexes: LayerIndexSet"))
        #expect(editableLayerIndex.contains("layerIndexes.contains(rawValue)"))
        #expect(!editableLayerIndex.contains("(0..<layerCount).contains(rawValue)"))

        let layerContext = try #require(Self.declarationBody(named: "DocumentLayerMutationContext", in: layerContracts))
        #expect(layerContext.contains("public let layerIndexes: LayerIndexSet"))
        #expect(layerContext.contains("public var layerCount: Int"))
        #expect(layerContext.contains("public func containsLayerIndex(_ rawValue: Int) -> Bool"))
        #expect(layerContext.contains("guard containsLayerIndex(rawValue) else"))
        #expect(layerContext.contains("layerIndexes: layerIndexes"))
        #expect(!layerContext.contains("(0..<layerCount).contains(rawValue)"))

        let validationContext = try #require(Self.declarationBody(named: "DocumentMutationValidationContext", in: validationContracts))
        #expect(validationContext.contains("public let layerIndexes: LayerIndexSet"))
        #expect(validationContext.contains("public func containsLayerIndex(_ rawValue: Int) -> Bool"))
        #expect(validationContracts.contains("guard context.containsLayerIndex(target.index)"))
        #expect(validationContracts.contains("anchor.index < 0 || context.containsLayerIndex(anchor.index)"))
        #expect(!validationContracts.contains("(0..<context.layerCount).contains"))

        #expect(workflowValidation.contains("layerIndexes: state.layerSidebar.layers.map(\\.index)"))
        #expect(engineLive.contains("layerIndexes: presentation.layerRows.map(\\.index)"))
    }

    @Test
    func noPublicRawIntLayerMutationMethods() throws {
        let repoRoot = try Self.repoRoot()
        let checkedFiles = [
            "Packages/PrimoModules/Sources/PrimoDocumentRuntime/DocumentRuntimeFacade.swift",
            "Packages/PrimoModules/Sources/PrimoDocumentMutationContracts/DocumentMutationRuntimeContracts.swift",
            "Packages/PrimoModules/Sources/PrimoDocumentApplication/DocumentMutationWorkflow.swift",
            "Packages/PrimoModules/Sources/PrimoDocumentApplication/DocumentLayerMutationContracts.swift",
            "Packages/PrimoModules/Sources/PrimoDocumentApplication/DocumentLayerContentMutationContracts.swift"
        ]
        let mutationMethodPrefixes = [
            "createFolder",
            "deleteFolder",
            "deleteLayer",
            "duplicateLayer",
            "moveLayer",
            "assignLayer",
            "mergeLayerDown",
            "setLayer",
            "setFolder",
            "replaceLayer",
            "applyLayer",
            "clearLayer",
            "revealLayer",
            "ensureLayer",
            "setTextLayer",
            "clearTextLayer"
        ]
        let rawLayerParameterNames: Set<String> = [
            "index",
            "layerIndex",
            "activeLayerIndex",
            "destinationIndex",
            "folderID",
            "activeLayerIndex"
        ]

        for file in checkedFiles {
            let body = try String(
                contentsOf: repoRoot.appendingPathComponent(file, isDirectory: false),
                encoding: .utf8
            )
            #expect(!body.contains("DocumentIndexedMutationResult"), "\(file) should not expose untyped indexed mutation results")
            #expect(!body.contains("DocumentLayerIndexedMutationResult"), "\(file) should not expose untyped indexed mutation results")
            #expect(!body.contains("Result<Int, DocumentMutationFailure>"), "\(file) should not return raw Int mutation results")
            #expect(!body.contains("Result<Int, DocumentLayerMutationFailure>"), "\(file) should not return raw Int layer mutation results")
            for callable in Self.callables(accessLevel: "public", in: body)
                where callable.kind == "func" &&
                    mutationMethodPrefixes.contains(where: callable.name.hasPrefix)
            {
                let rawLayerParameter = callable.parameters.first { parameter in
                    rawLayerParameterNames.contains(parameter.semanticName) && parameter.type == "Int"
                }
                #expect(rawLayerParameter == nil, "\(file): \(callable.signature) should use typed layer/folder tokens")
            }
        }
    }

    @Test
    func uncheckedSendableIsAllowlisted() throws {
        let repoRoot = try Self.repoRoot()
        let roots = [
            repoRoot.appendingPathComponent("Packages/PrimoModules/Sources", isDirectory: true),
            repoRoot.appendingPathComponent("App", isDirectory: true)
        ].filter { FileManager.default.fileExists(atPath: $0.path) }
        let allowed: Set<String> = [
            "Packages/PrimoModules/Sources/PrimoBrushInfrastructure/TextFontLibraryClient.swift:RegisteredFontURLRegistry",
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DirtyUpdatePublisher.swift:DirtyUpdatePublisher",
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift:DocumentTimelapseReplayService",
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentPresentationBuilder.swift:DocumentPresentationBuilder",
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/GpuMutationPayloadLease.swift:GpuMutationPayloadLease",
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/SwiftDocumentRuntime.swift:GpuResourceLease",
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/SwiftDocumentRuntime.swift:SwiftDocumentRuntime",
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/SwiftDocumentStore.swift:SwiftDocumentStore",
            "Packages/PrimoModules/Sources/PrimoDocumentInfrastructure/DocumentRuntimeSupport.swift:LockedDocumentRuntimeExecutor",
            "Packages/PrimoModules/Sources/PrimoDocumentMetalRuntimeInfrastructure/PrimoMetalDocumentProcessingClient.swift:PrimoMetalDocumentProcessingClient",
            "Packages/PrimoModules/Sources/PrimoDocumentPresentationContracts/CanvasPresentationTypes.swift:PreviewStrokeStyle",
            "Packages/PrimoModules/Sources/PrimoDocumentPresentationContracts/CanvasPresentationTypes.swift:PreviewStrokeTrack",
            "Packages/PrimoModules/Sources/PrimoDocumentRuntimeLive/DocumentRuntimePresentationBroadcaster.swift:DocumentRuntimePresentationBroadcaster"
        ]

        var actual: Set<String> = []
        for root in roots {
            for source in try Self.swiftSources(under: root) {
                let relativePath = source.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
                let body = try String(contentsOf: source, encoding: .utf8)
                for declaration in Self.uncheckedSendableDeclarations(in: body) {
                    actual.insert("\(relativePath):\(declaration)")
                }
            }
        }

        #expect(actual == allowed, "Update this allowlist only when the unchecked Sendable ownership/locking rationale is reviewed. Actual: \(actual.sorted())")
    }

    @Test
    func noSentinelLayerIndexValues() throws {
        let repoRoot = try Self.repoRoot()
        let roots = [
            repoRoot.appendingPathComponent("Packages/PrimoModules/Sources", isDirectory: true),
            repoRoot.appendingPathComponent("App/Features/Document", isDirectory: true)
        ].filter { FileManager.default.fileExists(atPath: $0.path) }
        let bannedPatterns = [
            #"anchorLayerIndex\s*:\s*-1"#,
            #"anchorLayerIndex\.rawValue\s*\?\?\s*-1"#,
            #"rawValue\s*\?\?\s*-1"#,
            #"folderID\?\.rawValue\s*\?\?\s*-1"#,
            #"rawValueOrSentinel"#
        ]

        for root in roots {
            for source in try Self.swiftSources(under: root) {
                let relativePath = source.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
                let code = Self.swiftCodeWithCommentsAndStringsBlanked(
                    in: try String(contentsOf: source, encoding: .utf8)
                )
                for pattern in bannedPatterns {
                    #expect(
                        code.range(of: pattern, options: .regularExpression) == nil,
                        "\(relativePath) should use LayerAnchorIndex/optional typed values instead of sentinel pattern \(pattern)"
                    )
                }
            }
        }
    }

    @Test
    func appPreviewAdaptersDoNotCreateAuthoritativeLayerIndexesWithInitialRevision() throws {
        let repoRoot = try Self.repoRoot()
        let adapterFiles = [
            "App/Features/Document/DocumentRuntimeAdapters+PresentationWorkflow.swift",
            "App/Features/Document/DocumentRuntimeAdapters+Canvas.swift",
            "App/Features/Document/DocumentRuntimeAdapters+Layer.swift",
            "App/Features/Document/DocumentRuntimeAdapters+PersistenceExport.swift",
            "App/Features/Document/DocumentRuntimeAdapters+PreviewRendering.swift",
            "App/Features/Document/DocumentRuntimeAdapters+Stroke.swift",
            "App/Features/Document/DocumentWorkflowValidation.swift"
        ]

        for file in adapterFiles {
            let body = Self.swiftCodeWithCommentsAndStringsBlanked(
                in: try String(
                    contentsOf: repoRoot.appendingPathComponent(file, isDirectory: false),
                    encoding: .utf8
                )
            )
            #expect(
                !body.contains("DocumentLayerMutationContext(\n                revision: .initial") &&
                    !body.contains("DocumentLayerMutationContext(\n            revision: .initial") &&
                    !body.contains("DocumentLayerMutationContext(revision: .initial"),
                "\(file) should not mint authoritative layer indexes from preview state at .initial revision"
            )
        }
    }

    @Test
    func coreTypesStayFreeOfLiveSystemSideEffects() throws {
        let repoRoot = try Self.repoRoot()
        let graph = try Self.packageTargetGraph()
        #expect(graph["PrimoCoreContracts"] == [] as Set<String>)
        #expect(graph["PrimoSystemContracts"] == [] as Set<String>)
        #expect(graph["PrimoCoreTypes"] == ["PrimoCoreContracts", "PrimoSystemContracts"] as Set<String>)
        #expect(graph["PrimoCoreTypes"]?.contains("PrimoSystemClients") != true)
        #expect(graph["PrimoSystemClients"] == ["PrimoSystemContracts"] as Set<String>)

        let coreRoot = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoCoreContracts",
            isDirectory: true
        )
        let systemContractsRoot = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoSystemContracts",
            isDirectory: true
        )
        let liveRoot = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoSystemClients",
            isDirectory: true
        )
        let compatibilityURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoCoreTypes/CoreTypesCompatibility.swift",
            isDirectory: false
        )
        let coreSources = try Self.swiftSources(under: coreRoot)
        let systemContractSources = try Self.swiftSources(under: systemContractsRoot)
        let liveSources = try Self.swiftSources(under: liveRoot)
        let contractImports = try (coreSources + systemContractSources).flatMap { source in
            let body = try String(contentsOf: source, encoding: .utf8)
            return ArchitectureSourceInspector(source: body).imports.map(\.moduleName)
        }
        let liveImports = try liveSources.flatMap { source in
            let body = try String(contentsOf: source, encoding: .utf8)
            return ArchitectureSourceInspector(source: body).imports.map(\.moduleName)
        }

        #expect(!contractImports.contains("Security"))
        #expect(liveImports.contains("Security"))
        #expect(liveImports.contains("PrimoSystemContracts"))
        #expect(!liveImports.contains("PrimoCoreTypes"))

        let compatibilitySource = try String(contentsOf: compatibilityURL, encoding: .utf8)
        let compatibilityInspector = ArchitectureSourceInspector(source: compatibilitySource)
        let compatibilityImports = compatibilityInspector.imports
        #expect(compatibilityImports.contains(.init(moduleName: "PrimoCoreContracts", attributes: ["_exported"])))
        #expect(compatibilityImports.contains(.init(moduleName: "PrimoSystemContracts", attributes: ["_exported"])))
        let compatibilityAliases = Set(compatibilityInspector.typealiases.map(\.name))
        #expect(compatibilityAliases.isSuperset(of: [
            "OperationRequest",
            "OperationContract",
            "DateClient",
            "UUIDClient",
            "FileClient",
            "HTTPClient",
            "SecretStoreClient",
            "SecurityScopedResourceClient",
        ]))

        for source in coreSources + systemContractSources {
            let body = try String(contentsOf: source, encoding: .utf8)
            let declarations = ArchitectureSourceInspector(source: body).topLevelDeclarations
            #expect(
                declarations.allSatisfy { $0.accessLevel == "public" },
                "\(source.path) should expose contracts only through public declarations"
            )
        }

        let liveBody = try liveSources
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
        for token in ["FileManager.default", "URLSession.shared", "UserDefaults.standard", "SecItem", "ProcessInfo.processInfo", "DispatchQueue.main"] {
            #expect(
                liveBody.contains(token),
                "PrimoSystemClients should own live system-client implementation token \(token)"
            )
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

    private static func targetName(in declarationLocation: String) -> String {
        String(declarationLocation.prefix { $0 != ":" })
    }

    private static func swiftImports(in source: String) -> Set<String> {
        ArchitectureSourceInspector(source: source).importedModules
    }

    private static func exportedImports(in source: String) -> [ArchitectureSourceInspector.Import] {
        ArchitectureSourceInspector(source: source).imports
            .filter { $0.attributes.contains("_exported") }
    }

    private static func dependencyKeys(in source: String) -> Set<String> {
        ArchitectureSourceInspector(source: source).dependencyAttributeKeys
    }

    private static func swiftCodeWithCommentsAndStringsBlanked(in source: String) -> String {
        var output = ""
        var cursor = source.startIndex
        var blockCommentDepth = 0
        var isInsideLineComment = false
        var isInsideString = false
        var escaped = false

        func appendBlankOrNewline(_ character: Character) {
            output.append(character == "\n" ? "\n" : " ")
        }

        while cursor < source.endIndex {
            let character = source[cursor]
            let next = source.index(after: cursor)
            let nextCharacter = next < source.endIndex ? source[next] : nil

            if isInsideLineComment {
                isInsideLineComment = character != "\n"
                appendBlankOrNewline(character)
            } else if blockCommentDepth > 0 {
                if character == "/", nextCharacter == "*" {
                    blockCommentDepth += 1
                    output.append("  ")
                    cursor = source.index(after: next)
                    continue
                }
                if character == "*", nextCharacter == "/" {
                    blockCommentDepth -= 1
                    output.append("  ")
                    cursor = source.index(after: next)
                    continue
                }
                appendBlankOrNewline(character)
            } else if isInsideString {
                appendBlankOrNewline(character)
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
            } else if character == "/", nextCharacter == "/" {
                isInsideLineComment = true
                output.append("  ")
                cursor = source.index(after: next)
                continue
            } else if character == "/", nextCharacter == "*" {
                blockCommentDepth = 1
                output.append("  ")
                cursor = source.index(after: next)
                continue
            } else if character == "\"" {
                isInsideString = true
                output.append(" ")
            } else {
                output.append(character)
            }
            cursor = next
        }
        return output
    }

    private static func yamlTargetBlock(named targetName: String, in yaml: String) -> String? {
        let marker = "\n  \(targetName):\n"
        guard let range = yaml.range(of: marker) else { return nil }
        let bodyStart = range.upperBound
        let remaining = yaml[bodyStart...]
        let nextTarget = remaining.range(of: "\n  [^\\s][A-Za-z0-9_ -]*:\\n", options: .regularExpression)
        let bodyEnd = nextTarget?.lowerBound ?? yaml.endIndex
        return String(yaml[range.lowerBound..<bodyEnd])
    }

    private static func publicTopLevelSymbols(in source: String) -> [String] {
        ArchitectureSourceInspector(source: source).topLevelDeclarations
            .filter { $0.accessLevel == "public" }
            .map(\.name)
    }

    private static func publicTopLevelTypealiases(in source: String) -> [String] {
        ArchitectureSourceInspector(source: source).topLevelDeclarations
            .filter { $0.accessLevel == "public" && $0.kind == "typealias" }
            .map(\.name)
    }

    private static func infrastructureProductNames(in source: String) -> [String] {
        PackageManifestProductParser.libraryProductNames(in: source)
            .filter { $0.hasSuffix("Infrastructure") }
    }

    private static func storedPropertyNames(accessLevel: String, in source: String) -> [String] {
        ArchitectureSourceInspector(source: source).properties
            .filter { $0.accessLevel == accessLevel && $0.isStored }
            .map(\.name)
    }

    private static func storedProperties(
        accessLevel: String,
        in source: String
    ) -> [ArchitectureSourceInspector.Property] {
        ArchitectureSourceInspector(source: source).properties
            .filter { $0.accessLevel == accessLevel && $0.isStored }
    }

    private static func computedPropertyNames(accessLevel: String, in source: String) -> Set<String> {
        Set(
            ArchitectureSourceInspector(source: source).properties
                .filter { $0.accessLevel == accessLevel && !$0.isStored }
                .map(\.name)
        )
    }

    private static func initializerSignatures(accessLevel: String, in source: String) -> [String] {
        ArchitectureSourceInspector(source: source).initializerSignatures
            .filter { $0.hasPrefix("\(accessLevel) init") }
    }

    private static func initializerDeclarations(accessLevel: String, in source: String) -> [String] {
        let prefix = "\(accessLevel) init"
        var declarations: [String] = []
        var searchStart = source.startIndex
        while let range = source.range(of: prefix, range: searchStart..<source.endIndex) {
            guard let openingBrace = source[range.lowerBound...].firstIndex(of: "{") else { break }
            declarations.append(String(source[range.lowerBound..<openingBrace]))
            searchStart = openingBrace
        }
        return declarations
    }

    private static func functionSignatures(accessLevel: String? = nil, in source: String) -> [String] {
        ArchitectureSourceInspector(source: source).functionSignatures
            .filter { signature in
                guard let accessLevel else { return true }
                return signature.hasPrefix("\(accessLevel) ") ||
                    signature.hasPrefix("\(accessLevel) static ") ||
                    signature.hasPrefix("\(accessLevel) class ")
            }
    }

    private static func callables(
        accessLevel: String? = nil,
        in source: String
    ) -> [ArchitectureSourceInspector.Callable] {
        ArchitectureSourceInspector(source: source).callables
            .filter { callable in
                guard let accessLevel else { return true }
                return callable.accessLevel == accessLevel
            }
    }

    private static func documentRuntimeAdapterSources(repoRoot: URL) throws -> String {
        try [
            "App/Features/Document/DocumentRuntimeAdapters+PresentationWorkflow.swift",
            "App/Features/Document/DocumentRuntimeAdapters+Canvas.swift",
            "App/Features/Document/DocumentRuntimeAdapters+Layer.swift",
            "App/Features/Document/DocumentRuntimeAdapters+PersistenceExport.swift",
            "App/Features/Document/DocumentRuntimeAdapters+PreviewRendering.swift",
            "App/Features/Document/DocumentRuntimeAdapters+Stroke.swift"
        ].map { relativePath in
            try String(
                contentsOf: repoRoot.appendingPathComponent(relativePath, isDirectory: false),
                encoding: .utf8
            )
        }.joined(separator: "\n")
    }

    private static func rawLayerPackageCallableSignatures(in source: String) -> [String] {
        let rawLayerParameterNames: Set<String> = [
            "index",
            "layerIndex",
            "activeLayerIndex",
            "destinationIndex",
            "folderID"
        ]
        let rawPayloadParameterNames: Set<String> = [
            "pixelData",
            "maskData"
        ]
        return Self.callables(accessLevel: "package", in: source)
            .filter { callable in
                callable.parameters.contains { parameter in
                    rawLayerParameterNames.contains(parameter.semanticName) &&
                        (parameter.type == "Int" || parameter.type == "Int?")
                } ||
                    callable.parameters.contains { parameter in
                        rawPayloadParameterNames.contains(parameter.semanticName) &&
                            parameter.type == "Data"
                    }
            }
            .map(\.signature)
            .map(Self.normalizedSignature)
            .sorted()
    }

    private static func normalizedSignature(_ signature: String) -> String {
        signature
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
            .replacingOccurrences(of: #" +"#, with: " ", options: .regularExpression)
    }

    private static func matchingDelimiter(
        in text: String,
        open: String.Index,
        opening: Character,
        closing: Character
    ) -> String.Index? {
        var depth = 0
        var cursor = open
        while cursor < text.endIndex {
            let character = text[cursor]
            if character == opening {
                depth += 1
            } else if character == closing {
                depth -= 1
                if depth == 0 { return cursor }
            }
            cursor = text.index(after: cursor)
        }
        return nil
    }

    private static func declarationBody(named typeName: String, in source: String) -> String? {
        ArchitectureSourceInspector(source: source).declarationSource(named: typeName)
    }

    private static func typeBody(named typeName: String, in source: String) -> String? {
        Self.declarationBody(named: typeName, in: source)
    }

    private static func functionBody(matching signature: String, in source: String) -> String? {
        guard let declaration = source.range(of: signature) else {
            return nil
        }
        guard let openingBrace = source[declaration.lowerBound...].firstIndex(of: "{") else {
            return nil
        }
        var depth = 0
        var index = openingBrace
        while index < source.endIndex {
            let character = source[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(source[openingBrace...index])
                }
            }
            index = source.index(after: index)
        }
        return nil
    }

    private static func packageTargetGraph() throws -> [String: Set<String>] {
        try cachedPackageTargetGraph.get()
    }

    private static func isForbiddenContractBoundaryDependency(_ dependency: String) -> Bool {
        dependency.contains("Infrastructure") ||
            dependency == "PrimoSystemClients" ||
            dependency.hasSuffix("FileFormats")
    }

    private static func transitiveDependencies(
        of target: String,
        in graph: [String: Set<String>]
    ) -> Set<String> {
        var visited: Set<String> = []
        var stack = Array(graph[target] ?? [])

        while let dependency = stack.popLast() {
            guard visited.insert(dependency).inserted else { continue }
            stack.append(contentsOf: graph[dependency] ?? [])
        }

        return visited
    }

    private static func uncheckedSendableDeclarations(in source: String) -> [String] {
        let pattern = #"(?:public|package|private|fileprivate|internal)?\s*(?:final\s+)?(?:class|struct|actor)\s+([A-Za-z_][A-Za-z0-9_]*)[^{\n]*@unchecked\s+Sendable|(?:public|package|private|fileprivate|internal)?\s*(?:final\s+)?(?:class|struct|actor)\s+([A-Za-z_][A-Za-z0-9_]*)[^{\n]*:\s*@unchecked\s+Sendable"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        return regex.matches(in: source, range: nsRange).compactMap { match in
            for index in 1..<match.numberOfRanges {
                guard let range = Range(match.range(at: index), in: source) else { continue }
                return String(source[range])
            }
            return nil
        }
    }

    private static let cachedPackageTargetGraph: Result<[String: Set<String>], Error> = Result {
        try loadPackageTargetGraph()
    }

    private static func loadPackageTargetGraph() throws -> [String: Set<String>] {
        let repoRoot = try Self.repoRoot()
        let packageRoot = repoRoot.appendingPathComponent("Packages/PrimoModules", isDirectory: true)
        let scratchRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            "primo-dump-package-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: scratchRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratchRoot) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = [
            "package",
            "--package-path",
            packageRoot.path,
            "--scratch-path",
            scratchRoot.path,
            "dump-package"
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["DEVELOPER_DIR"] = environment["DEVELOPER_DIR"] ?? "/Applications/Xcode.app/Contents/Developer"
        process.environment = environment

        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let message = String(data: outputData, encoding: .utf8) ?? ""
            throw PackageGraphError.dumpPackageFailed(message)
        }
        return try PackageDumpTargetGraph.decode(from: outputData)
    }

    #if os(macOS)
        private static func generatedPublicSymbolSnapshots(
            for moduleNames: [String],
            repoRoot: URL
        ) throws -> [String: String] {
            let packageRoot = repoRoot.appendingPathComponent("Packages/PrimoModules", isDirectory: true)
            let scratchRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
                "primo-symbolgraph-\(UUID().uuidString)",
                isDirectory: true
            )
            try FileManager.default.createDirectory(at: scratchRoot, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: scratchRoot) }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
            process.arguments = [
                "package",
                "--package-path",
                packageRoot.path,
                "--scratch-path",
                scratchRoot.path,
                "dump-symbol-graph",
                "--minimum-access-level",
                "public",
                "--skip-synthesized-members"
            ]
            var environment = ProcessInfo.processInfo.environment
            environment["DEVELOPER_DIR"] = environment["DEVELOPER_DIR"] ?? "/Applications/Xcode.app/Contents/Developer"
            process.environment = environment

            let outputURL = scratchRoot.appendingPathComponent("symbolgraph-extract.log", isDirectory: false)
            FileManager.default.createFile(atPath: outputURL.path, contents: nil)
            let outputHandle = try FileHandle(forWritingTo: outputURL)
            defer { try? outputHandle.close() }
            process.standardOutput = outputHandle
            process.standardError = outputHandle
            try process.run()
            process.waitUntilExit()

            let requestedSymbolGraphs = try moduleNames.map { moduleName in
                try #require(Self.symbolGraphURL(for: moduleName, under: scratchRoot))
            }

            if process.terminationStatus != 0, requestedSymbolGraphs.count != moduleNames.count {
                let message = try String(contentsOf: outputURL, encoding: .utf8)
                throw SymbolSnapshotError.symbolGraphExtractionFailed(message)
            }

            var snapshots: [String: String] = [:]
            for (moduleName, symbolGraph) in zip(moduleNames, requestedSymbolGraphs) {
                snapshots[moduleName] = try Self.normalizedPublicSymbolSnapshot(at: symbolGraph)
            }
            return snapshots
        }
    #endif

    private static func symbolGraphURL(for moduleName: String, under root: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        for item in enumerator {
            guard let url = item as? URL else { continue }
            guard url.lastPathComponent == "\(moduleName).symbols.json" else { continue }
            return url
        }
        return nil
    }

    private static func normalizedPublicSymbolSnapshot(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let symbols = root["symbols"] as? [[String: Any]]
        else {
            throw SymbolSnapshotError.invalidSymbolGraph(url.path)
        }
        let records = symbols.compactMap(SymbolSnapshotRecord.init(symbol:))
        return records.sorted().map(\.line).joined(separator: "\n") + "\n"
    }
}

private enum SymbolSnapshotError: Error, CustomStringConvertible {
    case symbolGraphExtractionFailed(String)
    case invalidSymbolGraph(String)

    var description: String {
        switch self {
        case let .symbolGraphExtractionFailed(message):
            return "symbol graph extraction failed: \(message)"
        case let .invalidSymbolGraph(path):
            return "invalid symbol graph: \(path)"
        }
    }
}

private enum PackageGraphError: Error, CustomStringConvertible {
    case dumpPackageFailed(String)

    var description: String {
        switch self {
        case let .dumpPackageFailed(message):
            return "swift package dump-package failed: \(message)"
        }
    }
}

private enum PackageDumpTargetGraph {
    static func decode(from data: Data) throws -> [String: Set<String>] {
        let package = try JSONDecoder().decode(DumpPackage.self, from: data)
        return Dictionary(uniqueKeysWithValues: package.targets.map { target in
            (target.name, Set(target.dependencies.compactMap(\.targetName)))
        })
    }

    private struct DumpPackage: Decodable {
        let targets: [Target]
    }

    private struct Target: Decodable {
        let name: String
        let dependencies: [Dependency]
    }

    private struct Dependency: Decodable {
        let targetName: String?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let byName = try container.decodeIfPresent([String?].self, forKey: .byName) {
                targetName = byName.first ?? nil
            } else if let product = try container.decodeIfPresent([String?].self, forKey: .product) {
                targetName = product.first ?? nil
            } else {
                targetName = nil
            }
        }

        private enum CodingKeys: String, CodingKey {
            case byName
            case product
        }
    }
}

private extension ArchitectureSourceInspector.Callable {
    func hasParameter(named name: String, type: String) -> Bool {
        parameters.contains { $0.semanticName == name && $0.type == type }
    }

    func hasParameter(type: String) -> Bool {
        parameters.contains { $0.type == type }
    }
}

private extension ArchitectureSourceInspector.Callable.Parameter {
    var semanticName: String {
        secondName ?? firstName ?? ""
    }
}

private struct SymbolSnapshotRecord: Comparable {
    let kind: String
    let preciseIdentifier: String
    let path: String
    let title: String
    let declaration: String

    init?(symbol: [String: Any]) {
        guard symbol["accessLevel"] as? String == "public" else { return nil }
        guard
            let kind = (symbol["kind"] as? [String: Any])?["identifier"] as? String,
            let preciseIdentifier = (symbol["identifier"] as? [String: Any])?["precise"] as? String,
            let pathComponents = symbol["pathComponents"] as? [String],
            let title = (symbol["names"] as? [String: Any])?["title"] as? String
        else {
            return nil
        }
        self.kind = kind
        self.preciseIdentifier = preciseIdentifier
        self.path = pathComponents.joined(separator: ".")
        self.title = title
        self.declaration = (symbol["declarationFragments"] as? [[String: Any]])?
            .compactMap { $0["spelling"] as? String }
            .joined() ?? ""
    }

    init?(line: String) {
        let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard columns.count == 5 else { return nil }
        self.kind = columns[0]
        self.preciseIdentifier = columns[1]
        self.path = columns[2]
        self.title = columns[3]
        self.declaration = columns[4]
    }

    static func records(in snapshot: String) -> [SymbolSnapshotRecord] {
        snapshot.split(separator: "\n").compactMap { SymbolSnapshotRecord(line: String($0)) }
    }

    static func < (lhs: SymbolSnapshotRecord, rhs: SymbolSnapshotRecord) -> Bool {
        lhs.line < rhs.line
    }

    var line: String {
        [
            kind,
            preciseIdentifier,
            path,
            title,
            declaration
        ].joined(separator: "\t")
    }

    var referencesInfrastructureTypeName: Bool {
        [path, title, declaration].contains { field in
            field.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" })
                .contains { $0.hasSuffix("Infrastructure") }
        }
    }
}

private enum PackageManifestProductParser {
    static func libraryProductNames(in manifest: String) -> [String] {
        callBlocks(named: ".library", in: manifest).compactMap { block in
            firstQuotedValue(after: "name:", in: block)
        }
    }

    private static func callBlocks(named marker: String, in text: String) -> [String] {
        var blocks: [String] = []
        var cursor = text.startIndex
        var isInsideLineComment = false
        var blockCommentDepth = 0
        var isInsideString = false
        var escaped = false

        while cursor < text.endIndex {
            let character = text[cursor]
            let next = text.index(after: cursor)
            let nextCharacter = next < text.endIndex ? text[next] : nil

            if isInsideLineComment {
                isInsideLineComment = character != "\n"
            } else if blockCommentDepth > 0 {
                if character == "/", nextCharacter == "*" {
                    blockCommentDepth += 1
                    cursor = text.index(after: next)
                    continue
                }
                if character == "*", nextCharacter == "/" {
                    blockCommentDepth -= 1
                    cursor = text.index(after: next)
                    continue
                }
            } else if isInsideString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
            } else if character == "/", nextCharacter == "/" {
                isInsideLineComment = true
                cursor = text.index(after: next)
                continue
            } else if character == "/", nextCharacter == "*" {
                blockCommentDepth = 1
                cursor = text.index(after: next)
                continue
            } else if character == "\"" {
                isInsideString = true
            } else if text[cursor...].hasPrefix(marker),
                      let openParen = text[cursor...].firstIndex(of: "("),
                      let closeParen = matchingDelimiter(in: text, open: openParen, opening: "(", closing: ")") {
                blocks.append(String(text[cursor...closeParen]))
                cursor = text.index(after: closeParen)
                continue
            }
            cursor = next
        }

        return blocks
    }

    private static func firstQuotedValue(after label: String, in block: String) -> String? {
        guard let labelRange = block.range(of: label) else { return nil }
        return quotedStrings(in: String(block[labelRange.upperBound...])).first
    }

    private static func quotedStrings(in text: String) -> [String] {
        var output: [String] = []
        var index = text.startIndex
        while let opening = text[index...].firstIndex(of: "\"") {
            var cursor = text.index(after: opening)
            var value = ""
            var escaped = false
            while cursor < text.endIndex {
                let character = text[cursor]
                if escaped {
                    value.append(character)
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    output.append(value)
                    index = text.index(after: cursor)
                    break
                } else {
                    value.append(character)
                }
                cursor = text.index(after: cursor)
            }
            if cursor >= text.endIndex { break }
        }
        return output
    }

    private static func matchingDelimiter(
        in text: String,
        open: String.Index,
        opening: Character,
        closing: Character
    ) -> String.Index? {
        var depth = 0
        var cursor = open
        var isInsideString = false
        var escaped = false
        while cursor < text.endIndex {
            let character = text[cursor]
            if isInsideString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
            } else if character == "\"" {
                isInsideString = true
            } else if character == opening {
                depth += 1
            } else if character == closing {
                depth -= 1
                if depth == 0 { return cursor }
            }
            cursor = text.index(after: cursor)
        }
        return nil
    }
}
