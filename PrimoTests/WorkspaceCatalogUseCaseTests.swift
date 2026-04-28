import Foundation
import PrimoCoreTypes
import PrimoDocumentDomain
import PrimoWorkspaceApplication
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
        let support = WorkspaceApplicationServices(
            documentPersistenceGateway: .stub(),
            documentWorkspaceClient: .stub(
                loadSavedProjects: { expectedProjects }
            ),
            uuidClient: UUIDClient(generate: UUID.init)
        )

        XCTAssertEqual(
            support.catalogUseCase.execute(.loadSavedProjects),
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
        let support = WorkspaceApplicationServices(
            documentPersistenceGateway: .stub(),
            documentWorkspaceClient: .stub(
                loadAutosaveRecoveryItems: { expectedItems }
            ),
            uuidClient: UUIDClient(generate: UUID.init)
        )

        XCTAssertEqual(
            support.catalogUseCase.execute(.loadAutosaveRecoveryItems),
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
        let support = WorkspaceApplicationServices(
            documentPersistenceGateway: .stub(),
            documentWorkspaceClient: .stub(
                loadSaveHistoryEntries: { tab in
                    XCTAssertEqual(tab, activeTab)
                    return expectedEntries
                }
            ),
            uuidClient: UUIDClient(generate: UUID.init)
        )

        XCTAssertEqual(
            support.catalogUseCase.execute(
                .loadSaveHistoryEntries(
                    DocumentFeatureRuntimeReducer.WorkspaceSaveHistoryLoadRequest(
                        activeTab: activeTab
                    )
                )
            ),
            .success(.saveHistoryEntriesLoaded(expectedEntries))
        )
    }

    func testMoveFailureRetainsRequestContext() {
        let sourceURL = DocumentProjectPath(URL(fileURLWithPath: "/tmp/source.atelier"))
        let request = DocumentFeatureRuntimeReducer.WorkspaceCatalogRequest.moveSavedProject(
            DocumentFeatureRuntimeReducer.WorkspaceSavedProjectMoveRequest(
                sourceURL: sourceURL,
                relativeFolderPath: nil,
                openTabID: nil
            )
        )
        let support = WorkspaceApplicationServices(
            documentPersistenceGateway: .stub(),
            documentWorkspaceClient: .stub(
                moveSavedProject: { _, _ in
                    throw TestError.expected("move failed")
                }
            ),
            uuidClient: UUIDClient(generate: UUID.init)
        )

        XCTAssertEqual(
            support.catalogUseCase.execute(request),
            .failure(
                DocumentFeatureRuntimeReducer.WorkspaceCatalogFailure(
                    request: request,
                    reason: .moveSavedProjectFailed("move failed")
                )
            )
        )
    }
}
