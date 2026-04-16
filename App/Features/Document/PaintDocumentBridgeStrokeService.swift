import CoreGraphics

struct PaintDocumentBridgeStrokeService {
    func makeStrokePoint(from sample: StylusSample) -> APStrokePoint {
        let point = APStrokePoint()
        point.x = sample.point.x
        point.y = sample.point.y
        point.pressure = normalizedPressure(sample.pressure)
        point.altitude = sample.altitude
        point.azimuth = sample.azimuth
        point.timestamp = sample.timestamp
        return point
    }

    func normalizedPressure(_ pressure: CGFloat) -> CGFloat {
        max(0.08, min(max(pressure, 0.0), 1.0))
    }
}
