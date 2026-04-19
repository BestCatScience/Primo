import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceApplication
import Testing

struct WorkspaceApplicationTests {
    @Test
    func catalogUseCaseForwardsGatewayResponses() throws {
        let expectedProjects = [
            SavedProjectSummary(
                url: DocumentProjectPath(URL(fileURLWithPath: "/tmp/a.atelier")),
                name: "A",
                relativeFolderPath: nil,
                modifiedAt: Date(timeIntervalSince1970: 0),
                canvasSize: .zero,
                layerCount: 1,
                previewImageData: nil
            )
        ]
        let useCase = WorkspaceCatalogUseCase(
            workspaceCatalog: WorkspaceCatalogGateway(
                loadSavedProjects: { expectedProjects },
                moveSavedProject: { sourceURL, _ in sourceURL },
                loadAutosaveRecoveryItems: { [] },
                discardAutosaveEntry: { _ in },
                loadSaveHistoryEntries: { _ in [] }
            )
        )

        let result = try #require(try useCase.execute(.loadSavedProjects).get())
        #expect(result == .savedProjectsLoaded(expectedProjects))
    }
}
