import CoreGraphics
import Foundation

extension AppFeature {
    static func affineTransformedPoint(
        _ point: CGPoint,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint
    ) -> CGPoint {
        let clampedScaleX = min(max(scaleX, 0.2), 6.0)
        let clampedScaleY = min(max(scaleY, 0.2), 6.0)
        let rotationRadians = CGFloat(rotationDegrees * .pi / 180.0)
        let cosTheta = cos(rotationRadians)
        let sinTheta = sin(rotationRadians)
        let localX = (point.x - pivot.x) * clampedScaleX
        let localY = (point.y - pivot.y) * clampedScaleY
        let rotatedX = (localX * cosTheta) - (localY * sinTheta)
        let rotatedY = (localX * sinTheta) + (localY * cosTheta)
        return CGPoint(
            x: pivot.x + rotatedX + translation.width,
            y: pivot.y + rotatedY + translation.height
        )
    }

    static func affineTransformQuad(
        bounds: CGRect,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint?
    ) -> (quad: TransformQuad, pivot: CGPoint) {
        let resolvedPivot = pivot ?? CGPoint(x: bounds.midX, y: bounds.midY)
        let sourceQuad = TransformQuad(
            topLeft: CGPoint(x: bounds.minX, y: bounds.minY),
            topRight: CGPoint(x: bounds.maxX, y: bounds.minY),
            bottomLeft: CGPoint(x: bounds.minX, y: bounds.maxY),
            bottomRight: CGPoint(x: bounds.maxX, y: bounds.maxY)
        )
        return (
            quad: TransformQuad(
                topLeft: affineTransformedPoint(sourceQuad.topLeft, translation: translation, scaleX: scaleX, scaleY: scaleY, rotationDegrees: rotationDegrees, pivot: resolvedPivot),
                topRight: affineTransformedPoint(sourceQuad.topRight, translation: translation, scaleX: scaleX, scaleY: scaleY, rotationDegrees: rotationDegrees, pivot: resolvedPivot),
                bottomLeft: affineTransformedPoint(sourceQuad.bottomLeft, translation: translation, scaleX: scaleX, scaleY: scaleY, rotationDegrees: rotationDegrees, pivot: resolvedPivot),
                bottomRight: affineTransformedPoint(sourceQuad.bottomRight, translation: translation, scaleX: scaleX, scaleY: scaleY, rotationDegrees: rotationDegrees, pivot: resolvedPivot)
            ),
            pivot: resolvedPivot
        )
    }

    static func effectiveTransformQuad(
        bounds: CGRect,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint?,
        mode: CanvasTransformMode,
        quadOffsets: TransformQuadOffsets
    ) -> (source: TransformQuad, affine: TransformQuad, effective: TransformQuad, pivot: CGPoint) {
        let sourceQuad = TransformQuad(
            topLeft: CGPoint(x: bounds.minX, y: bounds.minY),
            topRight: CGPoint(x: bounds.maxX, y: bounds.minY),
            bottomLeft: CGPoint(x: bounds.minX, y: bounds.maxY),
            bottomRight: CGPoint(x: bounds.maxX, y: bounds.maxY)
        )
        let affine = affineTransformQuad(
            bounds: bounds,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: pivot
        )
        let effective = mode == .freeform && !quadOffsets.isZero
            ? quadOffsets.applying(to: affine.quad)
            : affine.quad
        return (sourceQuad, affine.quad, effective, affine.pivot)
    }

    static func inverseBilinear(point: CGPoint, quad: TransformQuad) -> CGPoint? {
        let a = quad.topLeft
        let b = CGPoint(x: quad.topRight.x - quad.topLeft.x, y: quad.topRight.y - quad.topLeft.y)
        let c = CGPoint(x: quad.bottomLeft.x - quad.topLeft.x, y: quad.bottomLeft.y - quad.topLeft.y)
        let d = CGPoint(
            x: quad.bottomRight.x - quad.topRight.x - quad.bottomLeft.x + quad.topLeft.x,
            y: quad.bottomRight.y - quad.topRight.y - quad.bottomLeft.y + quad.topLeft.y
        )
        let ap = CGPoint(x: a.x - point.x, y: a.y - point.y)

        func cross(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
            (lhs.x * rhs.y) - (lhs.y * rhs.x)
        }

        let quadratic = cross(d, b)
        let linear = cross(c, b) + cross(d, ap)
        let constant = cross(c, ap)
        var candidates: [CGFloat] = []

        if abs(quadratic) < 1.0e-7 {
            if abs(linear) > 1.0e-7 {
                candidates.append(-constant / linear)
            }
        } else {
            let discriminant = max((linear * linear) - (4 * quadratic * constant), 0)
            let sqrtDiscriminant = sqrt(discriminant)
            candidates.append((-linear + sqrtDiscriminant) / (2 * quadratic))
            candidates.append((-linear - sqrtDiscriminant) / (2 * quadratic))
        }

        for u in candidates where u >= -0.001 && u <= 1.001 {
            let denominatorX = c.x + (d.x * u)
            let denominatorY = c.y + (d.y * u)
            let v: CGFloat
            if abs(denominatorX) > abs(denominatorY), abs(denominatorX) > 1.0e-7 {
                v = -((ap.x + (b.x * u)) / denominatorX)
            } else if abs(denominatorY) > 1.0e-7 {
                v = -((ap.y + (b.y * u)) / denominatorY)
            } else {
                continue
            }
            if v >= -0.001 && v <= 1.001 {
                return CGPoint(x: max(0, min(1, u)), y: max(0, min(1, v)))
            }
        }

        return nil
    }

    static func sampleSourcePoint(
        destinationPoint: CGPoint,
        sourceQuad: TransformQuad,
        destinationQuad: TransformQuad
    ) -> CGPoint? {
        guard let uv = inverseBilinear(point: destinationPoint, quad: destinationQuad) else { return nil }
        return CGPoint(
            x: sourceQuad.topLeft.x + ((sourceQuad.topRight.x - sourceQuad.topLeft.x) * uv.x),
            y: sourceQuad.topLeft.y + ((sourceQuad.bottomLeft.y - sourceQuad.topLeft.y) * uv.y)
        )
    }

    static func transformedLayerPixels(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selection: CanvasSelection?,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint?,
        mode: CanvasTransformMode,
        quadOffsets: TransformQuadOffsets
    ) -> Data? {
        guard
            translation != .zero ||
            abs(scaleX - 1.0) > 0.001 ||
            abs(scaleY - 1.0) > 0.001 ||
            abs(rotationDegrees) > 0.001 ||
            !quadOffsets.isZero
        else {
            return nil
        }

        let expectedCount = canvasWidth * canvasHeight * 4
        guard source.count == expectedCount else { return nil }

        let sourceBytes = [UInt8](source)
        let mask = selection.map { expandedMask(from: $0, canvasWidth: canvasWidth, canvasHeight: canvasHeight) }
            ?? Self.alphaMask(from: sourceBytes, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
        guard let bounds = Self.transformationBounds(selection: selection, sourceBytes: sourceBytes, canvasWidth: canvasWidth, canvasHeight: canvasHeight) else {
            return nil
        }
        let resolved = effectiveTransformQuad(
            bounds: bounds,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: pivot,
            mode: mode,
            quadOffsets: quadOffsets
        )

        var destination = sourceBytes
        for index in 0..<(canvasWidth * canvasHeight) where mask[index] != 0 {
            let pixelOffset = index * 4
            destination[pixelOffset] = 0
            destination[pixelOffset + 1] = 0
            destination[pixelOffset + 2] = 0
            destination[pixelOffset + 3] = 0
        }
        let clampedMinX = max(Int(floor(resolved.effective.bounds.minX)) - 1, 0)
        let clampedMaxX = min(Int(ceil(resolved.effective.bounds.maxX)) + 1, canvasWidth - 1)
        let clampedMinY = max(Int(floor(resolved.effective.bounds.minY)) - 1, 0)
        let clampedMaxY = min(Int(ceil(resolved.effective.bounds.maxY)) + 1, canvasHeight - 1)
        let rotationRadians = CGFloat(rotationDegrees * .pi / 180.0)
        let cosTheta = cos(rotationRadians)
        let sinTheta = sin(rotationRadians)
        let clampedScaleX = min(max(scaleX, 0.2), 6.0)
        let clampedScaleY = min(max(scaleY, 0.2), 6.0)

        for y in clampedMinY...clampedMaxY {
            for x in clampedMinX...clampedMaxX {
                let destinationPoint = CGPoint(x: CGFloat(x), y: CGFloat(y))
                let sourcePoint: CGPoint?
                if mode == .standard || quadOffsets.isZero {
                    let shiftedX = destinationPoint.x - translation.width - resolved.pivot.x
                    let shiftedY = destinationPoint.y - translation.height - resolved.pivot.y
                    let unrotatedX = (shiftedX * cosTheta) + (shiftedY * sinTheta)
                    let unrotatedY = (-shiftedX * sinTheta) + (shiftedY * cosTheta)
                    sourcePoint = CGPoint(
                        x: (unrotatedX / clampedScaleX) + resolved.pivot.x,
                        y: (unrotatedY / clampedScaleY) + resolved.pivot.y
                    )
                } else {
                    sourcePoint = sampleSourcePoint(
                        destinationPoint: destinationPoint,
                        sourceQuad: resolved.source,
                        destinationQuad: resolved.effective
                    )
                }

                guard let sourcePoint else { continue }
                let sourcePixelX = Int(sourcePoint.x.rounded())
                let sourcePixelY = Int(sourcePoint.y.rounded())
                guard sourcePixelX >= 0, sourcePixelX < canvasWidth, sourcePixelY >= 0, sourcePixelY < canvasHeight else { continue }
                let sourceIndex = (sourcePixelY * canvasWidth) + sourcePixelX
                guard mask[sourceIndex] != 0 else { continue }
                let sourceOffset = sourceIndex * 4
                guard sourceBytes[sourceOffset + 3] != 0 else { continue }
                let destinationOffset = ((y * canvasWidth) + x) * 4
                destination[destinationOffset] = sourceBytes[sourceOffset]
                destination[destinationOffset + 1] = sourceBytes[sourceOffset + 1]
                destination[destinationOffset + 2] = sourceBytes[sourceOffset + 2]
                destination[destinationOffset + 3] = sourceBytes[sourceOffset + 3]
            }
        }

        return Data(destination)
    }

    static func transformedSelection(
        _ selection: CanvasSelection?,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint?,
        mode: CanvasTransformMode,
        quadOffsets: TransformQuadOffsets,
        canvasSize: CGSize
    ) -> CanvasSelection? {
        guard let selection else { return nil }
        let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
        let canvasHeight = max(Int(canvasSize.height.rounded()), 1)
        let mask = expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
        let bounds = selection.bounds
        let resolved = effectiveTransformQuad(
            bounds: bounds,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: pivot,
            mode: mode,
            quadOffsets: quadOffsets
        )
        var transformed = [UInt8](repeating: 0, count: canvasWidth * canvasHeight)
        let clampedMinX = max(Int(floor(resolved.effective.bounds.minX)) - 1, 0)
        let clampedMaxX = min(Int(ceil(resolved.effective.bounds.maxX)) + 1, canvasWidth - 1)
        let clampedMinY = max(Int(floor(resolved.effective.bounds.minY)) - 1, 0)
        let clampedMaxY = min(Int(ceil(resolved.effective.bounds.maxY)) + 1, canvasHeight - 1)
        let rotationRadians = CGFloat(rotationDegrees * .pi / 180.0)
        let cosTheta = cos(rotationRadians)
        let sinTheta = sin(rotationRadians)
        let clampedScaleX = min(max(scaleX, 0.2), 6.0)
        let clampedScaleY = min(max(scaleY, 0.2), 6.0)

        for y in clampedMinY...clampedMaxY {
            for x in clampedMinX...clampedMaxX {
                let destinationPoint = CGPoint(x: CGFloat(x), y: CGFloat(y))
                let sourcePoint: CGPoint?
                if mode == .standard || quadOffsets.isZero {
                    let shiftedX = destinationPoint.x - translation.width - resolved.pivot.x
                    let shiftedY = destinationPoint.y - translation.height - resolved.pivot.y
                    let unrotatedX = (shiftedX * cosTheta) + (shiftedY * sinTheta)
                    let unrotatedY = (-shiftedX * sinTheta) + (shiftedY * cosTheta)
                    sourcePoint = CGPoint(
                        x: (unrotatedX / clampedScaleX) + resolved.pivot.x,
                        y: (unrotatedY / clampedScaleY) + resolved.pivot.y
                    )
                } else {
                    sourcePoint = sampleSourcePoint(
                        destinationPoint: destinationPoint,
                        sourceQuad: resolved.source,
                        destinationQuad: resolved.effective
                    )
                }

                guard let sourcePoint else { continue }
                let sourcePixelX = Int(sourcePoint.x.rounded())
                let sourcePixelY = Int(sourcePoint.y.rounded())
                guard sourcePixelX >= 0, sourcePixelX < canvasWidth, sourcePixelY >= 0, sourcePixelY < canvasHeight else { continue }
                let sourceIndex = (sourcePixelY * canvasWidth) + sourcePixelX
                guard mask[sourceIndex] != 0 else { continue }
                transformed[(y * canvasWidth) + x] = 255
            }
        }

        return croppedSelection(from: transformed, width: canvasWidth, height: canvasHeight, mode: selection.mode)
    }

    static func layerMaskData(
        from selection: CanvasSelection?,
        canvasSize: CGSize
    ) -> Data? {
        guard let selection else { return nil }
        let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
        let canvasHeight = max(Int(canvasSize.height.rounded()), 1)
        return Data(expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight))
    }

    static func alphaMask(from sourceBytes: [UInt8], canvasWidth: Int, canvasHeight: Int) -> [UInt8] {
        var mask = [UInt8](repeating: 0, count: canvasWidth * canvasHeight)
        for index in 0..<(canvasWidth * canvasHeight) {
            if sourceBytes[index * 4 + 3] != 0 {
                mask[index] = 255
            }
        }
        return mask
    }

    static func transformationBounds(
        selection: CanvasSelection?,
        sourceBytes: [UInt8],
        canvasWidth: Int,
        canvasHeight: Int
    ) -> CGRect? {
        if let selection, !selection.isEmpty {
            return selection.bounds
        }

        var minX = canvasWidth
        var minY = canvasHeight
        var maxX = -1
        var maxY = -1
        for y in 0..<canvasHeight {
            for x in 0..<canvasWidth {
                if sourceBytes[((y * canvasWidth) + x) * 4 + 3] == 0 { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
