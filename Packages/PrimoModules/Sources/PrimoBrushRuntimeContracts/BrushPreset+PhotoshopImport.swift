import Foundation
import PrimoBrushDomain

public extension BrushPreset {
    static func photoshopImported(name: String, tip: BrushTipRaster) -> BrushPreset {
        let analysis = BrushTipAnalyzer.analyze(tip)
        let importedRadius = Double(max(tip.width, tip.height)) * 0.5
        let radius = min(max(1.0, importedRadius), 48.0)
        return BrushPreset(
            name: name,
            tipKind: .ink,
            radius: max(1.0, radius),
            sizeSpeedSensitivity: analysis.sizeSpeedSensitivity,
            taperIn: 0.0,
            taperOut: 0.0,
            opacity: 1.0,
            hardness: analysis.hardness,
            roundness: analysis.roundness,
            roundnessPressureSensitivity: analysis.roundnessPressureSensitivity,
            roundnessTiltSensitivity: analysis.roundnessTiltSensitivity,
            angle: analysis.angle,
            anglePressureSensitivity: analysis.anglePressureSensitivity,
            angleTiltSensitivity: analysis.angleTiltSensitivity,
            angleMode: .fixed,
            spacing: analysis.spacing,
            spacingJitter: analysis.spacingJitter,
            scatterEnabled: analysis.scatterEnabled,
            scatterMode: analysis.scatterMode,
            scatterLateral: analysis.scatterLateral,
            scatterLinear: analysis.scatterLinear,
            count: analysis.count,
            countJitter: analysis.countJitter,
            countSizeJitter: analysis.countSizeJitter,
            countOpacityJitter: analysis.countOpacityJitter,
            angleJitter: analysis.angleJitter,
            roundnessJitter: analysis.roundnessJitter,
            textureMode: analysis.textureMode,
            textureStrength: analysis.textureStrength,
            flow: analysis.flow,
            flowPressureSensitivity: analysis.flowPressureSensitivity,
            flowJitter: analysis.flowJitter,
            wetness: analysis.wetness,
            wetnessPressureSensitivity: analysis.wetnessPressureSensitivity,
            opacityPressureSensitivity: analysis.opacityPressureSensitivity,
            colorMixStrength: analysis.colorMixStrength,
            paintLoad: analysis.paintLoad,
            loadPressureSensitivity: analysis.loadPressureSensitivity,
            dualBrushEnabled: analysis.dualBrushEnabled,
            dualTipKind: analysis.dualTipKind,
            dualScale: analysis.dualScale,
            dualSpacing: analysis.dualSpacing,
            dualScatter: analysis.dualScatter,
            dualAngle: analysis.dualAngle,
            dualBlendMode: analysis.dualBlendMode,
            grainScale: analysis.grainScale,
            grainContrast: analysis.grainContrast,
            paperScale: analysis.paperScale,
            paperStrength: analysis.paperStrength,
            paperThreshold: analysis.paperThreshold,
            flipX: false,
            flipY: false,
            customTip: tip,
            pressureSensitivity: 0.35,
            red: 20,
            green: 20,
            blue: 22
        ) ?? .defaultPencil
    }
}

private enum BrushTipAnalyzer {
    struct Result {
        let roundness: Double
        let roundnessPressureSensitivity: Double
        let roundnessTiltSensitivity: Double
        let angle: Double
        let anglePressureSensitivity: Double
        let angleTiltSensitivity: Double
        let spacing: Double
        let spacingJitter: Double
        let scatterEnabled: Bool
        let scatterMode: BrushScatterMode
        let scatterLateral: Double
        let scatterLinear: Double
        let count: Int
        let countJitter: Double
        let countSizeJitter: Double
        let countOpacityJitter: Double
        let angleJitter: Double
        let roundnessJitter: Double
        let hardness: Double
        let sizeSpeedSensitivity: Double
        let flow: Double
        let flowPressureSensitivity: Double
        let flowJitter: Double
        let textureMode: BrushTextureMode
        let textureStrength: Double
        let wetness: Double
        let wetnessPressureSensitivity: Double
        let opacityPressureSensitivity: Double
        let colorMixStrength: Double
        let paintLoad: Double
        let loadPressureSensitivity: Double
        let dualBrushEnabled: Bool
        let dualTipKind: BrushTipKind
        let dualScale: Double
        let dualSpacing: Double
        let dualScatter: Double
        let dualAngle: Double
        let dualBlendMode: BrushDualBlendMode
        let grainScale: Double
        let grainContrast: Double
        let paperScale: Double
        let paperStrength: Double
        let paperThreshold: Double
    }

    static func analyze(_ tip: BrushTipRaster) -> Result {
        let width = tip.width
        let height = tip.height
        let alpha = [UInt8](tip.alphaData)
        guard width > 0, height > 0, !alpha.isEmpty else {
            return fallbackResult
        }

        var totalWeight = 0.0
        var meanX = 0.0
        var meanY = 0.0
        var occupiedCount = 0
        var softEdgeCount = 0
        for y in 0..<height {
            for x in 0..<width {
                let value = Double(alpha[(y * width) + x]) / 255.0
                totalWeight += value
                meanX += Double(x) * value
                meanY += Double(y) * value
                if value > 0.08 { occupiedCount += 1 }
                if value > 0.08 && value < 0.92 { softEdgeCount += 1 }
            }
        }
        guard totalWeight > 0.0001 else {
            return fallbackResult
        }
        meanX /= totalWeight
        meanY /= totalWeight

        var covXX = 0.0
        var covYY = 0.0
        var covXY = 0.0
        for y in 0..<height {
            for x in 0..<width {
                let value = Double(alpha[(y * width) + x]) / 255.0
                if value <= 0 { continue }
                let dx = Double(x) - meanX
                let dy = Double(y) - meanY
                covXX += dx * dx * value
                covYY += dy * dy * value
                covXY += dx * dy * value
            }
        }
        covXX /= totalWeight
        covYY /= totalWeight
        covXY /= totalWeight
        let trace = covXX + covYY
        let determinant = (covXX * covYY) - (covXY * covXY)
        let root = sqrt(max(0.0, (trace * trace * 0.25) - determinant))
        let major = max(trace * 0.5 + root, 0.0001)
        let minor = max(trace * 0.5 - root, 0.0001)
        let roundness = max(0.12, min(1.0, sqrt(minor / major)))
        let angle = 0.5 * atan2(2.0 * covXY, covXX - covYY)

        let coverage = Double(occupiedCount) / Double(width * height)
        let softness = occupiedCount > 0 ? Double(softEdgeCount) / Double(occupiedCount) : 0.0
        let components = connectedComponentStats(alpha: alpha, width: width, height: height)
        let detachedCoverage = max(0.0, components.detachedCoverage)
        let islands = max(0, components.count - 1)
        let sparseTip = coverage < 0.34 || detachedCoverage > 0.03 || islands >= 2
        let elongated = roundness < 0.62
        let textureStrength = min(0.92, max(0.12, (softness * 0.55) + (detachedCoverage * 2.8)))
        let paperStrength = min(0.72, max(0.12, (1.0 - coverage) * 0.34 + softness * 0.28))

        return Result(
            roundness: roundness,
            roundnessPressureSensitivity: min(0.32, max(0.0, (1.0 - roundness) * 0.20)),
            roundnessTiltSensitivity: min(0.42, max(0.0, (1.0 - roundness) * 0.34)),
            angle: angle,
            anglePressureSensitivity: min(0.16, max(0.0, (1.0 - roundness) * 0.10)),
            angleTiltSensitivity: min(0.34, max(0.0, (1.0 - roundness) * 0.22)),
            spacing: min(0.55, max(0.08, 0.18 + ((1.0 - coverage) * 0.22))),
            spacingJitter: min(0.24, detachedCoverage * 0.35),
            scatterEnabled: sparseTip || detachedCoverage > 0.015 || islands >= 2,
            scatterMode: sparseTip ? .spray : .directional,
            scatterLateral: min(0.32, detachedCoverage * 0.8 + Double(islands) * 0.03),
            scatterLinear: min(0.16, detachedCoverage * 0.28),
            count: islands >= 2 ? 2 : 1,
            countJitter: islands >= 2 ? min(0.35, Double(islands) * 0.08) : 0.0,
            countSizeJitter: sparseTip ? min(0.48, 0.12 + detachedCoverage * 1.4 + softness * 0.18) : min(0.18, softness * 0.14),
            countOpacityJitter: sparseTip ? min(0.44, 0.10 + detachedCoverage * 1.1 + softness * 0.14) : min(0.14, softness * 0.10),
            angleJitter: min(0.22, (1.0 - roundness) * 0.12),
            roundnessJitter: min(0.18, softness * 0.2),
            hardness: min(0.98, max(0.55, 0.98 - (softness * 0.45))),
            sizeSpeedSensitivity: min(0.22, max(0.0, detachedCoverage * 0.9 + softness * 0.10)),
            flow: min(1.0, max(0.55, 0.88 + (coverage * 0.18) - (softness * 0.12))),
            flowPressureSensitivity: min(0.48, max(0.06, softness * 0.30 + detachedCoverage * 0.42)),
            flowJitter: min(0.36, max(0.0, detachedCoverage * 1.6 + softness * 0.12)),
            textureMode: textureStrength > 0.16 ? .eachTip : .strokeLocked,
            textureStrength: textureStrength,
            wetness: min(0.72, max(0.0, detachedCoverage * 1.35 + softness * 0.24)),
            wetnessPressureSensitivity: min(0.74, max(0.0, softness * 0.55 + detachedCoverage * 1.1)),
            opacityPressureSensitivity: min(0.88, max(0.18, 0.32 + softness * 0.44)),
            colorMixStrength: min(0.56, max(0.0, detachedCoverage * 1.8 + softness * 0.18)),
            paintLoad: min(1.0, max(0.42, 0.94 - softness * 0.34 - detachedCoverage * 1.2)),
            loadPressureSensitivity: min(0.66, max(0.0, softness * 0.42 + detachedCoverage * 0.9)),
            dualBrushEnabled: sparseTip,
            dualTipKind: elongated ? .ink : .pencil,
            dualScale: elongated ? 0.58 : 0.72,
            dualSpacing: sparseTip ? min(0.52, 0.22 + detachedCoverage * 2.1 + Double(islands) * 0.04) : 0.22,
            dualScatter: sparseTip ? min(0.45, detachedCoverage * 3.2 + Double(islands) * 0.05) : 0.08,
            dualAngle: angle * 0.65,
            dualBlendMode: sparseTip ? .multiply : .darker,
            grainScale: min(2.4, max(0.8, 1.08 + softness * 1.4)),
            grainContrast: min(2.6, max(1.1, 1.35 + (1.0 - coverage) * 1.2)),
            paperScale: min(0.28, max(0.08, 0.10 + detachedCoverage * 1.6 + softness * 0.06)),
            paperStrength: paperStrength,
            paperThreshold: min(0.68, max(0.28, 0.38 + (1.0 - coverage) * 0.12))
        )
    }

    private static var fallbackResult: Result {
        Result(
            roundness: 1.0,
            roundnessPressureSensitivity: 0.0,
            roundnessTiltSensitivity: 0.0,
            angle: 0.0,
            anglePressureSensitivity: 0.0,
            angleTiltSensitivity: 0.0,
            spacing: 0.25,
            spacingJitter: 0.0,
            scatterEnabled: false,
            scatterMode: .directional,
            scatterLateral: 0.0,
            scatterLinear: 0.0,
            count: 1,
            countJitter: 0.0,
            countSizeJitter: 0.0,
            countOpacityJitter: 0.0,
            angleJitter: 0.0,
            roundnessJitter: 0.0,
            hardness: 0.95,
            sizeSpeedSensitivity: 0.0,
            flow: 1.0,
            flowPressureSensitivity: 0.08,
            flowJitter: 0.0,
            textureMode: .off,
            textureStrength: 0.0,
            wetness: 0.0,
            wetnessPressureSensitivity: 0.0,
            opacityPressureSensitivity: 0.4,
            colorMixStrength: 0.0,
            paintLoad: 1.0,
            loadPressureSensitivity: 0.0,
            dualBrushEnabled: false,
            dualTipKind: .ink,
            dualScale: 0.72,
            dualSpacing: 0.26,
            dualScatter: 0.18,
            dualAngle: 0.0,
            dualBlendMode: .multiply,
            grainScale: 1.2,
            grainContrast: 1.5,
            paperScale: 0.12,
            paperStrength: 0.2,
            paperThreshold: 0.42
        )
    }

    private struct ComponentStats {
        let count: Int
        let detachedCoverage: Double
    }

    private static func connectedComponentStats(alpha: [UInt8], width: Int, height: Int) -> ComponentStats {
        var visited = [Bool](repeating: false, count: width * height)
        var componentAreas: [Int] = []
        let threshold: UInt8 = 32
        let directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width) + x
                if visited[index] || alpha[index] < threshold { continue }
                var queue: [(Int, Int)] = [(x, y)]
                visited[index] = true
                var area = 0
                while !queue.isEmpty {
                    let (cx, cy) = queue.removeLast()
                    area += 1
                    for (dx, dy) in directions {
                        let nx = cx + dx
                        let ny = cy + dy
                        guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                        let nIndex = (ny * width) + nx
                        if visited[nIndex] || alpha[nIndex] < threshold { continue }
                        visited[nIndex] = true
                        queue.append((nx, ny))
                    }
                }
                componentAreas.append(area)
            }
        }

        guard let largest = componentAreas.max(), largest > 0 else {
            return ComponentStats(count: 0, detachedCoverage: 0.0)
        }
        let detached = componentAreas.reduce(0, +) - largest
        let detachedCoverage = Double(detached) / Double(max(width * height, 1))
        return ComponentStats(count: componentAreas.count, detachedCoverage: detachedCoverage)
    }
}
