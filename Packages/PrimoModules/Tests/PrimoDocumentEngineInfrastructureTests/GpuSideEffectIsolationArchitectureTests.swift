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
            #expect(!body.contains("@Dependency"), "\(sourcePath) should be dependency-free")
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
        let body = try String(contentsOf: documentFeature, encoding: .utf8)
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

        #expect(!body.contains("@Dependency"), "DocumentFeature.swift should not own workflow dependencies")
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
            "product: PrimoDocumentStrokeInfrastructure",
            "product: PrimoDocumentTimelapseInfrastructure",
            "product: PrimoWorkspaceInfrastructure"
        ]
        #expect(appTargetBlock.contains("product: PrimoDocumentRuntime"))
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
        let appSupportBlock = try #require(Self.yamlTargetBlock(named: "PrimoAppSupport", in: projectYML))
        let appTargetBlock = try #require(Self.yamlTargetBlock(named: "Primo", in: projectYML))

        #expect(appSupportBlock.contains("type: framework"))
        #expect(appSupportBlock.contains("path: App/Support"))
        #expect(appTargetBlock.contains("- target: PrimoAppSupport"))

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
    }

    @Test
    func architectureSourceParsersIgnoreNonSemanticTokens() {
        let imports = Self.swiftImports(
            in: """
            // import PrimoDocumentEngineInfrastructure
            let example = "import PrimoDocumentRenderingInfrastructure"
            @testable import PrimoDocumentRuntime
            @_exported import PrimoWorkspaceRuntime
            import struct Foundation.URL
            import PrimoDocumentApplication
            """
        )

        #expect(imports == Set([
            "PrimoDocumentRuntime",
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
        let gatewayBody = try #require(Self.typeBody(named: "DocumentMutationGateway", in: contract))
        for rawClosure in [
            "public let deleteLayer",
            "public let setActiveLayer",
            "public let replaceLayerPixels",
            "public let replaceLayerPixelsInRect",
            "public let applyLayerProcessing",
            "public let clearLayer",
            "public let replaceLayerMask"
        ] {
            #expect(!gatewayBody.contains(rawClosure), "DocumentMutationGateway should keep raw mutation closures package-scoped")
        }

        let appRoot = repoRoot.appendingPathComponent("App", isDirectory: true)
        for source in try Self.swiftSources(under: appRoot) {
            let body = try String(contentsOf: source, encoding: .utf8)
            #expect(
                !body.contains("@Dependency(\\.documentMutationGateway)"),
                "\(source.path) should use validated command/workflow services instead of raw DocumentMutationGateway"
            )
        }
    }

    @Test
    func documentRuntimeFacadeDoesNotReexportConcreteInfrastructureModules() throws {
        let repoRoot = try Self.repoRoot()
        let facade = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentRuntime/DocumentRuntimeFacade.swift",
            isDirectory: false
        )
        let body = try String(contentsOf: facade, encoding: .utf8)
        #expect(!body.contains("@_exported import"), "PrimoDocumentRuntime should expose explicit App-facing wrappers instead of reexporting infrastructure modules")
        #expect(!body.contains("public typealias"), "PrimoDocumentRuntime should wrap App-facing infrastructure APIs instead of typealiasing them")
        #expect(!body.contains("public let queryGateway:"))
        #expect(!body.contains("public let gpuOperationGateway:"))
        #expect(!body.contains("public let textLayerGateway:"))
        #expect(!body.contains("public let mutationGateway:"))
        #expect(!body.contains("public let canvasCommands:"))
        #expect(!body.contains("public let layerCommands:"))
        #expect(!body.contains("public let strokeCommands:"))
        #expect(!body.contains("public let historyCommands:"))
        #expect(!body.contains("public let mutationWorkflow:"))
        #expect(!body.contains("public let contentService:"))
        #expect(!body.contains("public let canvasEditingWorkflow:"))
        #expect(!body.contains("public let selectionWorkflow:"))
        #expect(!body.contains("public let renderingWorkflow:"))
        #expect(!body.contains("public let textLayerService:"))
        #expect(!body.contains("public let exportClient:"))
        #expect(!body.contains("public let persistenceClient:"))
        #expect(!body.contains("public let stroke: CanvasStrokeRuntime"))
        #expect(!body.contains("public var strokeEditing: StrokeEditingRuntime"))
        #expect(!body.contains("releaseSurfaceHandleHandler"), "DocumentRenderingWorkflow should not carry resource-release authority")
        #expect(!body.contains("public init(gpuOperations:"), "Runtime facade wrappers should not expose raw GPU gateway injection publicly")

        let publicSymbols = Set(Self.publicTopLevelSymbols(in: body))
        let expectedSymbols: Set<String> = [
            "DocumentRuntime",
            "DocumentRuntimeFactory",
            "DocumentApplicationRuntime",
            "DocumentApplicationWorkflowRuntime",
            "DocumentApplicationRuntimeFactory",
            "DocumentPresentationRuntime",
            "CanvasMutationRuntime",
            "StrokeEditingRuntime",
            "LayerEditingRuntime",
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
            "DocumentProjectPreviewLoader",
            "TimelapseExportProgress",
            "TimelapseExportResult",
            "TimelapseExportError",
            "TimelapseExportService",
            "GpuCanvasPreviewRenderer",
            "GpuCanvasEyedropperSampler",
            "GpuLayerTransformProcessor",
            "BrushStrokeKernel",
            "GpuRenderingSupport",
            "PrimoMetalSurfaceFiltering",
            "CanvasPresentationContainerView",
            "CanvasPixelSurfaceView"
        ]
        #expect(publicSymbols == expectedSymbols)
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
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeComposition.swift",
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
        let adapters = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "App/Features/Document/DocumentRuntimeAdapters.swift",
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
        #expect(body.contains("protocol SelectionWorkflowRequesting: Sendable"))
        #expect(body.contains("typealias CanvasStrokeWorkflowAccess"))
        #expect(body.contains("private enum DocumentApplicationEnvironmentKey: DependencyKey"))
        #expect(validation.contains("struct DocumentWorkflowCommandValidator: Sendable"))
        #expect(!paintDocumentClientBody.contains("struct DocumentWorkflowCommandValidator"))
        #expect(!paintDocumentClientBody.contains("private enum DocumentApplicationEnvironmentKey"))
        for key in bannedKeys {
            #expect(!body.contains(key), "PaintDocumentClient should derive \(key) from DocumentApplicationEnvironment")
        }
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
                    !body.contains("@Dependency(\\.\(key))"),
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
                !body.contains("@Dependency(\\.fileClient)"),
                "\(sourcePath) should use narrow capabilities instead of raw FileClient"
            )
            #expect(
                !body.contains("@Dependency(\\.documentWorkspaceClient)"),
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
        #expect(
            !body.contains("@_exported import"),
            "DocumentRuntimeContracts.swift should not hide dependency boundaries through re-exported imports"
        )
        for token in banned {
            #expect(!body.contains(token), "Runtime contract type \(token) should live in a narrow contract target")
        }
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
                !body.contains("@_exported import"),
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
        let banned = [
            "func setActiveLayerIndex(_ index: Int)",
            "func duplicateLayer(index: Int",
            "func deleteLayer(index: Int)",
            "func moveLayer(from index: Int",
            "func createFolder(name: String, anchorLayerIndex: Int)",
            "func deleteFolder(id folderID: Int)",
            "func assignLayer(index: Int",
            "func setLayerName(_ name: String, index: Int)",
            "func setLayerVisible(_ isVisible: Bool, index: Int)",
            "func setLayerLocked(_ isLocked: Bool, index: Int)",
            "func setLayerAlphaLocked(_ isAlphaLocked: Bool, index: Int)",
            "func setLayerClipped(_ isClipped: Bool, index: Int)",
            "func setLayerOpacity(_ opacity: Double, index: Int)",
            "func setLayerBlendMode(_ blendMode: LayerBlendMode, index: Int)",
            "func setFolderExpanded(_ isExpanded: Bool, folderID: Int)",
            "func setFolderVisible(_ isVisible: Bool, folderID: Int)",
            "func setFolderName(_ name: String, folderID: Int)"
        ]
        for token in banned {
            #expect(!body.contains(token), "Layer mutation gateways should accept validated value objects instead of \(token)")
        }
        #expect(body.contains("func addLayerAndSelect(name: String)"))
        #expect(!body.contains("func addLayer(name: String)"))
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
        let adapters = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "App/Features/Document/DocumentRuntimeAdapters.swift",
                isDirectory: false
            ),
            encoding: .utf8
        )

        #expect(mutationContracts.contains("public struct EditableLayerIndex"))
        #expect(mutationContracts.contains("public init?(\n        validating rawValue: Int"))
        #expect(mutationContracts.contains("package init(_ rawValue: Int)"))
        #expect(validation.contains("let layerIndex: EditableLayerIndex"))
        #expect(!validation.contains("let layerIndex: Int"))
        #expect(adapters.contains("command.layer.layerIndex.rawValue"))
        #expect(adapters.contains("command.layerIndex.rawValue"))
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
        #expect(engineLive.contains("@Sendable (String, LayerAnchorIndex) -> DocumentIndexedMutationResult"))
        #expect(engineLive.contains("@Sendable (ExistingLayerIndex, ExistingFolderID?) -> DocumentMutationResult"))

        let runtimeComposition = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeComposition.swift",
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
        let readGateway = try #require(Self.typeBody(named: "DocumentReadGateway", in: contracts))
        for token in [
            "compositePixelData",
            "compositeSurface",
            "pixelDataForLayer",
            "consumeDirtyUpdate"
        ] {
            #expect(!readGateway.contains(token), "DocumentReadGateway should expose presentation reads only")
        }
        #expect(contracts.contains("public struct DocumentRenderGateway"))
        #expect(contracts.contains("public struct DocumentDirtyUpdateQueue"))

        let composition = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeComposition.swift",
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

        let rawRenderingBodies = try [
            #require(Self.typeBody(named: "DocumentReadGateway", in: renderingContracts)),
            #require(Self.typeBody(named: "DocumentRenderGateway", in: renderingContracts)),
            #require(Self.typeBody(named: "DocumentDirtyUpdateQueue", in: renderingContracts)),
            #require(Self.typeBody(named: "DocumentGpuOperationGateway", in: renderingContracts)),
            #require(Self.typeBody(named: "DocumentCanvasPreviewRenderingOperations", in: renderingContracts)),
            #require(Self.typeBody(named: "DocumentSelectionMaskOperations", in: renderingContracts)),
            #require(Self.typeBody(named: "DocumentLayerTransformOperations", in: renderingContracts)),
            #require(Self.typeBody(named: "DocumentRenderingOperations", in: renderingContracts))
        ]
        let rawMutationBodies = try [
            #require(Self.typeBody(named: "StrokeInputGateway", in: mutationContracts)),
            #require(Self.typeBody(named: "DocumentHistoryGateway", in: mutationContracts)),
            #require(Self.typeBody(named: "TextLayerGateway", in: mutationContracts)),
            #require(Self.typeBody(named: "DocumentLayerEffectsGateway", in: mutationContracts))
        ]

        for body in rawRenderingBodies + rawMutationBodies {
            #expect(!body.contains("public let"), "Raw gateway closures should stay package-scoped")
        }
        #expect(rawRenderingBodies[0].contains("package let presentation"))
        #expect(rawRenderingBodies[1].contains("package let compositeSurface"))
        #expect(rawRenderingBodies[2].contains("package let consumeDirtyUpdate"))
        #expect(rawRenderingBodies[3].contains("package let compositedPreviewPixelData"))
        #expect(rawRenderingBodies[4].contains("package let shapePreviewSurface"))
        #expect(rawRenderingBodies[5].contains("package let transformedSelectionMask"))
        #expect(rawRenderingBodies[6].contains("package let transformedLayerPixelData"))
        #expect(rawRenderingBodies[7].contains("package let processedLayerPixelData"))
        #expect(rawMutationBodies[0].contains("package let beginStroke"))

        let gpuGatewayBody = rawRenderingBodies[3]
        let surfaceReleaserBody = try #require(Self.typeBody(named: "DocumentSurfaceHandleReleaser", in: renderingContracts))
        #expect(!gpuGatewayBody.contains("public init("), "DocumentGpuOperationGateway should not publicly accept raw GPU function tables")
        #expect(!surfaceReleaserBody.contains("public init(releaseSurfaceHandle"), "Raw surface-handle release authority should be constructed inside the package")
        #expect(surfaceReleaserBody.contains("public func releaseSurfaceLease(_ lease: StrokePreviewLease)"))
        #expect(renderingContracts.contains("public protocol SurfaceHandleReleasing"))
        #expect(rawMutationBodies[1].contains("package let undo"))
        #expect(rawMutationBodies[2].contains("package let setTextLayer"))
        #expect(rawMutationBodies[3].contains("package let mergeLayerDown"))
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

        for typeName in [
            "HueSaturationBrightnessSettings",
            "BrightnessContrastSettings",
            "LevelsAdjustmentSettings",
            "PosterizeSettings"
        ] {
            let body = try #require(Self.typeBody(named: typeName, in: mutationContracts))
            #expect(!body.contains("public var") || body.contains(".rawValue"), "\(typeName) should expose raw scalars as read-only projections")
        }
        for token in [
            "public var hueDegrees: Double =",
            "public var saturation: Double =",
            "public var brightness: Double =",
            "public var contrast: Double =",
            "public var inputBlack: Double =",
            "public var inputWhite: Double =",
            "public var gamma: Double =",
            "public var outputBlack: Double =",
            "public var outputWhite: Double =",
            "public var levels: Double ="
        ] {
            #expect(!mutationContracts.contains(token), "Adjustment settings should not store \(token)")
        }
        #expect(mutationContracts.contains("public struct HueAdjustmentDegrees"))
        #expect(mutationContracts.contains("public struct AdjustmentScale"))
        #expect(mutationContracts.contains("public struct AdjustmentOffset"))
        #expect(mutationContracts.contains("public let gammaValue: PositiveFiniteDouble"))
        #expect(mutationContracts.contains("public struct PosterizeLevelCount"))
        #expect(mutationContracts.contains("public let levelsValue: PosterizeLevelCount"))
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
            #expect(!body.contains("public init(unchecked"), "\(source.path) should keep unsafe constructors package-scoped")
            #expect(!body.contains("public static func unchecked"), "\(source.path) should keep unsafe factories package-scoped")
        }

        let workspaceDocumentTypes = try String(
            contentsOf: domainRoot.appendingPathComponent("WorkspaceDocumentTypes.swift"),
            encoding: .utf8
        )
        let relativePath = try #require(Self.typeBody(named: "RelativeProjectFolderPath", in: workspaceDocumentTypes))
        #expect(
            relativePath.contains("public init(validatingComponents components: [String]) throws"),
            "RelativeProjectFolderPath component construction should stay validating"
        )
        #expect(
            relativePath.contains("package static func unsafeUnchecked(components: [String])"),
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
            }
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

    private static func swiftImports(in source: String) -> Set<String> {
        let importKinds: Set<String> = [
            "class",
            "enum",
            "func",
            "let",
            "protocol",
            "struct",
            "typealias",
            "var"
        ]
        let code = Self.swiftCodeWithCommentsAndStringsBlanked(in: source)
        return Set(code.split(separator: "\n").compactMap { line in
            var trimmed = line.trimmingCharacters(in: .whitespaces)
            while trimmed.hasPrefix("@"),
                  let attributeEnd = trimmed.firstIndex(where: { $0 == " " || $0 == "\t" }) {
                trimmed = String(trimmed[attributeEnd...]).trimmingCharacters(in: .whitespaces)
            }
            guard trimmed.hasPrefix("import ") else { return nil }
            var parts = trimmed.dropFirst("import ".count)
                .split(whereSeparator: { $0 == " " || $0 == "." })
            guard let first = parts.first else { return nil }
            if importKinds.contains(String(first)) {
                parts.removeFirst()
            }
            return parts.first.map(String.init)
        })
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
        source.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("public ") else { return nil }
            let parts = trimmed.split(whereSeparator: { $0 == " " || $0 == ":" || $0 == "<" || $0 == "(" })
            guard let declarationIndex = parts.firstIndex(where: { part in
                part == "struct" ||
                    part == "enum" ||
                    part == "protocol" ||
                    part == "class" ||
                    part == "actor" ||
                    part == "typealias"
            }) else {
                return nil
            }
            let nameIndex = parts.index(after: declarationIndex)
            guard parts.indices.contains(nameIndex) else { return nil }
            return String(parts[nameIndex])
        }
    }

    private static func infrastructureProductNames(in source: String) -> [String] {
        PackageManifestProductParser.libraryProductNames(in: source)
            .filter { $0.hasSuffix("Infrastructure") }
    }

    private static func typeBody(named typeName: String, in source: String) -> String? {
        guard let declaration = source.range(of: "struct \(typeName)") ?? source.range(of: "enum \(typeName)") else {
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
        let repoRoot = try Self.repoRoot()
        let manifest = repoRoot.appendingPathComponent("Packages/PrimoModules/Package.swift", isDirectory: false)
        let body = try String(contentsOf: manifest, encoding: .utf8)
        return PackageManifestTargetParser.parseTargetDependencies(from: body)
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

private enum PackageManifestTargetParser {
    static func parseTargetDependencies(from manifest: String) -> [String: Set<String>] {
        var graph: [String: Set<String>] = [:]
        for block in targetBlocks(in: manifest) {
            guard let name = firstQuotedValue(after: "name:", in: block) else { continue }
            graph[name] = Set(dependencies(in: block))
        }
        return graph
    }

    private static func targetBlocks(in manifest: String) -> [String] {
        var blocks: [String] = []
        var searchStart = manifest.startIndex
        while let markerRange = manifest.range(of: ".target(", range: searchStart..<manifest.endIndex) {
            let openParen = manifest.index(before: markerRange.upperBound)
            guard let closeParen = matchingDelimiter(
                in: manifest,
                open: openParen,
                opening: "(",
                closing: ")"
            ) else {
                break
            }
            blocks.append(String(manifest[markerRange.lowerBound...closeParen]))
            searchStart = manifest.index(after: closeParen)
        }
        return blocks
    }

    private static func dependencies(in targetBlock: String) -> [String] {
        guard let dependenciesRange = targetBlock.range(of: "dependencies:"),
              let openBracket = targetBlock[dependenciesRange.upperBound...].firstIndex(of: "["),
              let closeBracket = matchingDelimiter(
                in: targetBlock,
                open: openBracket,
                opening: "[",
                closing: "]"
              )
        else {
            return []
        }
        return quotedStrings(in: String(targetBlock[openBracket...closeBracket]))
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
