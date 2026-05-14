import Foundation
import PrimoDocumentApplication
import PrimoDocumentMutationContracts
import PrimoDocumentRuntime
import Testing
@testable import PrimoDocumentEngineInfrastructure

struct DocumentRuntimeCompositionTests {
    @Test
    func runtimePresentationObservationPublishesInitialAndMutationSnapshots() async throws {
        let runtime = PrimoDocumentRuntime.DocumentRuntimeFactory.live()
        var iterator = runtime.observePresentation().makeAsyncIterator()

        let initial = await iterator.next()
        #expect(initial?.canvasSize.width != 3)

        let outcome = await runtime.execute(.canvas(.create(width: 3, height: 3)))
        guard case .mutation(.success) = outcome else {
            Issue.record("Expected create command to succeed")
            return
        }

        let updated = await iterator.next()
        #expect(updated?.canvasSize.width == 3)
        #expect(updated?.canvasSize.height == 3)
    }

    @Test
    func editingGatewayExecutesLayerRequestsThroughSharedRuntime() throws {
        let runtime = PrimoDocumentEngineInfrastructure.DocumentRuntimeCompositionFactory.live()

        let addResult = runtime.editingGateway.execute(
            .structure(.addLayer(name: "Foreground"))
        )
        let addPlan = try addResult.get()
        guard case let .structure(structurePlan) = addPlan else {
            Issue.record("Expected structure plan")
            return
        }
        #expect(structurePlan.resultingIndex == 1)

        let renameResult = runtime.editingGateway.execute(
            .attribute(.setLayerName(index: 1, name: "Ink"))
        )
        _ = try renameResult.get()

        let presentation = runtime.queryGateway.lightweightPresentation()
        #expect(presentation.activeLayerIndex == 1)
        #expect(presentation.layerRows.count == 2)
        #expect(presentation.layerRows.first(where: { $0.index == 1 })?.name == "Ink")
    }

    @Test
    func compositionOverridesReturnNewBoundaryWhilePreservingSharedRuntime() throws {
        let runtime = PrimoDocumentEngineInfrastructure.DocumentRuntimeCompositionFactory.live()
        let overridden = runtime.withOverrides(
            historyGateway: DocumentHistoryGateway(
                canUndo: { false },
                canRedo: { false },
                undo: { .failure(.noUndoState) },
                redo: { .failure(.noRedoState) }
            )
        )

        _ = try overridden.editingGateway.execute(
            .structure(.addLayer(name: "Foreground"))
        ).get()

        let presentation = runtime.queryGateway.lightweightPresentation()
        #expect(presentation.layerRows.count == 2)
        #expect(overridden.historyGateway.canUndo() == false)
        #expect(runtime.historyGateway.canUndo())
    }

    @Test
    func compositionStoresGatewaysAsImmutablePublicBoundary() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let compositionURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeComposition.swift"
        )
        let body = try String(contentsOf: compositionURL, encoding: .utf8)

        #expect(body.contains("package struct DocumentRuntimeComposition"))
        #expect(body.contains("package let queryGateway: DocumentQueryGateway"))
        #expect(body.contains("package let renderGateway: DocumentRenderGateway"))
        #expect(body.contains("package let dirtyUpdateQueue: DocumentDirtyUpdateQueue"))
        #expect(body.contains("package let mutationGateway: DocumentMutationGateway"))
        #expect(body.contains("package let strokeGateway: StrokeInputGateway"))
        #expect(body.contains("package func withOverrides("))
        #expect(!body.contains("public let queryGateway: DocumentQueryGateway"))
        #expect(!body.contains("public func withOverrides("))
        #expect(!body.contains("public var queryGateway: DocumentQueryGateway"))
    }

    @Test
    func liveEditingGatewayRejectsStaleValidatedLayerIndexes() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let compositionURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeComposition.swift"
        )
        let body = try String(contentsOf: compositionURL, encoding: .utf8)

        #expect(body.contains("private func validateFreshLayerIndex(_ index: ExistingLayerIndex)"))
        #expect(body.contains("return .staleLayerIndex("))
        #expect(body.contains("validationRevision: index.revision"))
        #expect(body.contains("currentRevision: currentRevision"))
    }

    @Test
    func liveGatewayKeepsHeavyPersistenceAndExportWorkOutsideRuntimeLock() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let factoryURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentEngineLive.swift"
        )
        let body = try String(contentsOf: factoryURL, encoding: .utf8)

        #expect(body.contains("let snapshot = runtimeBox.withRuntime { $0.projectSaveSnapshot(paperStyle: paperStyle) }"))
        #expect(body.contains("try snapshot.write(to: url, fileClient: fileClient, uuidClient: uuidClient)"))
        #expect(!body.contains("try runtimeBox.withRuntime { session in\n                    try session.saveProject"))
        #expect(body.contains("SwiftDocumentRuntime.compositeExportSurface(\n                    forMaterializedSnapshot: snapshot"))
        #expect(body.contains("SwiftDocumentRuntime.compositePNGData(\n                    forMaterializedSnapshot: snapshot"))
    }

    @Test
    func lockedRuntimeBoxGuardsAgainstReentrantAccess() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let supportURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentInfrastructure/DocumentRuntimeSupport.swift"
        )
        let body = try String(contentsOf: supportURL, encoding: .utf8)

        #expect(body.contains("private var isExecuting = false"))
        #expect(body.contains("precondition(!isExecuting, \"Reentrant document runtime access\")"))
        #expect(body.contains("NSRecursiveLock()"))
    }

    @Test
    func runtimeFailureMappingPreservesTypedFailures() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let compositionURL = repoRoot.appendingPathComponent(
            "Packages/PrimoModules/Sources/PrimoDocumentEngineInfrastructure/DocumentRuntimeComposition.swift"
        )
        let body = try String(contentsOf: compositionURL, encoding: .utf8)

        #expect(body.contains("case let .alphaLocked(index):\n        return .alphaLocked(index)"))
        #expect(body.contains("case let .invalidCanvasSize(width, height):\n        return .invalidCanvasSize(width: width, height: height)"))
        #expect(body.contains("case .emptyInput:\n        return .emptyInput"))
        #expect(body.contains("case .noUndoState:\n        return .noUndoState"))
        #expect(body.contains("case let .incompatibleLayerType(index):\n        return .incompatibleLayerType(index)"))
        #expect(!body.contains("bridgeMutationFailed(\"alphaLocked\")"))
        #expect(!body.contains("bridgeMutationFailed(\"invalidCanvasSize\")"))
        #expect(!body.contains("bridgeMutationFailed(\"emptyInput\")"))
        #expect(!body.contains("bridgeMutationFailed(\"noUndoState\")"))
        #expect(!body.contains("bridgeMutationFailed(\"incompatibleLayerType\")"))
    }
}
