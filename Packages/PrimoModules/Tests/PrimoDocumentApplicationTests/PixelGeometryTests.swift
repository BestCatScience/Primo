import Foundation
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts
import Testing

@Suite
struct PixelGeometryTests {
    @Test
    func rejectsInvalidAndOversizedDimensions() {
        #expect(PixelGeometry(width: 0, height: 1) == nil)
        #expect(PixelGeometry(width: -1, height: 1) == nil)
        #expect(PixelGeometry(width: Int.max, height: 2) == nil)
        #expect(PixelGeometry(width: 8192, height: 8192) != nil)
        #expect(PixelGeometry(width: 8193, height: 1) == nil)
        #expect(PixelGeometry(width: 1, height: 8193) == nil)
        #expect(PixelGeometry(width: 8192, height: 8192, maxPixels: 8192 * 8192 - 1) == nil)
    }

    @Test
    func computesRGBAAndMaskByteCountsSafely() throws {
        let geometry = try #require(PixelGeometry(width: 16, height: 9))
        #expect(geometry.pixelCount == 144)
        #expect(geometry.rgbaByteCount == 576)
        #expect(geometry.maskByteCount == 144)
        #expect(geometry.fitsMetalUInt32)
    }

    @Test
    func rgbaAndMaskSurfacesValidatePayloadSizes() throws {
        let geometry = try #require(PixelGeometry(width: 3, height: 2))

        let rgba = RgbaSurface(geometry: geometry, data: Data(count: geometry.rgbaByteCount))
        #expect(rgba?.width == 3)
        #expect(rgba?.height == 2)
        #expect(RgbaSurface(geometry: geometry, data: Data(count: geometry.maskByteCount)) == nil)

        let mask = MaskSurface(geometry: geometry, data: Data(count: geometry.maskByteCount))
        #expect(mask?.width == 3)
        #expect(mask?.height == 2)
        #expect(MaskSurface(geometry: geometry, data: Data(count: geometry.rgbaByteCount)) == nil)
    }

    @Test
    func layerBudgetScalesDownForLargeCanvases() throws {
        let small = try #require(PixelGeometry(width: 64, height: 64))
        #expect(CanvasSizePolicy.maxLayerCountForCanvas(small) == CanvasSizePolicy.maxLayerCount)

        let huge = try #require(PixelGeometry(width: 8192, height: 8192))
        #expect(CanvasSizePolicy.maxLayerCountForCanvas(huge) < CanvasSizePolicy.maxLayerCount)
        #expect(CanvasSizePolicy.layerPixelBytesFitDocumentBudget(canvasRGBAByteCount: huge.rgbaByteCount, layerCount: CanvasSizePolicy.maxLayerCountForCanvas(huge)))
        #expect(!CanvasSizePolicy.layerPixelBytesFitDocumentBudget(canvasRGBAByteCount: huge.rgbaByteCount, layerCount: CanvasSizePolicy.maxLayerCountForCanvas(huge) + 1))
    }
}

@Suite
struct DocumentSurfaceInvariantTests {
    @Test
    func compositeSurfaceValidatingInitializerRejectsMismatchedRGBABytes() {
        #expect(DocumentCompositeSurface(validatingWidth: 2, height: 2, pixelData: Data(count: 16)) != nil)
        #expect(DocumentCompositeSurface(validatingWidth: 2, height: 2, pixelData: Data(count: 15)) == nil)
    }

    @Test
    func snapshotAndLayerValidatingInitializersRejectMismatchedBytes() {
        let layer = MetalLayerSnapshot(
            validatingIndex: 0,
            opacity: 1,
            visible: true,
            isClipped: false,
            blendMode: .normal,
            canvasWidth: 2,
            canvasHeight: 2,
            thumbnailData: nil,
            pixelData: Data(count: 16)
        )
        #expect(layer != nil)

        let badLayer = MetalLayerSnapshot(
            validatingIndex: 0,
            opacity: 1,
            visible: true,
            isClipped: false,
            blendMode: .normal,
            canvasWidth: 2,
            canvasHeight: 2,
            thumbnailData: nil,
            pixelData: Data(count: 12)
        )
        #expect(badLayer == nil)

        #expect(MetalDocumentSnapshot(
            validatingWidth: 2,
            height: 2,
            revision: 1,
            compositePixelData: Data(count: 16),
            layers: []
        ) != nil)
        #expect(MetalDocumentSnapshot(
            validatingWidth: 2,
            height: 2,
            revision: 1,
            compositePixelData: Data(count: 12),
            layers: []
        ) == nil)
    }

    @Test
    func incrementalUpdateAndSelectionRejectInvalidPayloadSizes() {
        #expect(IncrementalLayerUpdate(
            validatingID: UUID(),
            layerIndex: 0,
            originX: 0,
            originY: 0,
            width: 2,
            height: 2,
            pixelData: Data(count: 16)
        ) != nil)
        #expect(IncrementalLayerUpdate(
            validatingID: UUID(),
            layerIndex: 0,
            originX: 0,
            originY: 0,
            width: 2,
            height: 2,
            pixelData: Data(count: 12)
        ) == nil)

        #expect(CanvasSelection(
            validatingBounds: CGRect(x: 0, y: 0, width: 2, height: 2),
            maskWidth: 2,
            maskHeight: 2,
            maskData: Data(count: 4),
            mode: .lasso
        ) != nil)
        #expect(CanvasSelection(
            validatingBounds: CGRect(x: 0, y: 0, width: 2, height: 2),
            maskWidth: 2,
            maskHeight: 2,
            maskData: Data(count: 3),
            mode: .lasso
        ) == nil)
    }
}
