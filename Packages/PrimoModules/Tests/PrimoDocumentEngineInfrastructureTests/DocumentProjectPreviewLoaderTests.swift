import CoreGraphics
import Foundation
import PrimoCoreTypes
import PrimoDocumentDomain
import PrimoDocumentMetalRuntimeInfrastructure
import Testing
@testable import PrimoDocumentEngineInfrastructure
import PrimoDocumentRuntimeLive

struct DocumentProjectPreviewLoaderTests {
    @Test
    func loadProjectValidatesPackageBeforeReadingManifestReferences() throws {
        let outsideURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("primo-outside-\(UUID().uuidString).rgba", isDirectory: false)
        try Data([1, 2, 3, 4]).write(to: outsideURL)
        defer { try? FileManager.default.removeItem(at: outsideURL) }

        let projectURLs = try [
            makeProjectPackage(layers: [layer(pixelFilename: "../outside.rgba")]),
            makeProjectPackage(layers: [layer(pixelFilename: outsideURL.path)]),
            makeSymlinkLayerProject(outsideURL: outsideURL),
            makeProjectPackage(layers: [
                layer(index: 0, pixelFilename: "Layers/layer0.rgba"),
                layer(index: 0, pixelFilename: "Layers/layer0.rgba"),
            ]),
            makeProjectPackage(layers: [layer(index: 1, pixelFilename: "Layers/layer0.rgba")]),
            makeProjectPackage(layers: [layer(folderID: 99)]),
            makeProjectPackage(folders: [
                folder(id: 1, anchorLayerIndex: 2),
            ]),
            makeOversizedLayerBudgetProject(),
            makeOversizedTimelapsePayloadProject(),
        ]
        defer {
            for projectURL in projectURLs {
                try? FileManager.default.removeItem(at: projectURL)
            }
        }

        for projectURL in projectURLs {
            #expect(throws: Error.self, "Expected validation failure for \(projectURL.lastPathComponent)") {
                _ = try SwiftDocumentRuntime.loadProject(
                    from: projectURL,
                    gpuServices: DocumentRuntimeGpuServicesFactory.live()
                )
            }
        }
    }

    @Test
    func loadPreviewRejectsInvalidPackageThroughRuntimeValidator() throws {
        let projectURL = try makeProjectPackage(layers: [
            layer(pixelFilename: "../outside.rgba"),
        ])
        defer { try? FileManager.default.removeItem(at: projectURL) }

        #expect(throws: Error.self) {
            _ = try DocumentProjectPreviewLoader.loadPreview(from: projectURL)
        }
    }

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
        try runtime.persistenceGateway.saveProject(WritableProjectLocation(firstURL), .default)

        runtime.persistenceGateway.newCanvas(2, 2)
        try replaceLayer(in: runtime, rgba: [0, 0, 255, 255])
        try runtime.persistenceGateway.saveProject(WritableProjectLocation(secondURL), .default)

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

        let activePixels = try runtime.renderGateway.pixelDataForLayer(0).get()
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
        try initialRuntime.persistenceGateway.saveProject(WritableProjectLocation(projectURL), .default)
        let originalFingerprint = try fileFingerprint(at: projectURL)

        let failingRuntime = DocumentEngineFactory.live(
            fileClient: failingManifestWriteFileClient(),
            uuidClient: UUIDClient(generate: { UUID(uuidString: "00000000-0000-0000-0000-000000000333")! })
        )
        failingRuntime.persistenceGateway.newCanvas(2, 2)
        try replaceLayer(in: failingRuntime, rgba: [0, 0, 255, 255])

        #expect(throws: Error.self) {
            try failingRuntime.persistenceGateway.saveProject(WritableProjectLocation(projectURL), .default)
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

    private func makeProjectPackage(
        canvasWidth: Int = 1,
        canvasHeight: Int = 1,
        activeLayerIndex: Int = 0,
        layers: [[String: Any]]? = nil,
        folders: [[String: Any]] = [],
        timelapseOperations: [[String: Any]] = []
    ) throws -> URL {
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("primo-package-\(UUID().uuidString).primo", isDirectory: true)
        try FileManager.default.createDirectory(
            at: projectURL.appendingPathComponent("Layers", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: projectURL.appendingPathComponent("TimelapseData", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0, 0, 0, 0]).write(
            to: projectURL.appendingPathComponent("Layers/layer0.rgba", isDirectory: false)
        )

        let manifest: [String: Any] = [
            "version": 1,
            "canvasWidth": canvasWidth,
            "canvasHeight": canvasHeight,
            "activeLayerIndex": activeLayerIndex,
            "paperStyle": [
                "red": 1,
                "green": 1,
                "blue": 1,
                "alpha": 1,
                "isTransparent": false,
            ],
            "layers": layers ?? [layer()],
            "folders": folders,
            "timelapseFrames": [],
            "timelapseOperations": timelapseOperations,
        ]
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
        try manifestData.write(to: projectURL.appendingPathComponent("manifest.json", isDirectory: false))
        return projectURL
    }

    private func makeSymlinkLayerProject(outsideURL: URL) throws -> URL {
        let projectURL = try makeProjectPackage()
        try FileManager.default.removeItem(
            at: projectURL.appendingPathComponent("Layers/layer0.rgba", isDirectory: false)
        )
        try FileManager.default.createSymbolicLink(
            at: projectURL.appendingPathComponent("Layers/layer0.rgba", isDirectory: false),
            withDestinationURL: outsideURL
        )
        return projectURL
    }

    private func makeOversizedLayerBudgetProject() throws -> URL {
        let layers = (0..<5).map {
            layer(index: $0, pixelFilename: "Layers/layer0.rgba")
        }
        return try makeProjectPackage(canvasWidth: 8192, canvasHeight: 8192, layers: layers)
    }

    private func makeOversizedTimelapsePayloadProject() throws -> URL {
        let projectURL = try makeProjectPackage(timelapseOperations: [
            [
                "kind": "replaceLayerPixels",
                "layerIndex": 0,
                "dataFilename": "TimelapseData/payload.bin",
            ],
        ])
        let payloadURL = projectURL.appendingPathComponent("TimelapseData/payload.bin", isDirectory: false)
        FileManager.default.createFile(atPath: payloadURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: payloadURL)
        try handle.truncate(atOffset: UInt64(512 * 1024 * 1024 + 1))
        try handle.close()
        return projectURL
    }

    private func layer(
        index: Int = 0,
        folderID: Int? = nil,
        pixelFilename: String = "Layers/layer0.rgba"
    ) -> [String: Any] {
        var value: [String: Any] = [
            "index": index,
            "name": "Layer \(index)",
            "visible": true,
            "locked": false,
            "alphaLocked": false,
            "clipped": false,
            "opacity": 1,
            "blendMode": "normal",
            "pixelFilename": pixelFilename,
        ]
        if let folderID {
            value["folderID"] = folderID
        }
        return value
    }

    private func folder(id: Int, anchorLayerIndex: Int) -> [String: Any] {
        [
            "id": id,
            "name": "Folder \(id)",
            "visible": true,
            "expanded": true,
            "anchorLayerIndex": anchorLayerIndex,
        ]
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
