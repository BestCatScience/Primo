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
    func createProjectURLIncludesUUIDToAvoidSameSecondCollisions() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let documents = root.appendingPathComponent("Documents", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let generatedIDs = UUIDSequence([
            UUID(uuidString: "00000000-0000-0000-0000-000000000111")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000222")!,
        ])
        let client = DocumentWorkspaceClient.live(
            fileClient: fileClient(documentsDirectory: documents),
            dateClient: DateClient(now: { Date(timeIntervalSince1970: 20) }),
            uuidClient: UUIDClient(generate: { generatedIDs.next() }),
            previewGateway: previewGateway()
        )

        let firstURL = try client.createProjectURL()
        let secondURL = try client.createProjectURL()
        let firstName = firstURL.fileURL.lastPathComponent
        let secondName = secondURL.fileURL.lastPathComponent

        #expect(firstURL.fileURL != secondURL.fileURL)
        #expect(firstName.hasPrefix("primo-"))
        #expect(firstName.hasSuffix("-00000000-0000-0000-0000-000000000111.atelier"))
        #expect(secondName.hasPrefix("primo-"))
        #expect(secondName.hasSuffix("-00000000-0000-0000-0000-000000000222.atelier"))
        #expect(firstName.dropLast("-00000000-0000-0000-0000-000000000111.atelier".count) == secondName.dropLast("-00000000-0000-0000-0000-000000000222.atelier".count))
    }

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
            unsafeUncheckedWidth: 1,
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

    @Test
    func persistProjectSnapshotCopyFailurePreservesExistingDestination() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let documents = root.appendingPathComponent("Documents", isDirectory: true)
        let sourceURL = root.appendingPathComponent("source.atelier", isDirectory: true)
        let destinationURL = root.appendingPathComponent("destination.atelier", isDirectory: true)
        try writeMinimalProject(at: sourceURL, byte: 0x20)
        try writeMinimalProject(at: destinationURL, byte: 0x10)
        let originalFingerprint = try fileFingerprint(at: destinationURL)
        defer { try? FileManager.default.removeItem(at: root) }

        let client = DocumentWorkspaceClient.live(
            fileClient: fileClient(
                documentsDirectory: documents,
                copyItem: { source, destination in
                    if destination.path.contains(".primo-staging") {
                        throw CocoaError(.fileWriteUnknown)
                    }
                    try FileManager.default.copyItem(at: source, to: destination)
                }
            ),
            dateClient: DateClient(now: { Date(timeIntervalSince1970: 20) }),
            uuidClient: UUIDClient(generate: { UUID(uuidString: "00000000-0000-0000-0000-000000000444")! }),
            previewGateway: previewGateway()
        )

        #expect(throws: Error.self) {
            _ = try client.persistProjectSnapshot(
                DocumentProjectPath(sourceURL),
                DocumentProjectPath(destinationURL)
            )
        }

        #expect(try fileFingerprint(at: destinationURL) == originalFingerprint)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(".primo-staging").path))
    }

    @Test
    func persistProjectSnapshotValidationFailurePreservesExistingDestination() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let documents = root.appendingPathComponent("Documents", isDirectory: true)
        let sourceURL = root.appendingPathComponent("source.atelier", isDirectory: true)
        let destinationURL = root.appendingPathComponent("destination.atelier", isDirectory: true)
        try writeMinimalProject(at: sourceURL, byte: 0x20)
        try FileManager.default.removeItem(
            at: sourceURL
                .appendingPathComponent("Layers", isDirectory: true)
                .appendingPathComponent("layer-0000.rgba", isDirectory: false)
        )
        try writeMinimalProject(at: destinationURL, byte: 0x10)
        let originalFingerprint = try fileFingerprint(at: destinationURL)
        defer { try? FileManager.default.removeItem(at: root) }

        let client = DocumentWorkspaceClient.live(
            fileClient: fileClient(documentsDirectory: documents),
            dateClient: DateClient(now: { Date(timeIntervalSince1970: 20) }),
            uuidClient: UUIDClient(generate: { UUID(uuidString: "00000000-0000-0000-0000-000000000555")! }),
            previewGateway: previewGateway()
        )

        #expect(throws: Error.self) {
            _ = try client.persistProjectSnapshot(
                DocumentProjectPath(sourceURL),
                DocumentProjectPath(destinationURL)
            )
        }

        #expect(try fileFingerprint(at: destinationURL) == originalFingerprint)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(".primo-staging").path))
    }

    @Test
    func persistProjectSnapshotRestoresExistingDestinationWhenPublishedPackageValidationFails() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let documents = root.appendingPathComponent("Documents", isDirectory: true)
        let sourceURL = root.appendingPathComponent("source.atelier", isDirectory: true)
        let destinationURL = root.appendingPathComponent("destination.atelier", isDirectory: true)
        try writeMinimalProject(at: sourceURL, byte: 0x20)
        try writeMinimalProject(at: destinationURL, byte: 0x10)
        let originalFingerprint = try fileFingerprint(at: destinationURL)
        defer { try? FileManager.default.removeItem(at: root) }

        let client = DocumentWorkspaceClient.live(
            fileClient: fileClient(
                documentsDirectory: documents,
                readData: { url in
                    if url.standardizedFileURL == destinationURL
                        .appendingPathComponent("manifest.json", isDirectory: false)
                        .standardizedFileURL {
                        throw CocoaError(.fileReadUnknown)
                    }
                    return try Data(contentsOf: url)
                }
            ),
            dateClient: DateClient(now: { Date(timeIntervalSince1970: 20) }),
            uuidClient: UUIDClient(generate: { UUID(uuidString: "00000000-0000-0000-0000-000000000666")! }),
            previewGateway: previewGateway()
        )

        #expect(throws: Error.self) {
            _ = try client.persistProjectSnapshot(
                DocumentProjectPath(sourceURL),
                DocumentProjectPath(destinationURL)
            )
        }

        #expect(try fileFingerprint(at: destinationURL) == originalFingerprint)
        #expect(try fileFingerprint(at: sourceURL)["Layers/layer-0000.rgba"] == Data([0x20, 0x20, 0x20, 0xFF]))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(".primo-staging").path))
    }

    private func fileClient(
        documentsDirectory: URL,
        copyItem: @escaping @Sendable (URL, URL) throws -> Void = {
            try FileManager.default.copyItem(at: $0, to: $1)
        },
        readData: @escaping @Sendable (URL) throws -> Data = { try Data(contentsOf: $0) }
    ) -> FileClient {
        FileClient(
            temporaryDirectory: { FileManager.default.temporaryDirectory },
            urls: { directory, _ in
                directory == .documentDirectory ? [documentsDirectory] : FileManager.default.urls(for: directory, in: .userDomainMask)
            },
            fileExists: { FileManager.default.fileExists(atPath: $0) },
            createDirectory: { try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: $1) },
            removeItem: { try FileManager.default.removeItem(at: $0) },
            copyItem: copyItem,
            moveItem: { try FileManager.default.moveItem(at: $0, to: $1) },
            replaceItem: { destinationURL, replacementURL, backupItemName in
                _ = try FileManager.default.replaceItemAt(
                    destinationURL,
                    withItemAt: replacementURL,
                    backupItemName: backupItemName,
                    options: backupItemName == nil ? [] : [.withoutDeletingBackupItem]
                )
            },
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
            readData: readData,
            writeData: { try $0.write(to: $1, options: $2) }
        )
    }

    private func previewGateway() -> DocumentWorkspacePreviewGateway {
        DocumentWorkspacePreviewGateway(
            loadProjectPreview: { _ in
                DocumentWorkspacePreview(
                    canvasSize: CGSize(width: 1, height: 1),
                    layerCount: 1,
                    previewSurface: nil,
                    previewImageData: nil
                )
            }
        )
    }

    private func writeMinimalProject(at url: URL, byte: UInt8) throws {
        let layersURL = url.appendingPathComponent("Layers", isDirectory: true)
        try FileManager.default.createDirectory(at: layersURL, withIntermediateDirectories: true)
        try Data([byte, byte, byte, 0xFF]).write(
            to: layersURL.appendingPathComponent("layer-0000.rgba", isDirectory: false)
        )
        let manifest = """
        {
          "version" : 5,
          "canvasWidth" : 1,
          "canvasHeight" : 1,
          "activeLayerIndex" : 0,
          "paperStyle" : {
            "red" : 1,
            "green" : 1,
            "blue" : 1,
            "alpha" : 1,
            "isTransparent" : false
          },
          "layers" : [
            {
              "index" : 0,
              "name" : "Layer 1",
              "visible" : true,
              "locked" : false,
              "alphaLocked" : false,
              "clipped" : false,
              "opacity" : 1,
              "blendMode" : "normal",
              "pixelFilename" : "Layers/layer-0000.rgba"
            }
          ],
          "folders" : [],
          "timelapseFrames" : [],
          "timelapseOperations" : []
        }
        """
        try manifest.data(using: .utf8)!.write(
            to: url.appendingPathComponent("manifest.json", isDirectory: false)
        )
    }

    private func fileFingerprint(at root: URL) throws -> [String: Data] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )
        var fingerprint: [String: Data] = [:]
        for url in urls {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                let nested = try fileFingerprint(at: url)
                for (path, data) in nested {
                    fingerprint["\(url.lastPathComponent)/\(path)"] = data
                }
            } else {
                fingerprint[url.lastPathComponent] = try Data(contentsOf: url)
            }
        }
        return fingerprint
    }
}

private final class UUIDSequence: @unchecked Sendable {
    private var ids: [UUID]

    init(_ ids: [UUID]) {
        self.ids = ids
    }

    func next() -> UUID {
        ids.removeFirst()
    }
}
