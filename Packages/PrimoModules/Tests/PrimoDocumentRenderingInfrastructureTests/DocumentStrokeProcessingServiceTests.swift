import Foundation
import PrimoDocumentContracts
import PrimoDocumentMetalStrokeInfrastructure
import Testing

struct DocumentStrokeProcessingServiceTests {
    @Test
    func stageCommittedSnapshotUsesProvidedCompositePixels() {
        let baseSnapshot = MetalDocumentSnapshot(
            width: 2,
            height: 2,
            revision: 3,
            compositePixelData: Data(repeating: 0x00, count: 16),
            layers: [
                MetalLayerSnapshot(
                    index: 0,
                    opacity: 1.0,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: Data(repeating: 0x11, count: 16)
                )
            ]
        )
        let committedPixels = Data(repeating: 0x22, count: 16)
        let stagedComposite = Data(repeating: 0x33, count: 16)
        let service = DocumentStrokeProcessingService()

        let staged = service.stageCommittedSnapshot(
            baseSnapshot: baseSnapshot,
            committedPixels: committedPixels,
            lastCommittedRenderRevision: 7,
            activeLayerIndex: 0,
            stagedCompositePixelData: stagedComposite
        )

        #expect(staged?.revision == 8)
        #expect(staged?.compositePixelData == stagedComposite)
        #expect(staged?.layers.first?.pixelData == committedPixels)
    }
}
