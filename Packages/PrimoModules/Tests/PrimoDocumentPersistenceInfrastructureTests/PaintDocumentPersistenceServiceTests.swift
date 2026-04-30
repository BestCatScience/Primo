import Foundation
import PrimoCoreTypes
import PrimoDocumentDomain
import PrimoDocumentPersistenceInfrastructure
import Testing

struct PaintDocumentPersistenceServiceTests {
    @Test
    func validateProjectPackageRejectsHiddenSymlinkTimelapseFrame() throws {
        let projectURL = try makeProjectPackage(
            timelapseFrames: [
                StoredPrimoDocument.TimelapseFrame(filename: "Timelapse/.frame", width: 1, height: 1),
            ]
        )
        defer { try? FileManager.default.removeItem(at: projectURL) }
        let outsideURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("primo-outside-\(UUID().uuidString).bin", isDirectory: false)
        try Data([1]).write(to: outsideURL)
        try FileManager.default.createSymbolicLink(
            at: projectURL.appendingPathComponent("Timelapse/.frame", isDirectory: false),
            withDestinationURL: outsideURL
        )
        defer { try? FileManager.default.removeItem(at: outsideURL) }

        #expect(throws: PaintDocumentPersistenceError.self) {
            try PaintDocumentPersistenceService(fileClient: .live).validateProjectPackage(at: projectURL)
        }
    }

    @Test
    func validateProjectPackageRejectsHiddenOversizedTimelapsePayload() throws {
        let projectURL = try makeProjectPackage(
            timelapseOperations: [
                StoredTimelapseOperation(
                    kind: .replaceLayerPixels,
                    layerIndex: .unchecked(0),
                    dataFilename: "TimelapseData/.payload"
                ),
            ]
        )
        defer { try? FileManager.default.removeItem(at: projectURL) }
        let payloadURL = projectURL.appendingPathComponent("TimelapseData/.payload", isDirectory: false)
        FileManager.default.createFile(atPath: payloadURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: payloadURL)
        try handle.truncate(atOffset: UInt64(512 * 1024 * 1024 + 1))
        try handle.close()

        #expect(throws: PaintDocumentPersistenceError.self) {
            try PaintDocumentPersistenceService(fileClient: .live).validateProjectPackage(at: projectURL)
        }
    }

    @Test
    func validateProjectPackageRejectsExcessiveTimelapsePayloadTotal() throws {
        let payloads = [
            "TimelapseData/payload0.bin",
            "TimelapseData/payload1.bin",
            "TimelapseData/payload2.bin",
        ]
        let projectURL = try makeProjectPackage(
            timelapseOperations: payloads.map {
                StoredTimelapseOperation(
                    kind: .replaceLayerPixels,
                    layerIndex: .unchecked(0),
                    dataFilename: $0
                )
            }
        )
        defer { try? FileManager.default.removeItem(at: projectURL) }
        for payload in payloads {
            let payloadURL = projectURL.appendingPathComponent(payload, isDirectory: false)
            FileManager.default.createFile(atPath: payloadURL.path, contents: nil)
            let handle = try FileHandle(forWritingTo: payloadURL)
            try handle.truncate(atOffset: UInt64(400 * 1024 * 1024))
            try handle.close()
        }

        #expect(throws: PaintDocumentPersistenceError.self) {
            try PaintDocumentPersistenceService(fileClient: .live).validateProjectPackage(at: projectURL)
        }
    }

    @Test
    func validateProjectPackageRejectsLayerCountOverMemoryBudget() throws {
        let layers = (0..<5).map { index in
            StoredPrimoDocument.Layer(
                index: .unchecked(index),
                name: "Layer \(index)",
                visible: true,
                locked: false,
                alphaLocked: false,
                clipped: false,
                opacity: 1,
                blendMode: "normal",
                folderID: nil,
                textLayer: nil,
                pixelFilename: "Layers/layer\(index).rgba",
                maskFilename: nil
            )
        }
        let projectURL = try makeProjectPackage(canvasWidth: 8192, canvasHeight: 8192, layers: layers)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        #expect(throws: PaintDocumentPersistenceError.self) {
            try PaintDocumentPersistenceService(fileClient: .live).validateProjectPackage(at: projectURL)
        }
    }

    @Test
    func validateProjectPackageAcceptsRegularTimelapseAssets() throws {
        let projectURL = try makeProjectPackage(
            timelapseFrames: [
                StoredPrimoDocument.TimelapseFrame(filename: "Timelapse/frame.bin", width: 1, height: 1),
            ],
            timelapseOperations: [
                StoredTimelapseOperation(
                    kind: .replaceLayerPixels,
                    layerIndex: .unchecked(0),
                    dataFilename: "TimelapseData/payload.bin"
                ),
            ]
        )
        defer { try? FileManager.default.removeItem(at: projectURL) }
        try Data([1, 2, 3]).write(to: projectURL.appendingPathComponent("Timelapse/frame.bin", isDirectory: false))
        try Data([4, 5, 6, 7]).write(to: projectURL.appendingPathComponent("TimelapseData/payload.bin", isDirectory: false))

        try PaintDocumentPersistenceService(fileClient: .live).validateProjectPackage(at: projectURL)
    }

    private func makeProjectPackage(
        canvasWidth: Int = 1,
        canvasHeight: Int = 1,
        layers: [StoredPrimoDocument.Layer]? = nil,
        timelapseFrames: [StoredPrimoDocument.TimelapseFrame] = [],
        timelapseOperations: [StoredTimelapseOperation] = []
    ) throws -> URL {
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("primo-package-\(UUID().uuidString).primo", isDirectory: true)
        try FileManager.default.createDirectory(
            at: projectURL.appendingPathComponent("Layers", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: projectURL.appendingPathComponent("Timelapse", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: projectURL.appendingPathComponent("TimelapseData", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0, 0, 0, 0]).write(to: projectURL.appendingPathComponent("Layers/layer0.rgba", isDirectory: false))
        let storedLayers = layers ?? [
            StoredPrimoDocument.Layer(
                index: .unchecked(0),
                name: "Layer 1",
                visible: true,
                locked: false,
                alphaLocked: false,
                clipped: false,
                opacity: 1,
                blendMode: "normal",
                folderID: nil,
                textLayer: nil,
                pixelFilename: "Layers/layer0.rgba",
                maskFilename: nil
            ),
        ]

        let document = StoredPrimoDocument(
            version: 1,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            activeLayerIndex: .unchecked(0),
            paperStyle: StoredPrimoDocument.PaperStyle(
                red: 1,
                green: 1,
                blue: 1,
                alpha: 1,
                isTransparent: false
            ),
            layers: storedLayers,
            folders: [],
            timelapseFrames: timelapseFrames,
            timelapseOperations: timelapseOperations
        )
        let manifestData = try JSONEncoder().encode(document)
        try manifestData.write(to: projectURL.appendingPathComponent("manifest.json", isDirectory: false))
        return projectURL
    }
}
