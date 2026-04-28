import CoreGraphics
import Foundation
import PrimoCoreTypes
import PrimoDocumentDomain
import PrimoDocumentMetalRuntimeInfrastructure
import Testing
@testable import PrimoDocumentEngineInfrastructure

struct DocumentProjectPreviewLoaderTests {
    @Test
    func loadPreviewReadsProjectWithoutReplacingActiveRuntime() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let firstURL = root.appendingPathComponent("first.atelier", isDirectory: true)
        let secondURL = root.appendingPathComponent("second.atelier", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let runtime = DocumentEngineFactory.live()
        runtime.persistenceGateway.newCanvas(2, 2)
        try replaceLayer(in: runtime, rgba: [255, 0, 0, 255])
        try runtime.persistenceGateway.saveProject(firstURL, .default)

        runtime.persistenceGateway.newCanvas(2, 2)
        try replaceLayer(in: runtime, rgba: [0, 0, 255, 255])
        try runtime.persistenceGateway.saveProject(secondURL, .default)

        try replaceLayer(in: runtime, rgba: [255, 0, 0, 255])

        let preview = try DocumentProjectPreviewLoader.loadPreview(from: secondURL)

        #expect(preview.canvasSize == CGSize(width: 2, height: 2))
        #expect(preview.layerCount == 1)
        if PrimoMetalDocumentProcessingClient.shared.isAvailable {
            let surface = try #require(preview.previewSurface)
            #expect(surface.width == 2)
            #expect(surface.height == 2)
            #expect(surface.pixelData.contains(255))
        }

        let activePixels = runtime.queryGateway.pixelDataForLayer(0)
        #expect(activePixels.prefix(4).elementsEqual([255, 0, 0, 255]))
    }

    @Test
    func saveProjectFailureWhileWritingStagingKeepsExistingProjectIntact() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let projectURL = root.appendingPathComponent("project.atelier", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let initialRuntime = DocumentEngineFactory.live()
        initialRuntime.persistenceGateway.newCanvas(2, 2)
        try replaceLayer(in: initialRuntime, rgba: [255, 0, 0, 255])
        try initialRuntime.persistenceGateway.saveProject(projectURL, .default)
        let originalFingerprint = try fileFingerprint(at: projectURL)

        let failingRuntime = DocumentEngineFactory.live(
            fileClient: failingManifestWriteFileClient(),
            uuidClient: UUIDClient(generate: { UUID(uuidString: "00000000-0000-0000-0000-000000000333")! })
        )
        failingRuntime.persistenceGateway.newCanvas(2, 2)
        try replaceLayer(in: failingRuntime, rgba: [0, 0, 255, 255])

        #expect(throws: Error.self) {
            try failingRuntime.persistenceGateway.saveProject(projectURL, .default)
        }

        #expect(try fileFingerprint(at: projectURL) == originalFingerprint)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(".primo-staging").path))
        let preview = try DocumentProjectPreviewLoader.loadPreview(from: projectURL)
        #expect(preview.canvasSize == CGSize(width: 2, height: 2))
        #expect(preview.layerCount == 1)
    }

    private func replaceLayer(
        in runtime: DocumentEngineLive,
        rgba: [UInt8]
    ) throws {
        let data = Data(Array(repeating: rgba, count: 4).flatMap { $0 })
        switch runtime.mutationGateway.replaceLayerPixels(0, data) {
        case .success:
            break
        case let .failure(failure):
            throw failure
        }
    }

    private func failingManifestWriteFileClient() -> FileClient {
        FileClient(
            temporaryDirectory: { FileManager.default.temporaryDirectory },
            urls: { FileManager.default.urls(for: $0, in: $1) },
            fileExists: { FileManager.default.fileExists(atPath: $0) },
            createDirectory: { try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: $1) },
            removeItem: { try FileManager.default.removeItem(at: $0) },
            copyItem: { try FileManager.default.copyItem(at: $0, to: $1) },
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
            readData: { try Data(contentsOf: $0) },
            writeData: { data, url, options in
                if url.lastPathComponent == "manifest.json", url.path.contains(".primo-staging") {
                    throw CocoaError(.fileWriteUnknown)
                }
                try data.write(to: url, options: options)
            }
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
