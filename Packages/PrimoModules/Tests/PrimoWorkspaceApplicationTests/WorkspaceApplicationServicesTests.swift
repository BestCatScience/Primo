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
import Testing

struct WorkspaceApplicationServicesTests {
    @Test
    func gatewaysForwardToUnderlyingServices() throws {
        let recorder = CallRecorder()
        let activeTab = OpenDocumentTab(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
            title: "Canvas",
            backingStoreURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/backing.atelier")),
            sourceProjectURL: DocumentProjectPath(URL(fileURLWithPath: "/tmp/source.atelier")),
            canvasSize: CGSize(width: 512, height: 512),
            isDirty: true,
            pane: .primary,
            previewImageData: nil
        )
        let services = WorkspaceApplicationServices(
            documentPersistenceGateway: DocumentPersistenceGateway(
                saveProject: { url, _ in
                    recorder.record("saveProject:\(url.path)")
                },
                loadProject: { _ in
                    LoadedPaintProject(
                        presentation: PaintDocumentPresentation(
                            canvasSize: .zero,
                            activeLayerIndex: 0,
                            layerRows: [],
                            layerSidebarRows: [],
                            renderSnapshot: nil
                        ),
                        paperStyle: .default
                    )
                },
                setPaperStyle: { _ in },
                newCanvas: { _, _ in },
                prewarmDrawingResources: {}
            ),
            documentWorkspaceClient: DocumentWorkspaceClient(
                createTabBackingStoreURL: { id in
                    recorder.record("createTabBackingStoreURL:\(id.uuidString)")
                    return DocumentProjectPath(URL(fileURLWithPath: "/tmp/\(id.uuidString).atelier"))
                },
                createProjectURL: {
                    DocumentProjectPath(URL(fileURLWithPath: "/tmp/project.atelier"))
                },
                writePNGToTemporaryDirectory: { data in
                    recorder.record("writePNG:\(data.count)")
                    return URL(fileURLWithPath: "/tmp/export.png")
                },
                timelapseTemporaryDirectory: {
                    recorder.record("timelapseTemporaryDirectory")
                    return URL(fileURLWithPath: "/tmp/timelapse")
                },
                loadSavedProjects: {
                    recorder.record("loadSavedProjects")
                    return []
                },
                moveSavedProject: { url, _ in
                    recorder.record("moveSavedProject:\(url.path)")
                    return url
                },
                loadAutosaveRecoveryItems: {
                    recorder.record("loadAutosaveRecoveryItems")
                    return []
                },
                discardAutosaveEntry: { id in
                    recorder.record("discardAutosaveEntry:\(id.rawValue)")
                },
                discardAutosaveSnapshot: { tab in
                    recorder.record("discardAutosaveSnapshot:\(tab.id.uuidString)")
                },
                persistAutosaveSnapshot: { url, tab in
                    recorder.record("persistAutosaveSnapshot:\(url.path):\(tab.id.uuidString)")
                },
                persistProjectSnapshot: { sourceURL, preferredDestinationURL in
                    let destinationPath = preferredDestinationURL?.path ?? "nil"
                    recorder.record("persistProjectSnapshot:\(sourceURL.path):\(destinationPath)")
                    return preferredDestinationURL ?? sourceURL
                },
                loadSaveHistoryEntries: { tab in
                    recorder.record("loadSaveHistoryEntries:\(tab.id.uuidString)")
                    return []
                },
                persistSaveHistorySnapshot: { url, tab, trigger in
                    recorder.record("persistSaveHistorySnapshot:\(url.path):\(tab.id.uuidString):\(trigger)")
                },
                removeWorkspaceItem: { url in
                    recorder.record("removeWorkspaceItem:\(url.path)")
                }
            ),
            uuidClient: UUIDClient(
                generate: {
                    UUID(uuidString: "00000000-0000-0000-0000-000000000999")!
                }
            )
        )

        try services.backingStoreGateway.saveProject(
            URL(fileURLWithPath: "/tmp/project.atelier"),
            CanvasPaperStyle.default
        )
        let generatedURL = try services.backingStoreGateway.createTabBackingStoreURL(activeTab.id)
        try services.backingStoreGateway.persistAutosaveSnapshot(generatedURL, activeTab)
        _ = try services.catalogGateway.loadSavedProjects()
        _ = try services.catalogGateway.loadSaveHistoryEntries(activeTab)
        try services.catalogGateway.discardAutosaveEntry(WorkspaceItemID(unchecked: "autosave-1"))
        let exportURL = try services.artifactService.writePNGToTemporaryDirectory(Data(repeating: 0xAB, count: 32))
        let tempDirectory = services.artifactService.timelapseTemporaryDirectory()
        let generatedID = services.identityGenerator.generateTabID()

        #expect(exportURL.path == "/tmp/export.png")
        #expect(tempDirectory.path == "/tmp/timelapse")
        #expect(generatedID.uuidString == "00000000-0000-0000-0000-000000000999")
        #expect(
            recorder.values == [
                "saveProject:/tmp/project.atelier",
                "createTabBackingStoreURL:00000000-0000-0000-0000-000000000123",
                "persistAutosaveSnapshot:/tmp/00000000-0000-0000-0000-000000000123.atelier:00000000-0000-0000-0000-000000000123",
                "loadSavedProjects",
                "loadSaveHistoryEntries:00000000-0000-0000-0000-000000000123",
                "discardAutosaveEntry:autosave-1",
                "writePNG:32",
                "timelapseTemporaryDirectory",
            ]
        )
    }
}

private final class CallRecorder: @unchecked Sendable {
    private(set) var values: [String] = []

    func record(_ value: String) {
        values.append(value)
    }
}
