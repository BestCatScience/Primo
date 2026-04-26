import CoreGraphics
import Foundation
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
}
