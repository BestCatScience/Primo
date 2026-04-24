import Foundation
import PrimoBrushFileFormats
import PrimoDocumentContracts
import PrimoDocumentRenderingInfrastructure
@testable import PrimoDocumentMetalRuntimeInfrastructure
import Testing

struct PrimoMetalStrokeGoldenTests {
    @Test
    func gpuExecutesBrushesThatUsedToBeRejectedByRasterizationGate() {
        let client = DocumentRenderingClient.live
        let basePixelData = seededCanvas(width: 48, height: 48)
        let brush = stressBrush()
        let samples = strokeSamples()

        let result = client.executeStroke(
            MetalStrokeExecutionRequest(
                basePixelData: basePixelData,
                canvasWidth: 48,
                canvasHeight: 48,
                samples: samples,
                brush: brush,
                mode: .commit,
                snapshotRevision: 1,
                activeLayerIndex: 0
            )
        )

        if client.isAvailable {
            #expect(result != nil)
            #expect(((result?.dirtyRect.originX ?? -1), (result?.dirtyRect.originY ?? -1), (result?.dirtyRect.width ?? -1), (result?.dirtyRect.height ?? -1)) == (0, 0, 48, 48))
            #expect(samplePixel(in: result!.pixelData, canvasWidth: 48, x: 18, y: 14) == (153, 113, 61, 248))
            #expect(samplePixel(in: result!.pixelData, canvasWidth: 48, x: 31, y: 24) == (214, 159, 104, 255))
        } else {
            #expect(result == nil)
        }
    }

    @Test
    func gpuRasterStrokeMatchesGoldenOutput() {
        let client = DocumentRenderingClient.live
        let basePixelData = seededCanvas(width: 40, height: 40)
        let brush = texturedOilBrush()
        let samples = strokeSamples()

        let output = client.rasterizedStrokePixelData(
            basePixelData: basePixelData,
            canvasWidth: 40,
            canvasHeight: 40,
            samples: samples,
            brush: brush
        )

        if client.isAvailable {
            #expect(output != nil)
            #expect(fnv1a64(output!) == 0)
            #expect(samplePixel(in: output!, canvasWidth: 40, x: 6, y: 8) == (0, 0, 0, 0))
            #expect(samplePixel(in: output!, canvasWidth: 40, x: 18, y: 14) == (0, 0, 0, 0))
            #expect(samplePixel(in: output!, canvasWidth: 40, x: 31, y: 24) == (0, 0, 0, 0))
        } else {
            #expect(output == nil)
        }
    }

    @Test
    func gpuColorSmudgeMatchesGoldenOutput() {
        let client = DocumentRenderingClient.live
        let basePixelData = seededCanvas(width: 36, height: 24)
        let brush = smudgeBrush()
        let samples = [
            StylusSample(point: CGPoint(x: 6, y: 10), pressure: 0.35, altitude: .pi / 2, azimuth: 0, timestamp: 0),
            StylusSample(point: CGPoint(x: 30, y: 12), pressure: 1.0, altitude: .pi / 2, azimuth: 0, timestamp: 1)
        ]

        let output = client.rasterizedStrokePixelData(
            basePixelData: basePixelData,
            canvasWidth: 36,
            canvasHeight: 24,
            samples: samples,
            brush: brush
        )

        if client.isAvailable {
            #expect(output != nil)
            #expect(fnv1a64(output!) == 0)
            #expect(samplePixel(in: output!, canvasWidth: 36, x: 6, y: 10) == (0, 0, 0, 0))
            #expect(samplePixel(in: output!, canvasWidth: 36, x: 18, y: 11) == (0, 0, 0, 0))
            #expect(samplePixel(in: output!, canvasWidth: 36, x: 30, y: 12) == (0, 0, 0, 0))
        } else {
            #expect(output == nil)
        }
    }

    @Test
    func gpuRasterizesSinglePointAndShortSmudgeStrokes() {
        let client = DocumentRenderingClient.live
        let basePixelData = seededCanvas(width: 24, height: 24)
        let stampOutput = client.rasterizedStrokePixelData(
            basePixelData: basePixelData,
            canvasWidth: 24,
            canvasHeight: 24,
            samples: [
                StylusSample(point: CGPoint(x: 12, y: 12), pressure: 1.0, altitude: .pi / 2, azimuth: 0, timestamp: 0)
            ],
            brush: texturedOilBrush()
        )
        let smudgeOutput = client.rasterizedStrokePixelData(
            basePixelData: basePixelData,
            canvasWidth: 24,
            canvasHeight: 24,
            samples: [
                StylusSample(point: CGPoint(x: 8, y: 11), pressure: 0.5, altitude: .pi / 2, azimuth: 0, timestamp: 0),
                StylusSample(point: CGPoint(x: 15, y: 12), pressure: 1.0, altitude: .pi / 2, azimuth: 0, timestamp: 0.016),
            ],
            brush: smudgeBrush()
        )

        if client.isAvailable {
            #expect(stampOutput != nil)
            #expect(smudgeOutput != nil)
            #expect(stampOutput != basePixelData)
            #expect(smudgeOutput != basePixelData)
        } else {
            #expect(stampOutput == nil)
            #expect(smudgeOutput == nil)
        }
    }

    @Test
    func gpuPrimitiveBinningProducesStableSummary() {
        let client = PrimoMetalDocumentProcessingClient.shared
        let summary = client.debugStrokeBinningSummary(
            canvasWidth: 48,
            canvasHeight: 48,
            samples: strokeSamples(),
            brush: stressBrush()
        )

        if client.isAvailable {
            #expect(summary != nil)
            #expect(summary?.primitiveCount == 2)
            #expect(summary?.tileCount == 4)
            #expect(summary?.totalPrimitiveReferences == 0)
            #expect(summary?.monotonicTileOffsets == true)
            #expect(summary?.primitiveIndexBoundsValid == true)
        } else {
            #expect(summary == nil)
        }
    }

    private func strokeSamples() -> [StylusSample] {
        [
            StylusSample(point: CGPoint(x: 6, y: 8), pressure: 0.45, altitude: .pi / 2, azimuth: 0, timestamp: 0),
            StylusSample(point: CGPoint(x: 18, y: 14), pressure: 0.9, altitude: .pi / 2, azimuth: 0, timestamp: 0.016),
            StylusSample(point: CGPoint(x: 31, y: 24), pressure: 0.62, altitude: .pi / 2, azimuth: 0, timestamp: 0.032)
        ]
    }

    private func stressBrush() -> BrushRuntimeSettings {
        BrushRuntimeSettings(
            tipKind: .airbrush,
            radius: 5.5,
            taperIn: 0.15,
            taperOut: 0.22,
            opacity: 0.9,
            hardness: 0.45,
            roundness: 1.0,
            angle: 0.0,
            angleMode: .fixed,
            stampSpacing: 0.14,
            spacingJitter: 0.0,
            scatterEnabled: true,
            scatterMode: .spray,
            scatterLateral: 10.0,
            scatterLinear: 8.0,
            count: 4,
            countJitter: 0.7,
            countSizeJitter: 0.35,
            countOpacityJitter: 0.25,
            angleJitter: 0.0,
            roundnessJitter: 0.0,
            textureMode: .moving,
            textureStrength: 0.8,
            flow: 0.85,
            colorMixingMode: .runningColor,
            wetness: 0.7,
            colorMixStrength: 0.65,
            smudgeBlurEnabled: true,
            smudgeBleed: 0.5,
            smudgeRadius: 0.6,
            paintLoad: 0.55,
            smudgeEngineEnabled: false,
            smudgeMode: .smearing,
            smudgeLength: 0.0,
            colorRate: 1.0,
            dualBrushEnabled: true,
            dualScale: 2.2,
            dualSpacing: 0.65,
            dualScatter: 1.9,
            pressureSensitivity: 0.9,
            red: 255,
            green: 160,
            blue: 48
        )
    }

    private func texturedOilBrush() -> BrushRuntimeSettings {
        BrushRuntimeSettings(
            tipKind: .oil,
            radius: 4.5,
            taperIn: 0.08,
            taperOut: 0.16,
            opacity: 0.84,
            hardness: 0.72,
            roundness: 1.0,
            angle: 0.0,
            angleMode: .fixed,
            stampSpacing: 0.16,
            spacingJitter: 0.0,
            scatterEnabled: false,
            scatterLateral: 0.0,
            scatterLinear: 0.0,
            count: 1,
            countJitter: 0.0,
            angleJitter: 0.0,
            roundnessJitter: 0.0,
            textureMode: .moving,
            textureStrength: 0.52,
            flow: 0.78,
            colorMixingMode: .runningColor,
            wetness: 0.68,
            colorMixStrength: 0.56,
            smudgeBlurEnabled: true,
            smudgeBleed: 0.38,
            smudgeRadius: 0.42,
            paintLoad: 0.64,
            smudgeEngineEnabled: false,
            smudgeMode: .smearing,
            smudgeLength: 0.0,
            colorRate: 1.0,
            grainScale: 1.1,
            grainContrast: 1.25,
            paperScale: 0.18,
            paperStrength: 0.28,
            paperThreshold: 0.33,
            customTip: BrushTipRaster(width: 2, height: 2, alphaData: Data([255, 180, 180, 255])),
            pressureSensitivity: 0.85,
            red: 220,
            green: 90,
            blue: 42
        )
    }

    private func smudgeBrush() -> BrushRuntimeSettings {
        BrushRuntimeSettings(
            tipKind: .oil,
            radius: 2.1,
            opacity: 1.0,
            hardness: 0.92,
            roundness: 1.0,
            angle: 0.0,
            angleMode: .fixed,
            stampSpacing: 0.28,
            spacingJitter: 0.0,
            scatterEnabled: false,
            scatterLateral: 0.0,
            scatterLinear: 0.0,
            count: 1,
            countJitter: 0.0,
            angleJitter: 0.0,
            roundnessJitter: 0.0,
            textureMode: .off,
            textureStrength: 0.0,
            flow: 1.0,
            wetness: 0.0,
            colorMixStrength: 0.0,
            smudgeRadius: 0.6,
            paintLoad: 1.0,
            smudgeEngineEnabled: true,
            smudgeMode: .smearing,
            smudgeLength: 0.7,
            colorRate: 0.15,
            loadPressureSensitivity: 0.9,
            pressureSensitivity: 0.0,
            red: 12,
            green: 220,
            blue: 40
        )
    }

    private func seededCanvas(width: Int, height: Int) -> Data {
        var data = Data(count: width * height * 4)
        data.withUnsafeMutableBytes { rawBytes in
            guard let base = rawBytes.bindMemory(to: UInt8.self).baseAddress else { return }
            for y in 0..<height {
                for x in 0..<width {
                    let offset = ((y * width) + x) * 4
                    let checker = ((x / 6) + (y / 5)) % 2 == 0
                    base[offset] = checker ? 180 : 42
                    base[offset + 1] = UInt8(min(255, (x * 5) + (checker ? 16 : 40)))
                    base[offset + 2] = UInt8(min(255, (y * 8) + (checker ? 80 : 24)))
                    base[offset + 3] = checker ? 255 : 210
                }
            }
        }
        return data
    }

    private func samplePixel(in data: Data, canvasWidth: Int, x: Int, y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
        data.withUnsafeBytes { rawBytes in
            let base = rawBytes.bindMemory(to: UInt8.self).baseAddress!
            let offset = ((y * canvasWidth) + x) * 4
            return (base[offset], base[offset + 1], base[offset + 2], base[offset + 3])
        }
    }

    private func fnv1a64(_ data: Data) -> UInt64 {
        data.withUnsafeBytes { rawBytes in
            let bytes = rawBytes.bindMemory(to: UInt8.self)
            var hash: UInt64 = 0xcbf29ce484222325
            for byte in bytes {
                hash ^= UInt64(byte)
                hash &*= 0x100000001b3
            }
            return hash
        }
    }
}
