import Foundation
import PrimoBrushFileFormats
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
            #expect(preview?.pixelData == nil)
            #expect(preview?.gpuBufferHandle != nil)
            #expect(preview?.incrementalUpdate?.gpuBufferHandle != nil)
        } else {
            #expect(preview == nil)
        }
    }

    @Test
    func responsiveOilPreviewIsMarkedApproximate() {
        let client = DocumentRenderingClient.live
        let basePixels = Data(count: 32 * 32 * 4)
        let snapshot = MetalDocumentSnapshot(
            width: 32,
            height: 32,
            revision: 4,
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
                    point: CGPoint(x: 10, y: 10),
                    pressure: 1,
                    altitude: .pi / 2,
                    azimuth: 0,
                    timestamp: 0
                ),
                StylusSample(
                    point: CGPoint(x: 22, y: 22),
                    pressure: 1,
                    altitude: .pi / 2,
                    azimuth: 0,
                    timestamp: 0.016
                )
            ],
            brush: .init(
                tipKind: .oil,
                radius: 5,
                opacity: 1,
                hardness: 0.8,
                roundness: 0.8,
                angle: 0,
                angleMode: .strokeDirection,
                stampSpacing: 0.1,
                spacingJitter: 0,
                scatterLateral: 0,
                scatterLinear: 0,
                count: 1,
                countJitter: 0,
                angleJitter: 0,
                roundnessJitter: 0,
                textureMode: .strokeLocked,
                textureStrength: 0.2,
                wetness: 0.12,
                colorMixStrength: 0.1,
                smudgeRadius: 0.36,
                paintLoad: 0.92,
                smudgeEngineEnabled: true,
                smudgeMode: .smearing,
                smudgeLength: 0.4,
                colorRate: 0.46,
                pressureSensitivity: 0.16,
                red: 46,
                green: 50,
                blue: 58
            ),
            preserveAlphaLockedPixels: false,
            usesResponsiveOilPreview: true
        )

        if client.isAvailable {
            #expect(preview?.isApproximatePreview == true)
            #expect(preview?.rectPixelData?.isEmpty == false)
        } else {
            #expect(preview == nil)
        }
    }

    @Test
    func responsiveOilPreviewBrushStabilizesCoverageWithoutMutatingOriginal() {
        let customTip = BrushTipRaster(width: 2, height: 1, alphaData: Data([0, 255]))
        let original = BrushRuntimeSettings(
            tipKind: .oil,
            radius: 8.4,
            opacity: 0.72,
            hardness: 0.8,
            roundness: 0.74,
            angle: 0,
            angleMode: .strokeDirection,
            stampSpacing: 0.09,
            spacingJitter: 0,
            scatterLateral: 0,
            scatterLinear: 0,
            count: 1,
            countJitter: 0,
            angleJitter: 0,
            roundnessJitter: 0,
            textureMode: .strokeLocked,
            textureStrength: 0.16,
            flow: 0.82,
            flowPressureSensitivity: 0.08,
            wetness: 0.12,
            opacityPressureSensitivity: 0.1,
            colorMixStrength: 0.1,
            smudgeRadius: 0.36,
            paintLoad: 0.92,
            smudgeEngineEnabled: true,
            smudgeMode: .smearing,
            smudgeLength: 0.4,
            colorRate: 0.46,
            customTip: customTip,
            pressureSensitivity: 0.16,
            red: 46,
            green: 50,
            blue: 58
        )

        let preview = DocumentRenderingClient.responsiveOilPreviewBrush(from: original)

        #expect(original.smudgeEngineEnabled == true)
        #expect(original.customTip == customTip)
        #expect(original.textureStrength == 0.16)
        #expect(original.pressureSensitivity == 0.16)
        #expect(original.opacityPressureSensitivity == 0.1)
        #expect(original.flowPressureSensitivity == 0.08)
        #expect(original.radius == 8.4)
        #expect(original.hardness == 0.8)
        #expect(original.flow == 0.82)
        #expect(original.opacity == 0.72)

        #expect(preview.smudgeEngineEnabled == false)
        #expect(preview.customTip == nil)
        #expect(preview.textureStrength == 0.08)
        #expect(preview.pressureSensitivity == 0.04)
        #expect(preview.opacityPressureSensitivity == 0.04)
        #expect(preview.flowPressureSensitivity == 0.04)
        #expect(preview.radius == original.radius * 1.10)
        #expect(preview.hardness == 0.86)
        #expect(preview.flow == 0.96)
        #expect(preview.opacity == 0.92)
        #expect(preview.wetness == original.wetness)
        #expect(preview.paintLoad == original.paintLoad)
        #expect(preview.colorMixStrength == original.colorMixStrength)
        #expect(preview.textureMode == original.textureMode)
        #expect(preview.angleMode == original.angleMode)
        #expect(preview.stampSpacing == original.stampSpacing)
        #expect(preview.red == original.red)
        #expect(preview.green == original.green)
        #expect(preview.blue == original.blue)
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
