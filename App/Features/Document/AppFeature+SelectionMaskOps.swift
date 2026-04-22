import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain

extension AppFeature {
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
            mask = invertedSelectionMask(mask)
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
        let selected = MetalDocumentProcessingClient.shared.colorRangeSelection(
            pixelData: pixelData,
            width: width,
            height: height,
            request: request
        ) ?? cpuColorRangeSelectionMask(
            pixelData: pixelData,
            width: width,
            height: height,
            request: request
        )

        let expandedMask = request.expansion > 0
            ? expandedSelectionMask(selected, width: width, height: height, expansion: request.expansion)
            : selected
        return croppedSelection(from: expandedMask, width: width, height: height, mode: mode)
    }

    static func cpuColorRangeSelectionMask(
        pixelData: Data,
        width: Int,
        height: Int,
        request: ColorRangeSelectionRequest
    ) -> [UInt8] {
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

        return selected
    }

    static func expandedSelectionMask(_ source: [UInt8], width: Int, height: Int, expansion: Int) -> [UInt8] {
        MetalDocumentProcessingClient.shared.expandedMask(source, width: width, height: height, expansion: expansion)
            ?? cpuExpandedSelectionMask(source, width: width, height: height, expansion: expansion)
    }

    static func contractedSelectionMask(_ source: [UInt8], width: Int, height: Int, contraction: Int) -> [UInt8] {
        MetalDocumentProcessingClient.shared.contractedMask(source, width: width, height: height, contraction: contraction)
            ?? cpuContractedSelectionMask(source, width: width, height: height, contraction: contraction)
    }

    static func featheredSelectionMask(_ source: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8] {
        MetalDocumentProcessingClient.shared.featheredMask(source, width: width, height: height, radius: radius)
            ?? cpuFeatheredSelectionMask(source, width: width, height: height, radius: radius)
    }

    static func invertedSelectionMask(_ source: [UInt8]) -> [UInt8] {
        MetalDocumentProcessingClient.shared.invertMask(source)
            ?? source.map { $0 == 0 ? 255 : 0 }
    }

    static func cpuExpandedSelectionMask(_ source: [UInt8], width: Int, height: Int, expansion: Int) -> [UInt8] {
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

    static func cpuContractedSelectionMask(_ source: [UInt8], width: Int, height: Int, contraction: Int) -> [UInt8] {
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

    static func cpuFeatheredSelectionMask(_ source: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8] {
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
