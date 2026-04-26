import CoreGraphics
import Foundation
import PrimoCoreTypes
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoWorkspaceInfrastructure
import Testing

private final class PreviewCallRecorder: @unchecked Sendable {
    private(set) var urls: [URL] = []

    func record(_ url: URL) {
        urls.append(url)
    }
}

private struct TestAutosaveMetadata: Encodable {
    let id: String
    let title: String
    let sourceProjectPath: String?
    let updatedAt: Date
}

struct DocumentWorkspaceClientAutosaveTests {
    @Test
    func loadAutosaveRecoveryItemsUsesPreviewGatewaySurface() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let documents = root.appendingPathComponent("Documents", isDirectory: true)
        let autosaveID = "autosave-preview"
        let autosaveDirectory = documents
            .appendingPathComponent("primo-projects", isDirectory: true)
            .appendingPathComponent(".primo-autosaves", isDirectory: true)
            .appendingPathComponent(autosaveID, isDirectory: true)
        let projectURL = autosaveDirectory.appendingPathComponent("project.atelier", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        let metadata = TestAutosaveMetadata(
            id: autosaveID,
            title: "Recovered",
            sourceProjectPath: nil,
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: autosaveDirectory.appendingPathComponent("metadata.json"))
        defer { try? FileManager.default.removeItem(at: root) }

        let previewSurface = DocumentCompositeSurface(
            width: 1,
            height: 1,
            pixelData: Data([0x10, 0x20, 0x30, 0xFF])
        )
        let recorder = PreviewCallRecorder()
        let client = DocumentWorkspaceClient.live(
            fileClient: fileClient(documentsDirectory: documents),
            dateClient: DateClient(now: { Date(timeIntervalSince1970: 20) }),
            uuidClient: UUIDClient(generate: { UUID(uuidString: "00000000-0000-0000-0000-000000000222")! }),
            previewGateway: DocumentWorkspacePreviewGateway(
                loadProjectPreview: { url in
                    recorder.record(url)
                    return DocumentWorkspacePreview(
                        canvasSize: CGSize(width: 2, height: 3),
                        layerCount: 4,
                        previewSurface: previewSurface,
                        previewImageData: nil
                    )
                }
            )
        )

        let items = try client.loadAutosaveRecoveryItems()

        let item = try #require(items.first)
        #expect(items.count == 1)
        #expect(item.title == "Recovered")
        #expect(item.autosaveProjectURL.fileURL == projectURL)
        #expect(item.previewSurface == previewSurface)
        #expect(item.previewImageData == nil)
        #expect(recorder.urls.map(\.standardizedFileURL) == [projectURL.standardizedFileURL])
    }

    @Test
    func loadAutosaveRecoveryItemsKeepsRestorableEntryWhenPreviewFails() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let documents = root.appendingPathComponent("Documents", isDirectory: true)
        let autosaveID = "autosave-preview-failed"
        let autosaveDirectory = documents
            .appendingPathComponent("primo-projects", isDirectory: true)
            .appendingPathComponent(".primo-autosaves", isDirectory: true)
            .appendingPathComponent(autosaveID, isDirectory: true)
        let projectURL = autosaveDirectory.appendingPathComponent("project.atelier", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        let metadata = TestAutosaveMetadata(
            id: autosaveID,
            title: "Recovered without preview",
            sourceProjectPath: nil,
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: autosaveDirectory.appendingPathComponent("metadata.json"))
        defer { try? FileManager.default.removeItem(at: root) }

        let recorder = PreviewCallRecorder()
        let client = DocumentWorkspaceClient.live(
            fileClient: fileClient(documentsDirectory: documents),
            dateClient: DateClient(now: { Date(timeIntervalSince1970: 20) }),
            uuidClient: UUIDClient(generate: { UUID(uuidString: "00000000-0000-0000-0000-000000000222")! }),
            previewGateway: DocumentWorkspacePreviewGateway(
                loadProjectPreview: { url in
                    recorder.record(url)
                    throw DocumentWorkspaceCatalogError.projectLoadFailed("preview unavailable")
                }
            )
        )

        let items = try client.loadAutosaveRecoveryItems()

        let item = try #require(items.first)
        #expect(items.count == 1)
        #expect(item.title == "Recovered without preview")
        #expect(item.autosaveProjectURL.fileURL == projectURL)
        #expect(item.previewSurface == nil)
        #expect(item.previewImageData == nil)
        #expect(recorder.urls.map(\.standardizedFileURL) == [projectURL.standardizedFileURL])
    }

    private func fileClient(documentsDirectory: URL) -> FileClient {
        FileClient(
            temporaryDirectory: { FileManager.default.temporaryDirectory },
            urls: { directory, _ in
                directory == .documentDirectory ? [documentsDirectory] : FileManager.default.urls(for: directory, in: .userDomainMask)
            },
            fileExists: { FileManager.default.fileExists(atPath: $0) },
            createDirectory: { try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: $1) },
            removeItem: { try FileManager.default.removeItem(at: $0) },
            copyItem: { try FileManager.default.copyItem(at: $0, to: $1) },
            moveItem: { try FileManager.default.moveItem(at: $0, to: $1) },
            contentsOfDirectory: {
                try FileManager.default.contentsOfDirectory(
                    at: $0,
                    includingPropertiesForKeys: $1,
                    options: $2
                )
            },
            enumerateURLs: { url, keys, options in
                guard let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: keys,
                    options: options
                ) else {
                    return []
                }
                return enumerator.compactMap { $0 as? URL }
            },
            readData: { try Data(contentsOf: $0) },
            writeData: { try $0.write(to: $1, options: $2) }
        )
    }
}
