import Foundation
import PrimoDocumentApplication
import Testing
@testable import PrimoDocumentEngineInfrastructure

struct DocumentRuntimeCompositionTests {
    @Test
    func editingGatewayExecutesLayerRequestsThroughSharedRuntime() throws {
        let runtime = DocumentRuntimeCompositionFactory.live()

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
