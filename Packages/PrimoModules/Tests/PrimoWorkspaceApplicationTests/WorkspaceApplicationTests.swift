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

        let result = try useCase.execute(.loadSavedProjects).get()
        #expect(result == .savedProjectsLoaded(expectedProjects))
    }

    @Test
    func loadedProjectFollowUpPlannerSkipsRedundantPersistence() {
        let planner = WorkspaceLoadedProjectFollowUpPlanner()
        let request = planner.request(
            plan: LoadedWorkspaceProjectPlan(
                destination: .activeTab(title: nil, sourceProjectURL: nil)
            ),
            context: WorkspaceDocumentReplacementRequest(
                activeTab: OpenDocumentTab(
                    id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
                    title: "Canvas",
                    backingStoreURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/backing.atelier")),
                    sourceProjectURL: nil,
                    canvasSize: .zero,
                    isDirty: false,
                    pane: .primary,
                    previewImageData: nil
                ),
                paperStyle: .default
            ),
            requiresBackingStorePersistence: false
        )

        #expect(request == nil)
    }

    @Test
    func loadedProjectFollowUpPlannerBuildsTypedPersistenceRequest() {
        let autosaveID = WorkspaceItemID(unchecked: "autosave-7")
        let planner = WorkspaceLoadedProjectFollowUpPlanner()
        let activeTab = OpenDocumentTab(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!,
            title: "Canvas",
            backingStoreURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/backing.atelier")),
            sourceProjectURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/source.atelier")),
            canvasSize: CGSize(width: 640, height: 480),
            isDirty: true,
            pane: .secondary,
            previewImageData: Data([0x01])
        )
        let successEffects = LoadedWorkspaceProjectPlan.SuccessEffects(
            discardedAutosaveEntryID: autosaveID,
            completion: .restoredAutosave
        )

        let request = planner.request(
            plan: LoadedWorkspaceProjectPlan(
                destination: .selectedTab(
                    tabID: activeTab.id,
                    pane: activeTab.pane
                ),
                followUp: .init(
                    marksTabDirty: true,
                    persistsToBackingStore: false,
                    persistsAutosave: true
                ),
                successEffects: successEffects
            ),
            context: WorkspaceDocumentReplacementRequest(
                activeTab: activeTab,
                paperStyle: .default
            ),
            requiresBackingStorePersistence: true
        )

        #expect(
            request == .loadedWorkspaceFollowUp(
                LoadedWorkspaceFollowUpPersistenceRequest(
                    activeTab: activeTab,
                    paperStyle: .default,
                    persistsToBackingStore: true,
                    persistsAutosave: true,
                    successEffects: successEffects
                )
            )
        )
    }
}
