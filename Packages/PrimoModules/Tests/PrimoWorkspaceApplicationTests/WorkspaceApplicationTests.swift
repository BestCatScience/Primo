import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceApplication
import Testing

struct WorkspaceApplicationTests {
    @Test
    func catalogUseCaseForwardsGatewayResponses() throws {
        let previewSurface = DocumentCompositeSurface(
            width: 2,
            height: 1,
            pixelData: Data([0x10, 0x20, 0x30, 0xFF, 0x40, 0x50, 0x60, 0xFF])
        )
        let expectedProjects = [
            SavedProjectSummary(
                url: DocumentProjectPath(URL(fileURLWithPath: "/tmp/a.atelier")),
                name: "A",
                relativeFolderPath: nil,
                modifiedAt: Date(timeIntervalSince1970: 0),
                canvasSize: .zero,
                layerCount: 1,
                previewSurface: previewSurface,
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
        let previewSurface = DocumentCompositeSurface(
            width: 1,
            height: 1,
            pixelData: Data([0x01, 0x02, 0x03, 0xFF])
        )
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
            previewSurface: previewSurface,
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

    @Test
    func workflowServiceBuildsLoadedProjectFollowUpOutcome() throws {
        let activeTab = OpenDocumentTab(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000BC")!,
            title: "Canvas",
            backingStoreURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/backing.atelier")),
            sourceProjectURL: nil,
            canvasSize: CGSize(width: 320, height: 240),
            isDirty: false,
            pane: .primary,
            previewImageData: nil
        )
        let plan = LoadedWorkspaceProjectPlan(
            destination: .newTab(title: "Loaded", sourceProjectURL: nil),
            followUp: .init(
                marksTabDirty: true,
                persistsToBackingStore: false,
                persistsAutosave: true
            )
        )
        let service = WorkspaceApplicationWorkflowService()

        let outcome = try service.loadedWorkspaceFollowUp(
            plan: plan,
            context: WorkspaceDocumentContext(activeTab: activeTab, paperStyle: .default),
            requiresBackingStorePersistence: true
        ).get()

        #expect(outcome.marksActiveTabDirty)
        guard case let .loadedWorkspaceFollowUp(request)? = outcome.followUpRequest else {
            Issue.record("Expected loadedWorkspaceFollowUp request")
            return
        }
        #expect(request.activeTab == activeTab)
        #expect(request.persistsToBackingStore)
        #expect(request.persistsAutosave)
    }

    @Test
    func workflowServiceBuildsSaveActiveDocumentRequest() throws {
        let activeTab = OpenDocumentTab(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000BD")!,
            title: "Canvas",
            backingStoreURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/backing.atelier")),
            sourceProjectURL: nil,
            canvasSize: .zero,
            isDirty: true,
            pane: .primary,
            previewImageData: nil
        )
        let destination = DocumentProjectPath(URL(fileURLWithPath: "/tmp/destination.atelier"))
        let service = WorkspaceApplicationWorkflowService()

        let request = try service.saveActiveDocumentRequest(
            context: WorkspaceDocumentContext(activeTab: activeTab, paperStyle: .default),
            preferredDestinationURL: destination,
            trigger: .manualSave,
            purpose: .saveDocument
        ).get()

        #expect(
            request == .saveActiveDocument(
                WorkspaceDocumentSaveRequest(
                    activeTab: activeTab,
                    paperStyle: .default,
                    preferredDestinationURL: destination,
                    trigger: .manualSave,
                    purpose: .saveDocument
                )
            )
        )
    }

    @Test
    func workflowServiceCloseTabsIncludesActiveReplacementContext() throws {
        let activeTab = OpenDocumentTab(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000BE")!,
            title: "Canvas",
            backingStoreURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/backing.atelier")),
            sourceProjectURL: nil,
            canvasSize: .zero,
            isDirty: true,
            pane: .primary,
            previewImageData: nil
        )
        let service = WorkspaceApplicationWorkflowService()

        let request = try service.closeTabsPersistenceRequest(
            operation: .tab(activeTab.id),
            tabs: [activeTab],
            activeTabContext: WorkspaceDocumentContext(activeTab: activeTab, paperStyle: .default)
        ).get()

        guard case let .saveTabsForClose(closeRequest) = request else {
            Issue.record("Expected saveTabsForClose request")
            return
        }
        #expect(closeRequest.tabs == [activeTab])
        #expect(closeRequest.activeTab?.activeTab == activeTab)
        #expect(closeRequest.activeTab?.paperStyle == .default)
    }

    @Test
    func saveActiveDocumentResultPreservesPreviewSurface() throws {
        let previewSurface = DocumentCompositeSurface(
            width: 2,
            height: 2,
            pixelData: Data(repeating: 0x7F, count: 16)
        )
        let activeTab = OpenDocumentTab(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000CC")!,
            title: "Canvas",
            backingStoreURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/backing.atelier")),
            sourceProjectURL: nil,
            canvasSize: CGSize(width: 256, height: 256),
            isDirty: true,
            pane: .primary,
            previewSurface: previewSurface,
            previewImageData: nil
        )
        let useCase = WorkspacePersistenceUseCase(
            workspaceBackingStore: WorkspaceBackingStoreGateway(
                saveProject: { _, _ in },
                persistProjectSnapshot: { _, preferredDestinationURL in
                    preferredDestinationURL ?? DocumentProjectPath(URL(fileURLWithPath: "/tmp/saved.atelier"))
                },
                createTabBackingStoreURL: { _ in fatalError("unused") },
                persistAutosaveSnapshot: { _, _ in },
                discardAutosaveSnapshot: { _ in },
                persistSaveHistorySnapshot: { _, _, _ in },
                removeWorkspaceItem: { _ in }
            ),
            workspaceCatalog: WorkspaceCatalogGateway(
                loadSavedProjects: { [] },
                moveSavedProject: { sourceURL, _ in sourceURL },
                loadAutosaveRecoveryItems: { [] },
                discardAutosaveEntry: { _ in },
                loadSaveHistoryEntries: { _ in [] }
            ),
            identityGenerator: WorkspaceIdentityGenerator(generateTabID: { UUID() })
        )

        let result = try useCase.execute(
            .saveActiveDocument(
                WorkspaceDocumentSaveRequest(
                    activeTab: activeTab,
                    paperStyle: .default,
                    preferredDestinationURL: nil,
                    trigger: .manualSave,
                    purpose: .saveDocument
                )
            )
        ).get()

        guard case let .activeDocumentSaved(saved) = result else {
            Issue.record("Expected activeDocumentSaved result")
            return
        }
        #expect(saved.previewSurface == previewSurface)
        #expect(saved.previewImageData == nil)
    }
}
