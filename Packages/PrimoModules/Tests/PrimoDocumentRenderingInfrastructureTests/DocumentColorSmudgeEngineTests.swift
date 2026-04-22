import Foundation
import PrimoBrushDomain
import PrimoDocumentContracts
import PrimoDocumentStrokeInfrastructure
import Testing

struct DocumentColorSmudgeEngineTests {
    @Test
    func smearingPullsPreviousDabColorForward() {
        let engine = DocumentColorSmudgeEngine()
        let base = makeCanvas(width: 8, height: 4) { x, _ in
            if x < 3 {
                return (255, 0, 0, 255)
            }
            return (0, 0, 0, 0)
        }

        let result = engine.applyStroke(
            basePixelData: base,
            canvasWidth: 8,
            canvasHeight: 4,
            samples: [
                StylusSample(point: CGPoint(x: 1, y: 2), pressure: 1, altitude: .pi / 2, azimuth: 0, timestamp: 0),
                StylusSample(point: CGPoint(x: 5, y: 2), pressure: 1, altitude: .pi / 2, azimuth: 0, timestamp: 1)
            ],
            brush: smudgeBrush(mode: .smearing, smudgeLength: 1.0, colorRate: 0.0)
        )

        #expect(result != nil)
        let pulled = pixel(in: result!.pixelData, canvasWidth: 8, x: 5, y: 2)
        #expect(pulled.red > 0.25)
        #expect(pulled.alpha > 0.01)
    }

    @Test
    func dullingSamplesUnderlyingColorAndAddsPigmentByColorRate() {
        let engine = DocumentColorSmudgeEngine()
        let base = makeCanvas(width: 6, height: 6) { x, y in
            if x < 3 && y < 3 {
                return (0, 0, 255, 255)
            }
            return (0, 0, 0, 0)
        }

        let result = engine.applyStroke(
            basePixelData: base,
            canvasWidth: 6,
            canvasHeight: 6,
            samples: [
                StylusSample(point: CGPoint(x: 2, y: 2), pressure: 1, altitude: .pi / 2, azimuth: 0, timestamp: 0)
            ],
            brush: smudgeBrush(mode: .dulling, smudgeLength: 1.0, colorRate: 1.0)
        )

        #expect(result != nil)
        let sampled = pixel(in: result!.pixelData, canvasWidth: 6, x: 2, y: 2)
        #expect(sampled.blue > 0.10)
        #expect(sampled.green > 0.10)
    }

    @Test
    func pressureIncreasesSmudgeMixingWhenLoadPressureSensitivityIsEnabled() {
        let engine = DocumentColorSmudgeEngine()
        let base = makeCanvas(width: 8, height: 4) { x, _ in
            if x < 3 {
                return (255, 0, 0, 255)
            }
            return (0, 0, 0, 0)
        }

        let lowPressure = engine.applyStroke(
            basePixelData: base,
            canvasWidth: 8,
            canvasHeight: 4,
            samples: [
                StylusSample(point: CGPoint(x: 1, y: 2), pressure: 0.2, altitude: .pi / 2, azimuth: 0, timestamp: 0),
                StylusSample(point: CGPoint(x: 5, y: 2), pressure: 0.2, altitude: .pi / 2, azimuth: 0, timestamp: 1)
            ],
            brush: smudgeBrush(mode: .smearing, smudgeLength: 0.55, colorRate: 0.0, loadPressureSensitivity: 1.0)
        )

        let highPressure = engine.applyStroke(
            basePixelData: base,
            canvasWidth: 8,
            canvasHeight: 4,
            samples: [
                StylusSample(point: CGPoint(x: 1, y: 2), pressure: 1.0, altitude: .pi / 2, azimuth: 0, timestamp: 0),
                StylusSample(point: CGPoint(x: 5, y: 2), pressure: 1.0, altitude: .pi / 2, azimuth: 0, timestamp: 1)
            ],
            brush: smudgeBrush(mode: .smearing, smudgeLength: 0.55, colorRate: 0.0, loadPressureSensitivity: 1.0)
        )

        #expect(lowPressure != nil)
        #expect(highPressure != nil)
        let lowTransfer = accumulatedChannel(
            in: lowPressure!.pixelData,
            canvasWidth: 8,
            xRange: 4..<8,
            yRange: 0..<4
        )
        let highTransfer = accumulatedChannel(
            in: highPressure!.pixelData,
            canvasWidth: 8,
            xRange: 4..<8,
            yRange: 0..<4
        )
        #expect(highTransfer.red > lowTransfer.red)
        #expect(highTransfer.alpha > lowTransfer.alpha)
    }

    @Test
    func ignoresNonFiniteSamplesWithoutCrashing() {
        let engine = DocumentColorSmudgeEngine()
        let base = makeCanvas(width: 8, height: 4) { _, _ in
            (0, 0, 0, 0)
        }

        let result = engine.applyStroke(
            basePixelData: base,
            canvasWidth: 8,
            canvasHeight: 4,
            samples: [
                StylusSample(point: CGPoint(x: 1, y: 2), pressure: 1, altitude: .pi / 2, azimuth: 0, timestamp: 0),
                StylusSample(point: CGPoint(x: CGFloat.nan, y: 2), pressure: 1, altitude: .pi / 2, azimuth: 0, timestamp: 1),
                StylusSample(point: CGPoint(x: 5, y: 2), pressure: 1, altitude: .pi / 2, azimuth: 0, timestamp: 2)
            ],
            brush: smudgeBrush(mode: .smearing, smudgeLength: 0.55, colorRate: 0.0)
        )

        #expect(result != nil)
        #expect(result?.pixelData.count == base.count)
    }

    private func smudgeBrush(
        mode: BrushSmudgeMode,
        smudgeLength: Double,
        colorRate: Double,
        loadPressureSensitivity: Double = 0.0
    ) -> BrushRuntimeSettings {
        BrushRuntimeSettings(
            tipKind: .oil,
            radius: 1.6,
            opacity: 1.0,
            hardness: 1.0,
            roundness: 1.0,
            angle: 0.0,
            angleMode: .fixed,
            stampSpacing: 0.3,
            spacingJitter: 0.0,
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
            smudgeMode: mode,
            smudgeLength: smudgeLength,
            colorRate: colorRate,
            loadPressureSensitivity: loadPressureSensitivity,
            pressureSensitivity: 0.0,
            red: 0,
            green: 255,
            blue: 0
        )
    }

    private func makeCanvas(
        width: Int,
        height: Int,
        fill: (Int, Int) -> (UInt8, UInt8, UInt8, UInt8)
    ) -> Data {
        var data = Data(count: width * height * 4)
        data.withUnsafeMutableBytes { rawBytes in
            guard let base = rawBytes.bindMemory(to: UInt8.self).baseAddress else { return }
            for y in 0..<height {
                for x in 0..<width {
                    let offset = ((y * width) + x) * 4
                    let pixel = fill(x, y)
                    base[offset] = pixel.0
                    base[offset + 1] = pixel.1
                    base[offset + 2] = pixel.2
                    base[offset + 3] = pixel.3
                }
            }
        }
        return data
    }

    private func pixel(in data: Data, canvasWidth: Int, x: Int, y: Int) -> (red: Double, green: Double, blue: Double, alpha: Double) {
        data.withUnsafeBytes { rawBytes in
            let base = rawBytes.bindMemory(to: UInt8.self).baseAddress!
            let offset = ((y * canvasWidth) + x) * 4
            return (
                red: Double(base[offset]) / 255.0,
                green: Double(base[offset + 1]) / 255.0,
                blue: Double(base[offset + 2]) / 255.0,
                alpha: Double(base[offset + 3]) / 255.0
            )
        }
    }

    private func accumulatedChannel(
        in data: Data,
        canvasWidth: Int,
        xRange: Range<Int>,
        yRange: Range<Int>
    ) -> (red: Double, alpha: Double) {
        var red: Double = 0
        var alpha: Double = 0
        for y in yRange {
            for x in xRange {
                let value = pixel(in: data, canvasWidth: canvasWidth, x: x, y: y)
                red += value.red
                alpha += value.alpha
            }
        }
        return (red: red, alpha: alpha)
    }
}
