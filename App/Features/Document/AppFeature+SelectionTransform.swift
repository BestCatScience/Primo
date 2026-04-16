import ComposableArchitecture
import CoreGraphics
import Foundation

extension AppFeature {
    func applyTransform(state: inout State) -> Effect<Action> {
        let translation = CGSize(
            width: state.canvas.transformPreviewOffset.width.rounded(),
            height: state.canvas.transformPreviewOffset.height.rounded()
        )
        let scaleX = state.canvas.transformPreviewScaleX
        let scaleY = state.canvas.transformPreviewScaleY
        let rotationDegrees = state.canvas.transformPreviewRotationDegrees
        let transformMode = state.canvas.transformMode
        let transformPivot = state.canvas.transformPivot
        let quadOffsets = state.canvas.transformQuadOffsets
        guard state.canvas.transformHasPreview else { return .none }
        if
            state.canvas.selection == nil,
            var textLayer = state.canvas.activeTextLayer
        {
            textLayer.position = CGPoint(
                x: textLayer.position.x + translation.width,
                y: textLayer.position.y + translation.height
            )
            textLayer.scale = min(max(textLayer.scale * Double((scaleX + scaleY) * 0.5), 0.2), 6.0)
            textLayer.rotationDegrees += rotationDegrees
            guard paintDocumentClient.setTextLayer(state.canvas.activeLayerIndex, textLayer) else {
                state.canvas.resetTransformPreview()
                return .none
            }
            state.canvas.resetTransformPreview()
            applyDirtyPresentation(state: &state)
            return .none
        }
        let activeLayerIndex = state.canvas.activeLayerIndex
        let source = paintDocumentClient.pixelDataForLayer(activeLayerIndex)
        let canvasWidth = max(Int(state.canvas.canvasSize.width.rounded()), 1)
        let canvasHeight = max(Int(state.canvas.canvasSize.height.rounded()), 1)
        guard let transformed = Self.transformedLayerPixels(
            source: source,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            selection: state.canvas.selection,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: transformPivot,
            mode: transformMode,
            quadOffsets: quadOffsets
        ) else {
            state.canvas.resetTransformPreview()
            return .none
        }
        paintDocumentClient.replaceLayerPixels(activeLayerIndex, transformed)
        if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == activeLayerIndex }) {
            state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
            state.canvas.localBufferRevision += 1
        }
        state.canvas.selection = Self.transformedSelection(
            state.canvas.selection,
            translation: translation,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDegrees: rotationDegrees,
            pivot: transformPivot,
            mode: transformMode,
            quadOffsets: quadOffsets,
            canvasSize: state.canvas.canvasSize
        )
        state.canvas.resetTransformPreview()
        applyDirtyPresentation(state: &state)
        return .none
    }

    static func combinedSelection(
        existing: CanvasSelection?,
        incoming: CanvasSelection?,
        mode: SelectionCombineMode,
        canvasSize: CGSize
    ) -> CanvasSelection? {
        switch mode {
        case .replace:
            return incoming
        case .add, .subtract:
            guard let incoming else { return existing }
            guard let existing else {
                return mode == .add ? incoming : nil
            }

            let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
            let canvasHeight = max(Int(canvasSize.height.rounded()), 1)
            var baseMask = expandedMask(from: existing, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
            let incomingMask = expandedMask(from: incoming, canvasWidth: canvasWidth, canvasHeight: canvasHeight)

            for index in 0..<baseMask.count {
                switch mode {
                case .replace:
                    break
                case .add:
                    baseMask[index] = max(baseMask[index], incomingMask[index])
                case .subtract:
                    if incomingMask[index] != 0 {
                        baseMask[index] = 0
                    }
                }
            }

            return croppedSelection(from: baseMask, width: canvasWidth, height: canvasHeight, mode: incoming.mode)
        }
    }

    static func expandedMask(from selection: CanvasSelection, canvasWidth: Int, canvasHeight: Int) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: canvasWidth * canvasHeight)
        let originX = max(Int(selection.bounds.minX.rounded(.down)), 0)
        let originY = max(Int(selection.bounds.minY.rounded(.down)), 0)
        let width = min(selection.maskWidth, canvasWidth - originX)
        let height = min(selection.maskHeight, canvasHeight - originY)
        guard width > 0, height > 0 else { return result }

        selection.maskData.withUnsafeBytes { bytes in
            guard let source = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for y in 0..<height {
                for x in 0..<width {
                    let sourceIndex = (y * selection.maskWidth) + x
                    let destinationIndex = ((originY + y) * canvasWidth) + (originX + x)
                    result[destinationIndex] = source[sourceIndex]
                }
            }
        }
        return result
    }

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

    static func pointInTriangle(_ point: CGPoint, _ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Bool {
        let area = ((b.x - a.x) * (c.y - a.y)) - ((b.y - a.y) * (c.x - a.x))
        guard abs(area) > 0.0001 else { return false }
        let s = (((a.y - c.y) * (point.x - c.x)) + ((c.x - a.x) * (point.y - c.y))) / area
        let t = (((c.y - b.y) * (point.x - c.x)) + ((b.x - c.x) * (point.y - c.y))) / area
        let u = 1.0 - s - t
        return s >= -0.0001 && t >= -0.0001 && u >= -0.0001
    }

    static func pointInQuad(_ point: CGPoint, _ quad: TransformQuad) -> Bool {
        pointInTriangle(point, quad.topLeft, quad.topRight, quad.bottomLeft) ||
        pointInTriangle(point, quad.bottomRight, quad.topRight, quad.bottomLeft)
    }

    static func solveLinearSystem(_ matrix: [[Double]], _ values: [Double]) -> [Double]? {
        let count = values.count
        guard matrix.count == count, matrix.allSatisfy({ $0.count == count }) else { return nil }
        var augmented = matrix.enumerated().map { index, row in
            row + [values[index]]
        }

        for pivotIndex in 0..<count {
            var bestRow = pivotIndex
            var bestValue = abs(augmented[pivotIndex][pivotIndex])
            for row in (pivotIndex + 1)..<count {
                let value = abs(augmented[row][pivotIndex])
                if value > bestValue {
                    bestValue = value
                    bestRow = row
                }
            }
            guard bestValue > 1.0e-9 else { return nil }
            if bestRow != pivotIndex {
                augmented.swapAt(bestRow, pivotIndex)
            }

            let pivotValue = augmented[pivotIndex][pivotIndex]
            for column in pivotIndex...count {
                augmented[pivotIndex][column] /= pivotValue
            }

            for row in 0..<count where row != pivotIndex {
                let factor = augmented[row][pivotIndex]
                guard abs(factor) > 1.0e-12 else { continue }
                for column in pivotIndex...count {
                    augmented[row][column] -= factor * augmented[pivotIndex][column]
                }
            }
        }

        return augmented.map { $0[count] }
    }

    static func homography(from source: TransformQuad, to destination: TransformQuad) -> [Double]? {
        let sourcePoints = source.points
        let destinationPoints = destination.points
        var matrix: [[Double]] = []
        var values: [Double] = []
        matrix.reserveCapacity(8)
        values.reserveCapacity(8)

        for (src, dst) in zip(sourcePoints, destinationPoints) {
            let x = Double(src.x)
            let y = Double(src.y)
            let u = Double(dst.x)
            let v = Double(dst.y)
            matrix.append([x, y, 1, 0, 0, 0, -x * u, -y * u])
            values.append(u)
            matrix.append([0, 0, 0, x, y, 1, -x * v, -y * v])
            values.append(v)
        }

        guard let solution = solveLinearSystem(matrix, values) else { return nil }
        return [
            solution[0], solution[1], solution[2],
            solution[3], solution[4], solution[5],
            solution[6], solution[7], 1.0
        ]
    }

    static func applyHomography(_ matrix: [Double], to point: CGPoint) -> CGPoint? {
        guard matrix.count == 9 else { return nil }
        let x = Double(point.x)
        let y = Double(point.y)
        let denominator = (matrix[6] * x) + (matrix[7] * y) + matrix[8]
        guard abs(denominator) > 1.0e-9 else { return nil }
        return CGPoint(
            x: ((matrix[0] * x) + (matrix[1] * y) + matrix[2]) / denominator,
            y: ((matrix[3] * x) + (matrix[4] * y) + matrix[5]) / denominator
        )
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

    static func adjustedSelection(
        _ selection: CanvasSelection?,
        canvasSize: CGSize,
        expansion: Int,
        isInverted: Bool
    ) -> CanvasSelection? {
        guard let selection else { return nil }
        let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
        let canvasHeight = max(Int(canvasSize.height.rounded()), 1)
        var mask = expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight)

        if expansion > 0 {
            mask = expandedSelectionMask(mask, width: canvasWidth, height: canvasHeight, expansion: expansion)
        } else if expansion < 0 {
            mask = contractedSelectionMask(mask, width: canvasWidth, height: canvasHeight, contraction: abs(expansion))
        }

        if isInverted {
            mask = mask.map { $0 == 0 ? 255 : 0 }
        }

        return croppedSelection(from: mask, width: canvasWidth, height: canvasHeight, mode: selection.mode)
    }

    static func invertedSelection(
        _ selection: CanvasSelection?,
        canvasSize: CGSize,
        mode: SelectionToolMode
    ) -> CanvasSelection? {
        let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
        let canvasHeight = max(Int(canvasSize.height.rounded()), 1)

        if let selection {
            return adjustedSelection(
                selection,
                canvasSize: canvasSize,
                expansion: 0,
                isInverted: true
            )
        }

        let fullMask = [UInt8](repeating: 255, count: canvasWidth * canvasHeight)
        return croppedSelection(from: fullMask, width: canvasWidth, height: canvasHeight, mode: mode)
    }

    static func featheredSelection(
        _ selection: CanvasSelection?,
        canvasSize: CGSize,
        radius: Int
    ) -> CanvasSelection? {
        guard let selection else { return nil }
        let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
        let canvasHeight = max(Int(canvasSize.height.rounded()), 1)
        let mask = expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
        let featheredMask = featheredSelectionMask(mask, width: canvasWidth, height: canvasHeight, radius: radius)
        return croppedSelection(from: featheredMask, width: canvasWidth, height: canvasHeight, mode: selection.mode)
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

    static func makeLassoSelection(from points: [CGPoint], canvasSize: CGSize) -> CanvasSelection? {
        guard points.count >= 3 else { return nil }

        let polygon = closedPolygon(points, canvasSize: canvasSize)
        guard polygon.count >= 3 else { return nil }

        let path = CGMutablePath()
        path.addLines(between: polygon)
        path.closeSubpath()
        let bounds = path.boundingBoxOfPath.integral
        guard !bounds.isNull, !bounds.isEmpty else { return nil }

        let minX = max(0, Int(bounds.minX.rounded(.down)))
        let minY = max(0, Int(bounds.minY.rounded(.down)))
        let maxX = max(minX + 1, Int(bounds.maxX.rounded(.up)))
        let maxY = max(minY + 1, Int(bounds.maxY.rounded(.up)))
        let width = maxX - minX
        let height = maxY - minY
        guard width > 0, height > 0 else { return nil }

        var mask = Data(count: width * height)
        mask.withUnsafeMutableBytes { bytes in
            guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for y in 0..<height {
                for x in 0..<width {
                    let samplePoint = CGPoint(x: CGFloat(minX + x) + 0.5, y: CGFloat(minY + y) + 0.5)
                    if path.contains(samplePoint) {
                        base[(y * width) + x] = 255
                    }
                }
            }
        }

        let bytes = [UInt8](mask)
        return croppedSelection(from: bytes, width: width, height: height, mode: .lasso).map {
            CanvasSelection(
                bounds: CGRect(
                    x: CGFloat(minX) + $0.bounds.minX,
                    y: CGFloat(minY) + $0.bounds.minY,
                    width: $0.bounds.width,
                    height: $0.bounds.height
                ),
                maskWidth: $0.maskWidth,
                maskHeight: $0.maskHeight,
                maskData: $0.maskData,
                mode: .lasso
            )
        }
    }

    static func makeAutoSelection(
        at point: CGPoint,
        snapshot: MetalDocumentSnapshot?,
        layerIndex: Int,
        thresholdMode: FillThresholdMode,
        opacityTolerance: Double,
        colorTolerance: Double,
        expansion: Int
    ) -> CanvasSelection? {
        guard
            let snapshot,
            let layer = snapshot.layers.first(where: { $0.index == layerIndex })
        else {
            return nil
        }

        let width = snapshot.width
        let height = snapshot.height
        guard width > 0, height > 0 else { return nil }

        let startX = min(max(Int(point.x.rounded()), 0), width - 1)
        let startY = min(max(Int(point.y.rounded()), 0), height - 1)
        let expectedCount = width * height * 4
        guard layer.pixelData.count == expectedCount else { return nil }

        var selected = [UInt8](repeating: 0, count: width * height)
        var queue: [(Int, Int)] = [(startX, startY)]
        var head = 0
        var minX = startX
        var minY = startY
        var maxX = startX
        var maxY = startY

        layer.pixelData.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            let startOffset = ((startY * width) + startX) * 4
            let targetR = base[startOffset]
            let targetG = base[startOffset + 1]
            let targetB = base[startOffset + 2]
            let targetA = base[startOffset + 3]

            func matches(_ x: Int, _ y: Int) -> Bool {
                let offset = ((y * width) + x) * 4
                if thresholdMode == .color {
                    let dr = (Double(base[offset]) - Double(targetR)) / 255.0
                    let dg = (Double(base[offset + 1]) - Double(targetG)) / 255.0
                    let db = (Double(base[offset + 2]) - Double(targetB)) / 255.0
                    let distance = sqrt((dr * dr) + (dg * dg) + (db * db)) / sqrt(3.0)
                    return distance <= min(max(colorTolerance, 0.0), 1.0)
                }
                let sameColor =
                    base[offset] == targetR &&
                    base[offset + 1] == targetG &&
                    base[offset + 2] == targetB
                let alphaDistance = abs(Double(base[offset + 3]) - Double(targetA)) / 255.0
                return sameColor && alphaDistance <= min(max(opacityTolerance, 0.0), 1.0)
            }

            while head < queue.count {
                let (x, y) = queue[head]
                head += 1
                guard x >= 0, x < width, y >= 0, y < height else { continue }
                let index = (y * width) + x
                guard selected[index] == 0, matches(x, y) else { continue }

                selected[index] = 255
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)

                queue.append((x - 1, y))
                queue.append((x + 1, y))
                queue.append((x, y - 1))
                queue.append((x, y + 1))
            }
        }

        guard minX <= maxX, minY <= maxY else { return nil }
        let expandedMask = expandedSelectionMask(
            selected,
            width: width,
            height: height,
            expansion: max(0, expansion)
        )
        return croppedSelection(
            from: expandedMask,
            width: width,
            height: height,
            mode: .auto
        )
    }

    static func makeColorRangeSelection(
        request: ColorRangeSelectionRequest,
        snapshot: MetalDocumentSnapshot?,
        activeLayerIndex: Int,
        mode: SelectionToolMode
    ) -> CanvasSelection? {
        guard let snapshot else { return nil }
        let width = snapshot.width
        let height = snapshot.height
        guard width > 0, height > 0 else { return nil }

        let pixelData: Data
        switch request.source {
        case .activeLayer:
            guard let layer = snapshot.layers.first(where: { $0.index == activeLayerIndex }) else { return nil }
            pixelData = layer.pixelData
        case .canvas:
            pixelData = snapshot.compositePixelData
        }

        guard pixelData.count == width * height * 4 else { return nil }
        let tolerance = min(max(request.tolerance, 0.0), 1.0)
        let minimumAlpha = min(max(request.minimumAlpha, 0.0), 1.0)
        var selected = [UInt8](repeating: 0, count: width * height)

        pixelData.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for index in 0..<(width * height) {
                let offset = index * 4
                let alpha = Double(base[offset + 3]) / 255.0
                guard alpha >= minimumAlpha else { continue }

                let dr = (Double(base[offset]) - Double(request.red)) / 255.0
                let dg = (Double(base[offset + 1]) - Double(request.green)) / 255.0
                let db = (Double(base[offset + 2]) - Double(request.blue)) / 255.0
                let distance = sqrt((dr * dr) + (dg * dg) + (db * db)) / sqrt(3.0)
                if distance <= tolerance {
                    selected[index] = 255
                }
            }
        }

        let expandedMask = request.expansion > 0
            ? expandedSelectionMask(selected, width: width, height: height, expansion: request.expansion)
            : selected
        return croppedSelection(from: expandedMask, width: width, height: height, mode: mode)
    }

    static func expandedSelectionMask(_ source: [UInt8], width: Int, height: Int, expansion: Int) -> [UInt8] {
        guard expansion > 0 else { return source }
        var result = source
        let selectedPoints = source.enumerated().compactMap { index, value -> (Int, Int)? in
            guard value != 0 else { return nil }
            return (index % width, index / width)
        }

        for (seedX, seedY) in selectedPoints {
            for dy in -expansion...expansion {
                for dx in -expansion...expansion {
                    guard abs(dx) + abs(dy) <= expansion else { continue }
                    let x = seedX + dx
                    let y = seedY + dy
                    guard x >= 0, x < width, y >= 0, y < height else { continue }
                    result[(y * width) + x] = 255
                }
            }
        }
        return result
    }

    static func contractedSelectionMask(_ source: [UInt8], width: Int, height: Int, contraction: Int) -> [UInt8] {
        guard contraction > 0 else { return source }
        var current = source

        for _ in 0..<contraction {
            var next = current
            for y in 0..<height {
                for x in 0..<width {
                    let index = (y * width) + x
                    guard current[index] != 0 else { continue }

                    let hasOutsideNeighbor =
                        x == 0 || x == width - 1 || y == 0 || y == height - 1 ||
                        current[index - 1] == 0 ||
                        current[index + 1] == 0 ||
                        current[index - width] == 0 ||
                        current[index + width] == 0

                    if hasOutsideNeighbor {
                        next[index] = 0
                    }
                }
            }
            current = next
        }

        return current
    }

    static func featheredSelectionMask(_ source: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8] {
        guard radius > 0, width > 0, height > 0 else { return source }

        let kernelSize = (radius * 2) + 1
        let normalization = Double(kernelSize)
        var horizontal = [Double](repeating: 0, count: width * height)
        var vertical = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            var runningSum = 0.0
            for sampleX in -radius...radius {
                let clampedX = min(max(sampleX, 0), width - 1)
                runningSum += Double(source[(y * width) + clampedX])
            }

            for x in 0..<width {
                horizontal[(y * width) + x] = runningSum / normalization
                let outgoingX = max(x - radius, 0)
                let incomingX = min(x + radius + 1, width - 1)
                runningSum -= Double(source[(y * width) + outgoingX])
                runningSum += Double(source[(y * width) + incomingX])
            }
        }

        for x in 0..<width {
            var runningSum = 0.0
            for sampleY in -radius...radius {
                let clampedY = min(max(sampleY, 0), height - 1)
                runningSum += horizontal[(clampedY * width) + x]
            }

            for y in 0..<height {
                let blurred = runningSum / normalization
                vertical[(y * width) + x] = UInt8(max(0, min(255, Int(blurred.rounded()))))
                let outgoingY = max(y - radius, 0)
                let incomingY = min(y + radius + 1, height - 1)
                runningSum -= horizontal[(outgoingY * width) + x]
                runningSum += horizontal[(incomingY * width) + x]
            }
        }

        return vertical.map { $0 < 2 ? 0 : $0 }
    }

    static func croppedSelection(from source: [UInt8], width: Int, height: Int, mode: SelectionToolMode) -> CanvasSelection? {
        guard let first = source.firstIndex(where: { $0 != 0 }) else { return nil }
        var minX = first % width
        var maxX = minX
        var minY = first / width
        var maxY = minY

        for index in source.indices where source[index] != 0 {
            let x = index % width
            let y = index / width
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }

        let croppedWidth = (maxX - minX) + 1
        let croppedHeight = (maxY - minY) + 1
        guard croppedWidth > 0, croppedHeight > 0 else { return nil }

        var cropped = Data(count: croppedWidth * croppedHeight)
        cropped.withUnsafeMutableBytes { bytes in
            guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for y in 0..<croppedHeight {
                for x in 0..<croppedWidth {
                    let sourceIndex = ((minY + y) * width) + (minX + x)
                    base[(y * croppedWidth) + x] = source[sourceIndex]
                }
            }
        }

        return CanvasSelection(
            bounds: CGRect(x: minX, y: minY, width: croppedWidth, height: croppedHeight),
            maskWidth: croppedWidth,
            maskHeight: croppedHeight,
            maskData: cropped,
            mode: mode
        )
    }

    static func closedPolygon(_ points: [CGPoint], canvasSize: CGSize) -> [CGPoint] {
        let clamped = points.map {
            CGPoint(
                x: min(max($0.x, 0), max(canvasSize.width - 1, 0)),
                y: min(max($0.y, 0), max(canvasSize.height - 1, 0))
            )
        }
        guard let first = clamped.first, let last = clamped.last else { return [] }
        if hypot(first.x - last.x, first.y - last.y) <= 4 {
            return clamped
        }
        return clamped + [first]
    }
}
