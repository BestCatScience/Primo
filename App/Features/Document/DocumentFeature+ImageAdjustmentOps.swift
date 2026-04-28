import Foundation
import PrimoDocumentContracts

extension DocumentFeature {
    struct GradientMapStop {
        var position: Double
        var red: UInt8
        var green: UInt8
        var blue: UInt8
    }

    static func gradientMapStops(for preset: GradientMapPreset) -> [GradientMapStop] {
        switch preset {
        case .graphite:
            return [
                GradientMapStop(position: 0.0, red: 17, green: 21, blue: 27),
                GradientMapStop(position: 0.38, red: 84, green: 93, blue: 108),
                GradientMapStop(position: 1.0, red: 243, green: 244, blue: 246)
            ]
        case .sepia:
            return [
                GradientMapStop(position: 0.0, red: 28, green: 17, blue: 12),
                GradientMapStop(position: 0.42, red: 123, green: 74, blue: 40),
                GradientMapStop(position: 1.0, red: 241, green: 220, blue: 184)
            ]
        case .ocean:
            return [
                GradientMapStop(position: 0.0, red: 8, green: 19, blue: 44),
                GradientMapStop(position: 0.45, red: 27, green: 110, blue: 171),
                GradientMapStop(position: 1.0, red: 192, green: 241, blue: 255)
            ]
        case .sunset:
            return [
                GradientMapStop(position: 0.0, red: 36, green: 11, blue: 54),
                GradientMapStop(position: 0.4, red: 173, green: 58, blue: 91),
                GradientMapStop(position: 0.72, red: 244, green: 142, blue: 68),
                GradientMapStop(position: 1.0, red: 255, green: 223, blue: 128)
            ]
        case .toxic:
            return [
                GradientMapStop(position: 0.0, red: 4, green: 23, blue: 18),
                GradientMapStop(position: 0.44, red: 35, green: 172, blue: 106),
                GradientMapStop(position: 1.0, red: 227, green: 255, blue: 111)
            ]
        }
    }

    static func gradientMapStops(for settings: GradientMapSettings) -> [GradientMapStop] {
        normalizeGradientMapSettings(settings).stops.map {
            GradientMapStop(
                position: $0.position,
                red: $0.red,
                green: $0.green,
                blue: $0.blue
            )
        }
    }

    static func gradientMapSettings(for preset: GradientMapPreset) -> GradientMapSettings {
        let stops = gradientMapStops(for: preset)
        return GradientMapSettings(
            stops: stops.map {
                GradientMapStopSettings(
                    position: $0.position,
                    red: $0.red,
                    green: $0.green,
                    blue: $0.blue
                )
            }
        )
    }

    static func normalizeGradientMapSettings(_ settings: GradientMapSettings) -> GradientMapSettings {
        var sortedStops = settings.stops.sorted { $0.position < $1.position }

        if sortedStops.count < 2 {
            sortedStops = [
                GradientMapStopSettings(position: 0.0, red: 0, green: 0, blue: 0),
                GradientMapStopSettings(position: 1.0, red: 255, green: 255, blue: 255)
            ]
        }

        for index in sortedStops.indices {
            sortedStops[index].position = min(max(sortedStops[index].position, 0.0), 1.0)
        }

        sortedStops[0].position = 0.0
        sortedStops[sortedStops.count - 1].position = 1.0

        if sortedStops.count > 2 {
            for index in 1..<(sortedStops.count - 1) {
                let lowerBound = sortedStops[index - 1].position + 0.01
                let upperBound = sortedStops[index + 1].position - 0.01
                sortedStops[index].position = min(max(sortedStops[index].position, lowerBound), upperBound)
            }
        }

        return GradientMapSettings(stops: sortedStops)
    }

    static func mappedGradientColor(for value: Double, stops: [GradientMapStop]) -> (red: UInt8, green: UInt8, blue: UInt8) {
        let clampedValue = min(max(value, 0.0), 1.0)
        guard let upperIndex = stops.firstIndex(where: { clampedValue <= $0.position }) else {
            let last = stops[stops.count - 1]
            return (last.red, last.green, last.blue)
        }
        if upperIndex == 0 {
            let first = stops[0]
            return (first.red, first.green, first.blue)
        }

        let lower = stops[upperIndex - 1]
        let upper = stops[upperIndex]
        let span = max(upper.position - lower.position, 0.0001)
        let t = (clampedValue - lower.position) / span

        func mix(_ a: UInt8, _ b: UInt8) -> UInt8 {
            UInt8(max(0, min(255, Int((Double(a) + ((Double(b) - Double(a)) * t)).rounded()))))
        }

        return (
            red: mix(lower.red, upper.red),
            green: mix(lower.green, upper.green),
            blue: mix(lower.blue, upper.blue)
        )
    }

}
