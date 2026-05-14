import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMetalRuntimeInfrastructure
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import Testing
@testable import PrimoDocumentEngineInfrastructure

struct SwiftDocumentStoreInvariantTests {
    @Test
    func snapshotRejectsEmptyLayerStack() throws {
        #expect(makeSnapshot(layers: []) == nil)
    }

    @Test
    func snapshotRejectsOutOfRangeActiveLayer() throws {
        let layer = try #require(makeLayer())

        #expect(makeSnapshot(activeLayerIndex: -1, layers: [layer]) == nil)
        #expect(makeSnapshot(activeLayerIndex: 1, layers: [layer]) == nil)
    }

    @Test
    func layerRejectsMismatchedPixelAndMaskBuffers() throws {
        let geometry = try #require(PixelGeometry(width: 2, height: 2))

        #expect(makeLayer(geometry: geometry, pixelData: Data(count: geometry.rgbaByteCount - 1)) == nil)
        #expect(makeLayer(geometry: geometry, maskData: Data(count: geometry.maskByteCount - 1)) == nil)
    }

    @Test
    func layerRejectsInvalidOpacity() throws {
        let geometry = try #require(PixelGeometry(width: 2, height: 2))

        #expect(makeLayer(geometry: geometry, opacity: .nan) == nil)
        #expect(makeLayer(geometry: geometry, opacity: -0.1) == nil)
        #expect(makeLayer(geometry: geometry, opacity: 1.1) == nil)
    }

    @Test
    func layerValidatedMutatorsPreserveExistingValuesOnFailure() throws {
        let geometry = try #require(PixelGeometry(width: 2, height: 2))
        var layer = try #require(makeLayer(geometry: geometry))
        let originalPixelData = layer.pixelData

        let rejectedOpacity = layer.setOpacity(.nan)
        #expect(!rejectedOpacity)
        #expect(layer.opacity == 1)
        let rejectedPixelData = layer.replacePixelData(Data(count: geometry.rgbaByteCount - 1), geometry: geometry)
        #expect(!rejectedPixelData)
        #expect(layer.pixelData == originalPixelData)
        let rejectedMaskData = layer.replaceMaskData(Data(count: geometry.maskByteCount - 1), geometry: geometry)
        #expect(!rejectedMaskData)
        #expect(layer.maskData == nil)
    }

    @Test
    func snapshotAccessorsRejectInvalidRawMutation() throws {
        let store = SwiftDocumentStore(width: 2, height: 2)
        var snapshot = store.snapshot
        let onePixelGeometry = try #require(PixelGeometry(width: 1, height: 1))
        let mismatchedLayer = try #require(makeLayer(geometry: onePixelGeometry))

        snapshot.activeLayerIndex = 4
        #expect(snapshot.activeLayerIndex == 0)
        snapshot.layers = []
        #expect(snapshot.layers.count == 1)
        snapshot.layers = [mismatchedLayer]
        #expect(snapshot.layers.count == 1)
        snapshot.revision = -1
        #expect(snapshot.revision == 0)
        snapshot.nextFolderID = -1
        #expect(snapshot.nextFolderID == 1)
    }

    @Test
    func validSnapshotFeedsLightweightPresentation() throws {
        let runtime = SwiftDocumentRuntime(
            width: 2,
            height: 2,
            gpuServices: Self.gpuServices()
        )

        let presentation = runtime.lightweightPresentation()

        #expect(presentation.canvasSize.width == 2)
        #expect(presentation.canvasSize.height == 2)
        #expect(presentation.activeLayerIndex == 0)
        #expect(presentation.layerRows.count == 1)
        #expect(presentation.layerRows[0].validatedOpacity?.rawValue == 1)
    }

    private func makeLayer(
        geometry: PixelGeometry? = PixelGeometry(width: 2, height: 2),
        opacity: Double = 1,
        pixelData: Data? = nil,
        maskData: Data? = nil
    ) -> SwiftDocumentLayerRecord? {
        guard let geometry else { return nil }
        return SwiftDocumentLayerRecord(
            name: "Layer",
            visible: true,
            locked: false,
            alphaLocked: false,
            clipped: false,
            opacity: opacity,
            blendMode: .normal,
            folderID: nil,
            textLayer: nil,
            geometry: geometry,
            pixelData: pixelData ?? Data(count: geometry.rgbaByteCount),
            maskData: maskData
        )
    }

    private func makeSnapshot(
        activeLayerIndex: Int = 0,
        layers: [SwiftDocumentLayerRecord]? = nil
    ) -> SwiftDocumentStoreSnapshot? {
        let geometry = PixelGeometry(width: 2, height: 2)!
        return SwiftDocumentStoreSnapshot(
            canvasWidth: geometry.width,
            canvasHeight: geometry.height,
            activeLayerIndex: activeLayerIndex,
            paperStyle: .default,
            revision: 0,
            nextFolderID: 1,
            layers: layers ?? [makeLayer(geometry: geometry)!],
            folders: [],
            thumbnailCache: [:],
            timelapseFrames: [],
            timelapseEvents: [],
            timelapseUsesOperationPersistence: true
        )
    }

    private static func gpuServices() -> DocumentRuntimeGpuServices {
        DocumentRuntimeGpuServices(
            release: { _ in },
            retain: { _ in false },
            _materializedPixelData: { _ in nil },
            _scaledPixelData: { data, _, _, targetWidth, targetHeight in
                Data(data.prefix(targetWidth * targetHeight * 4))
            },
            _scaledMaskData: { data, _, _, targetWidth, targetHeight in
                Data(data.prefix(targetWidth * targetHeight))
            },
            _translatedPixelData: { data, _, _, _, _, _, _ in data },
            _translatedMaskData: { data, _, _, _, _, _, _ in data },
            _applyLayerMask: { pixelData, _, _, _ in pixelData },
            _processLayer: { pixelData, width, height, _ in
                Self.payload(width: width, height: height, pixelData: pixelData)
            },
            _mergeLayers: { lower, _, _, _, _, _, _ in lower },
            _rasterizeTextLayer: { _, size in
                let width = Int(size.width)
                let height = Int(size.height)
                return Self.payload(width: width, height: height)
            },
            _blurPixels: { pixelData, _, width, height, _, _ in
                Self.payload(width: width, height: height, pixelData: pixelData)
            },
            _fillPixels: { pixelData, _, width, height, _, _ in
                Self.payload(width: width, height: height, pixelData: pixelData)
            },
            _commitStrokeMutation: { pixelData, _, width, height, _, _, _, _ in
                PrimoMetalStrokeMutationResult(
                    dirtyRect: (originX: 0, originY: 0, width: width, height: height),
                    gpuBufferHandle: nil,
                    rectPixelData: pixelData
                )
            },
            _preservingExistingAlphaBufferHandle: { sourceHandle, _, _, _, _ in sourceHandle },
            _compositedPaperPreviewRGBA: { pixelData, _, _, _ in pixelData },
            _compositedIncrementalUpdate: { _, dirtyRect in
                IncrementalLayerUpdate.unsafeUnchecked(
                    layerIndex: -1,
                    originX: dirtyRect.originX,
                    originY: dirtyRect.originY,
                    width: dirtyRect.width,
                    height: dirtyRect.height,
                    pixelData: Data(count: dirtyRect.width * dirtyRect.height * 4)
                )
            },
            _compositeDocumentSurface: { snapshot in
                DocumentCompositeSurface(
                    unsafeUncheckedWidth: snapshot.width,
                    height: snapshot.height,
                    pixelData: Data(count: snapshot.width * snapshot.height * 4)
                )
            },
            _compositeDocumentBufferHandle: { _ in nil }
        )
    }

    private static func payload(
        width: Int,
        height: Int,
        pixelData: Data? = nil
    ) -> DocumentLayerMutationPayload {
        let data = pixelData ?? Data(count: width * height * 4)
        return DocumentLayerMutationPayload.unsafeUnchecked(
            canvasWidth: width,
            canvasHeight: height,
            dirtyRect: LayerPixelRect.unsafeUnchecked(originX: 0, originY: 0, width: width, height: height),
            gpuBufferHandle: nil,
            rectPixelData: data,
            fullPixelData: data
        )
    }
}
