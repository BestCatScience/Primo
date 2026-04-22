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
}
