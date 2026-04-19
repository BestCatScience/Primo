import Foundation
import PrimoWorkspaceInfrastructure
import XCTest
@testable import Primo

final class WorkspaceCatalogUseCaseTests: XCTestCase {
    func testLoadSavedProjectsReturnsTypedResult() {
        let expectedProjects = [
            SavedProjectSummary(
                url: DocumentProjectPath(URL(fileURLWithPath: "/tmp/a.atelier")),
                name: "A",
                relativeFolderPath: nil,
                modifiedAt: Date(timeIntervalSince1970: 0),
                canvasSize: CanvasFeature.defaultCanvasSize,
                layerCount: 1,
                previewImageData: nil,
            )
        ]
        let useCase = AppFeature.WorkspaceCatalogUseCase(
            workspaceCatalogService: AppFeature.WorkspaceCatalogService(
                documentWorkspaceClient: .stub(
                    loadSavedProjects: { expectedProjects }
                )
            )
        )

        XCTAssertEqual(
            useCase.execute(.loadSavedProjects),
            .success(.savedProjectsLoaded(expectedProjects))
        )
    }

    func testLoadAutosaveRecoveryReturnsTypedResult() {
        let expectedItems = [
            AutosaveRecoveryItem(
                id: .testValue("autosave"),
                title: "Recovered",
                sourceProjectURL: nil,
                autosaveProjectURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/recovered.atelier")),
                updatedAt: Date(timeIntervalSince1970: 0),
                previewImageData: nil
            )
        ]
        let useCase = AppFeature.WorkspaceCatalogUseCase(
            workspaceCatalogService: AppFeature.WorkspaceCatalogService(
                documentWorkspaceClient: .stub(
                    loadAutosaveRecoveryItems: { expectedItems }
                )
            )
        )

        XCTAssertEqual(
            useCase.execute(.loadAutosaveRecoveryItems),
            .success(.autosaveRecoveryItemsLoaded(expectedItems))
        )
    }

    func testLoadSaveHistoryReturnsTypedResult() {
        let activeTab = OpenDocumentTab.testValue()
        let expectedEntries = [
            SaveHistoryEntry(
                id: .testValue("history-1"),
                title: "Snapshot",
                projectURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/snapshot.atelier")),
                createdAt: Date(timeIntervalSince1970: 0),
                trigger: .manualSave,
                previewImageData: nil
            )
        ]
        let useCase = AppFeature.WorkspaceCatalogUseCase(
            workspaceCatalogService: AppFeature.WorkspaceCatalogService(
                documentWorkspaceClient: .stub(
                    loadSaveHistoryEntries: { tab in
                        XCTAssertEqual(tab, activeTab)
                        return expectedEntries
                    }
                )
            )
        )

        XCTAssertEqual(
            useCase.execute(
                .loadSaveHistoryEntries(
                    AppFeature.WorkspaceSaveHistoryLoadRequest(
                        activeTab: activeTab
                    )
                )
            ),
            .success(.saveHistoryEntriesLoaded(expectedEntries))
        )
    }

    func testMoveFailureRetainsRequestContext() {
        let sourceURL = DocumentProjectPath(URL(fileURLWithPath: "/tmp/source.atelier"))
        let request = AppFeature.WorkspaceCatalogRequest.moveSavedProject(
            AppFeature.WorkspaceSavedProjectMoveRequest(
                sourceURL: sourceURL,
                relativeFolderPath: nil,
                openTabID: nil
            )
        )
        let useCase = AppFeature.WorkspaceCatalogUseCase(
            workspaceCatalogService: AppFeature.WorkspaceCatalogService(
                documentWorkspaceClient: .stub(
                    moveSavedProject: { _, _ in
                        throw TestError.expected("move failed")
                    }
                )
            )
        )

        XCTAssertEqual(
            useCase.execute(request),
            .failure(
                AppFeature.WorkspaceCatalogFailure(
                    request: request,
                    reason: .moveSavedProjectFailed("move failed")
                )
            )
        )
    }
}
