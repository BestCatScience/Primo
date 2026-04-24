import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import Testing
@testable import PrimoDocumentRenderingInfrastructure

struct DocumentRenderingClientTests {
    @Test
    func previewCompositeFallsBackBehindSingleFacade() {
        let client = DocumentRenderingClient.live
        let basePixels = Data([0, 0, 0, 0, 0, 0, 0, 0])
        let adjustedPixels = Data([255, 0, 0, 255, 0, 255, 0, 255])
        let snapshot = MetalDocumentSnapshot(
            width: 2,
            height: 1,
            revision: 1,
            compositePixelData: basePixels,
            layers: [
                MetalLayerSnapshot(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: basePixels
                )
            ]
        )

        let composited = client.compositedPreviewPixelData(
            snapshot: snapshot,
            activeLayerIndex: 0,
            adjustedActiveLayerPixels: adjustedPixels
        )

        if client.isAvailable {
            #expect(composited == adjustedPixels)
        } else {
            #expect(composited == nil)
        }
    }

    @Test
    func strokeDirtyRectIsResolvedThroughRuntimeBoundary() {
        let client = DocumentRenderingClient.live

        let dirtyRect = client.strokePreviewDirtyRect(
            samples: [
                StylusSample(
                    point: CGPoint(x: 24, y: 18),
                    pressure: 1,
                    altitude: .pi / 2,
                    azimuth: 0,
                    timestamp: 0
                )
            ],
            brush: .init(
                tipKind: .ink,
                radius: 6,
                opacity: 1,
                hardness: 0.8,
                roundness: 1,
                angle: 0,
                angleMode: .fixed,
                stampSpacing: 0.2,
                spacingJitter: 0,
                scatterLateral: 0,
                scatterLinear: 0,
                count: 1,
                countJitter: 0,
                angleJitter: 0,
                roundnessJitter: 0,
                textureMode: .off,
                textureStrength: 0,
                pressureSensitivity: 1,
                red: 255,
                green: 255,
                blue: 255
            ),
            canvasWidth: 128,
            canvasHeight: 128
        )

        #expect(dirtyRect != nil)
        #expect((dirtyRect?.width ?? 0) > 0)
        #expect((dirtyRect?.height ?? 0) > 0)
    }

    @Test
    func compositedPaperPreviewRGBAProducesExportReadyPixels() {
        let client = DocumentRenderingClient.live
        let compositePixels = Data([255, 255, 255, 255, 0, 0, 0, 255])
        let output = client.compositedPaperPreviewRGBA(
            pixelData: compositePixels,
            width: 2,
            height: 1,
            paperStyle: .default
        )

        if client.isAvailable {
            #expect(output != nil)
            #expect(output?.count == compositePixels.count)
        } else {
            #expect(output == nil)
        }
    }

    @Test
    func processedLayerPixelDataRunsAdjustmentsThroughRuntimeBoundary() {
        let client = DocumentRenderingClient.live
        let pixels = Data([
            10, 20, 30, 255,
            200, 180, 160, 128,
        ])

        let output = client.processedLayerPixelData(
            pixelData: pixels,
            canvasWidth: 2,
            canvasHeight: 1,
            request: .luminanceToAlpha
        )

        if client.isAvailable {
            #expect(output != nil)
            #expect(output?.count == pixels.count)
            #expect(output?[0] == 0)
            #expect(output?[1] == 0)
            #expect(output?[2] == 0)
            #expect((output?[3] ?? 255) < 255)
        } else {
            #expect(output == nil)
        }
    }

    @Test
    func interactiveStrokePreviewBuildsPreviewThroughRuntimeBoundary() {
        let client = DocumentRenderingClient.live
        let basePixels = Data(count: 32 * 32 * 4)
        let snapshot = MetalDocumentSnapshot(
            width: 32,
            height: 32,
            revision: 3,
            compositePixelData: basePixels,
            layers: [
                MetalLayerSnapshot(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: basePixels
                )
            ]
        )

        let preview = client.makeInteractiveStrokePreview(
            snapshot: snapshot,
            activeLayerIndex: 0,
            basePixelData: basePixels,
            samples: [
                StylusSample(
                    point: CGPoint(x: 12, y: 12),
                    pressure: 1,
                    altitude: .pi / 2,
                    azimuth: 0,
                    timestamp: 0
                ),
                StylusSample(
                    point: CGPoint(x: 20, y: 20),
                    pressure: 1,
                    altitude: .pi / 2,
                    azimuth: 0,
                    timestamp: 0.016
                )
            ],
            brush: .init(
                tipKind: .ink,
                radius: 4,
                opacity: 1,
                hardness: 0.9,
                roundness: 1,
                angle: 0,
                angleMode: .fixed,
                stampSpacing: 0.15,
                spacingJitter: 0,
                scatterLateral: 0,
                scatterLinear: 0,
                count: 1,
                countJitter: 0,
                angleJitter: 0,
                roundnessJitter: 0,
                textureMode: .off,
                textureStrength: 0,
                pressureSensitivity: 1,
                red: 255,
                green: 255,
                blue: 255
            ),
            preserveAlphaLockedPixels: false
        )

        if client.isAvailable {
            #expect(preview != nil)
            #expect(preview?.pixelData.count == basePixels.count)
        } else {
            #expect(preview == nil)
        }
    }

    @Test
    func compositedPreviewDoesNotReuseStaleLayerTextureAcrossDistinctSnapshots() {
        let client = DocumentRenderingClient.live
        let transparentActivePixels = Data([0, 0, 0, 0])
        let redBackground = Data([255, 0, 0, 255])
        let blueBackground = Data([0, 0, 255, 255])

        let firstSnapshot = MetalDocumentSnapshot(
            width: 1,
            height: 1,
            revision: 0,
            compositePixelData: redBackground,
            layers: [
                MetalLayerSnapshot(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: redBackground
                ),
                MetalLayerSnapshot(
                    index: 1,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: transparentActivePixels
                )
            ]
        )
        let secondSnapshot = MetalDocumentSnapshot(
            width: 1,
            height: 1,
            revision: 0,
            compositePixelData: blueBackground,
            layers: [
                MetalLayerSnapshot(
                    index: 0,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: blueBackground
                ),
                MetalLayerSnapshot(
                    index: 1,
                    opacity: 1,
                    visible: true,
                    isClipped: false,
                    blendMode: .normal,
                    thumbnailData: nil,
                    pixelData: transparentActivePixels
                )
            ]
        )

        let firstComposite = client.compositedPreviewPixelData(
            snapshot: firstSnapshot,
            activeLayerIndex: 1,
            adjustedActiveLayerPixels: transparentActivePixels
        )
        let secondComposite = client.compositedPreviewPixelData(
            snapshot: secondSnapshot,
            activeLayerIndex: 1,
            adjustedActiveLayerPixels: transparentActivePixels
        )

        if client.isAvailable {
            #expect(firstComposite == redBackground)
            #expect(secondComposite == blueBackground)
        } else {
            #expect(firstComposite == nil)
            #expect(secondComposite == nil)
        }
    }
}
