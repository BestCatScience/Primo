import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentStrokeInfrastructure

extension DocumentFeatureRuntimeReducer {
    static func normalizedCommittedStrokeSamples(
        _ samples: [StylusSample],
        brush: BrushRuntimeSettings
    ) -> [StylusSample] {
        var normalized = samples.map { sample in
            StylusSample(
                point: CGPoint(
                    x: sample.point.x.isFinite ? sample.point.x : 0,
                    y: sample.point.y.isFinite ? sample.point.y : 0
                ),
                pressure: sample.pressure.isFinite ? sample.pressure : 1.0,
                altitude: sample.altitude.isFinite ? sample.altitude : .pi / 2,
                azimuth: sample.azimuth.isFinite ? sample.azimuth : 0,
                timestamp: sample.timestamp.isFinite ? sample.timestamp : 0
            )
        }
        guard normalized.count > 1 else { return normalized }

        let jumpThreshold = min(max(CGFloat(brush.radius) * 1.35, 14.0), 96.0)
        while normalized.count > 1 {
            let last = normalized[normalized.count - 1]
            let previous = normalized[normalized.count - 2]
            let dx = last.point.x - previous.point.x
            let dy = last.point.y - previous.point.y
            let distance = sqrt((dx * dx) + (dy * dy))
            let pressureDropThreshold = max(0.08, previous.pressure * 0.72)
            let isTrailingJump =
                (distance > jumpThreshold && last.pressure < pressureDropThreshold) ||
                distance > jumpThreshold * 2.0
            if !isTrailingJump {
                break
            }
            normalized.removeLast()
        }

        var deduplicated: [StylusSample] = []
        deduplicated.reserveCapacity(normalized.count)
        for sample in normalized {
            if let previous = deduplicated.last {
                let dx = sample.point.x - previous.point.x
                let dy = sample.point.y - previous.point.y
                let distance = sqrt((dx * dx) + (dy * dy))
                let pressureDelta = abs(sample.pressure - previous.pressure)
                if distance < 0.001, pressureDelta < 0.001 {
                    continue
                }
            }
            deduplicated.append(sample)
        }
        guard deduplicated.count > 1 else { return deduplicated }

        let terminalClusterRadius = min(max(CGFloat(brush.radius) * 0.55, 2.0), 24.0)
        let terminalClusterTravelLimit = terminalClusterRadius * 1.6
        let terminalDirectionAlignmentThreshold: CGFloat = 0.82
        guard strokePathLength(deduplicated) > terminalClusterRadius * 1.25 else {
            return deduplicated
        }
        let lastIndex = deduplicated.index(before: deduplicated.endIndex)
        let finalSample = deduplicated[lastIndex]
        var clusterStart = lastIndex
        var cumulativeTravel: CGFloat = 0

        while clusterStart > 0 {
            let previousIndex = deduplicated.index(before: clusterStart)
            let previous = deduplicated[previousIndex]
            let current = deduplicated[clusterStart]
            let stepDX = current.point.x - previous.point.x
            let stepDY = current.point.y - previous.point.y
            let stepDistance = sqrt((stepDX * stepDX) + (stepDY * stepDY))
            let finalDX = finalSample.point.x - previous.point.x
            let finalDY = finalSample.point.y - previous.point.y
            let distanceToFinal = sqrt((finalDX * finalDX) + (finalDY * finalDY))
            let directionAlignment: CGFloat
            if stepDistance > 0.001, distanceToFinal > 0.001 {
                directionAlignment = ((stepDX * finalDX) + (stepDY * finalDY)) / (stepDistance * distanceToFinal)
            } else {
                directionAlignment = 1.0
            }

            guard distanceToFinal <= terminalClusterRadius,
                  stepDistance <= terminalClusterRadius,
                  cumulativeTravel + stepDistance <= terminalClusterTravelLimit,
                  directionAlignment >= terminalDirectionAlignmentThreshold
            else {
                break
            }

            cumulativeTravel += stepDistance
            clusterStart = previousIndex
        }

        if clusterStart > 0, clusterStart < lastIndex - 1 {
            deduplicated.removeSubrange((clusterStart + 1)..<lastIndex)
        }

        return deduplicated
    }

    static func strokeTaperScale(progress: CGFloat, taperIn: CGFloat, taperOut: CGFloat) -> CGFloat {
        BrushStrokeKernel.taperScale(
            progress: progress,
            taperIn: taperIn,
            taperOut: taperOut
        )
    }

    static func strokeProgressTable(_ samples: [StylusSample]) -> [CGFloat] {
        guard !samples.isEmpty else { return [] }
        guard samples.count > 1 else { return [0] }

        var cumulative: [CGFloat] = [0]
        cumulative.reserveCapacity(samples.count)
        var totalLength: CGFloat = 0
        for pair in zip(samples, samples.dropFirst()) {
            let dx = pair.1.point.x - pair.0.point.x
            let dy = pair.1.point.y - pair.0.point.y
            totalLength += sqrt((dx * dx) + (dy * dy))
            cumulative.append(totalLength)
        }

        guard totalLength > 0.001 else {
            return Array(repeating: 0, count: samples.count)
        }

        return cumulative.map { $0 / totalLength }
    }

    static func strokePathLength(_ samples: [StylusSample]) -> CGFloat {
        zip(samples, samples.dropFirst()).reduce(.zero) { partial, pair in
            let dx = pair.1.point.x - pair.0.point.x
            let dy = pair.1.point.y - pair.0.point.y
            return partial + sqrt((dx * dx) + (dy * dy))
        }
    }

    static func strokeEndpointDistance(_ samples: [StylusSample]) -> CGFloat {
        guard let first = samples.first, let last = samples.last else { return .zero }
        let dx = last.point.x - first.point.x
        let dy = last.point.y - first.point.y
        return sqrt((dx * dx) + (dy * dy))
    }

    static func strokeVisualSpan(_ samples: [StylusSample]) -> CGFloat {
        guard let first = samples.first, let last = samples.last else { return .zero }
        var minX = first.point.x
        var maxX = first.point.x
        var minY = first.point.y
        var maxY = first.point.y

        for sample in samples.dropFirst() {
            minX = min(minX, sample.point.x)
            maxX = max(maxX, sample.point.x)
            minY = min(minY, sample.point.y)
            maxY = max(maxY, sample.point.y)
        }

        let width = maxX - minX
        let height = maxY - minY
        let endpointDX = last.point.x - first.point.x
        let endpointDY = last.point.y - first.point.y
        let endpointDistance = sqrt((endpointDX * endpointDX) + (endpointDY * endpointDY))
        return max(width, height, endpointDistance)
    }

    static func averagedStylusSample(_ samples: [StylusSample]) -> StylusSample {
        guard !samples.isEmpty else {
            return StylusSample(
                point: .zero,
                pressure: 1.0,
                altitude: .pi / 2,
                azimuth: 0,
                timestamp: 0
            )
        }
        let count = CGFloat(samples.count)
        let summed = samples.reduce(
            (x: CGFloat.zero, y: CGFloat.zero, pressure: CGFloat.zero, altitude: CGFloat.zero, azimuth: CGFloat.zero, timestamp: TimeInterval.zero)
        ) { partial, sample in
            (
                x: partial.x + sample.point.x,
                y: partial.y + sample.point.y,
                pressure: partial.pressure + sample.pressure,
                altitude: partial.altitude + sample.altitude,
                azimuth: partial.azimuth + sample.azimuth,
                timestamp: partial.timestamp + sample.timestamp
            )
        }
        return StylusSample(
            point: CGPoint(x: summed.x / count, y: summed.y / count),
            pressure: summed.pressure / count,
            altitude: summed.altitude / count,
            azimuth: summed.azimuth / count,
            timestamp: summed.timestamp / Double(samples.count)
        )
    }

    static func interpolatedStylusSample(from start: StylusSample, to end: StylusSample, progress t: CGFloat) -> StylusSample {
        StylusSample(
            point: CGPoint(
                x: start.point.x + ((end.point.x - start.point.x) * t),
                y: start.point.y + ((end.point.y - start.point.y) * t)
            ),
            pressure: start.pressure + ((end.pressure - start.pressure) * t),
            altitude: start.altitude + ((end.altitude - start.altitude) * t),
            azimuth: start.azimuth + ((end.azimuth - start.azimuth) * t),
            timestamp: start.timestamp + ((end.timestamp - start.timestamp) * Double(t))
        )
    }

    static func resolvedStrokeRadius(for sample: StylusSample, progress: CGFloat = 0, brush: BrushRuntimeSettings) -> CGFloat {
        BrushStrokeKernel.resolvedRadius(
            for: sample,
            progress: progress,
            brush: brush
        )
    }

    static func previewNoise(x: CGFloat, y: CGFloat) -> CGFloat {
        BrushStrokeKernel.noise(x: x, y: y)
    }
}
