import Foundation
import PrimoCoreTypes
import PrimoDocumentContracts
import PrimoBrushRuntimeContracts
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import PrimoWorkspaceApplication
import PrimoWorkspaceInfrastructure
import XCTest

final class WorkspaceApplicationPerformanceTests: XCTestCase {
    func testSaveActiveDocumentPerformance() {
        let activeTab = OpenDocumentTab(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000111")!,
            title: "Perf",
            backingStoreURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/backing.atelier")),
            sourceProjectURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/source.atelier")),
            canvasSize: CGSize(width: 2048, height: 2048),
            isDirty: true,
            pane: .primary,
            previewImageData: Data(repeating: 0xAB, count: 4096)
        )
        let services = WorkspaceApplicationServices(
            documentPersistenceGateway: DocumentPersistenceGateway(
                saveProject: { _, _ in },
                loadProject: { _ in
                    LoadedPaintProject(
                        presentation: PaintDocumentPresentation(canvasSize: .zero, activeLayerIndex: 0, layerRows: [], layerSidebarRows: [], renderSnapshot: nil),
                        paperStyle: .default
                    )
                },
                setPaperStyle: { _ in },
                newCanvas: { _, _ in },
                prewarmDrawingResources: {}
            ),
            documentWorkspaceClient: DocumentWorkspaceClient(
                createTabBackingStoreURL: { id in
                    DocumentProjectPath(URL(fileURLWithPath: "/tmp/\(id.uuidString).atelier"))
                },
                createProjectURL: {
                    DocumentProjectPath(URL(fileURLWithPath: "/tmp/project.atelier"))
                },
                writePNGToTemporaryDirectory: { _ in
                    URL(fileURLWithPath: "/tmp/export.png")
                },
                timelapseTemporaryDirectory: {
                    URL(fileURLWithPath: "/tmp")
                },
                loadSavedProjects: { [] },
                moveSavedProject: { url, _ in url },
                loadAutosaveRecoveryItems: { [] },
                discardAutosaveEntry: { _ in },
                discardAutosaveSnapshot: { _ in },
                persistAutosaveSnapshot: { _, _ in },
                persistProjectSnapshot: { sourceURL, preferredDestinationURL in
                    preferredDestinationURL ?? sourceURL
                },
                loadSaveHistoryEntries: { _ in [] },
                persistSaveHistorySnapshot: { _, _, _ in },
                removeWorkspaceItem: { _ in }
            ),
            uuidClient: UUIDClient(generate: UUID.init)
        )
        let request = WorkspacePersistenceRequest.saveActiveDocument(
            WorkspaceDocumentSaveRequest(
                activeTab: activeTab,
                paperStyle: .default,
                preferredDestinationURL: nil,
                trigger: .manualSave,
                purpose: .saveDocument
            )
        )

        measure {
            let result = services.persistenceUseCase.execute(request)
            switch result {
            case let .success(.activeDocumentSaved(saveResult)):
                XCTAssertEqual(saveResult.activeTabID, activeTab.id)
                XCTAssertEqual(saveResult.savedURL, activeTab.backingStoreURL)
            default:
                XCTFail("Expected saveActiveDocument to succeed during performance measurement")
            }
        }
    }
}
