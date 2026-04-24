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
            guard
                let baseMask = expandedMask(from: existing, canvasWidth: canvasWidth, canvasHeight: canvasHeight),
                let incomingMask = expandedMask(from: incoming, canvasWidth: canvasWidth, canvasHeight: canvasHeight),
                let combined = MetalDocumentProcessingClient.shared.combinedSelectionMask(
                    base: baseMask,
                    incoming: incomingMask,
                    mode: mode == .add ? .add : .subtract,
                    width: canvasWidth,
                    height: canvasHeight
                )
            else {
                return nil
            }

            return croppedSelection(from: combined, width: canvasWidth, height: canvasHeight, mode: incoming.mode)
        }
    }

    static func expandedMask(from selection: CanvasSelection, canvasWidth: Int, canvasHeight: Int) -> [UInt8]? {
        let originX = max(Int(selection.bounds.minX.rounded(.down)), 0)
        let originY = max(Int(selection.bounds.minY.rounded(.down)), 0)
        let width = min(selection.maskWidth, canvasWidth - originX)
        let height = min(selection.maskHeight, canvasHeight - originY)
        guard width > 0, height > 0 else {
            return [UInt8](repeating: 0, count: canvasWidth * canvasHeight)
        }

        return MetalDocumentProcessingClient.shared.expandedSelectionMask(
            maskData: selection.maskData,
            maskWidth: selection.maskWidth,
            maskHeight: selection.maskHeight,
            originX: originX,
            originY: originY,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )
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
        guard var mask = expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight) else {
            return nil
        }

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
        guard let mask = expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight) else {
            return nil
        }
        let featheredMask = featheredSelectionMask(mask, width: canvasWidth, height: canvasHeight, radius: radius)
        return croppedSelection(from: featheredMask, width: canvasWidth, height: canvasHeight, mode: selection.mode)
    }

    static func makeLassoSelection(from points: [CGPoint], canvasSize: CGSize) -> CanvasSelection? {
        guard points.count >= 3 else { return nil }

        let polygon = closedPolygon(points, canvasSize: canvasSize)
        guard polygon.count >= 3 else { return nil }

        let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
        let canvasHeight = max(Int(canvasSize.height.rounded()), 1)
        guard let mask = MetalDocumentProcessingClient.shared.lassoSelection(
            points: polygon,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        ) else {
            return nil
        }
        return croppedSelection(from: mask, width: canvasWidth, height: canvasHeight, mode: .lasso)
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

        guard let selected = MetalDocumentProcessingClient.shared.autoSelection(
            pixelData: layer.pixelData,
            width: width,
            height: height,
            seedX: startX,
            seedY: startY,
            thresholdMode: thresholdMode,
            opacityTolerance: opacityTolerance,
            colorTolerance: colorTolerance,
            expansion: max(0, expansion)
        ) else {
            return nil
        }
        return croppedSelection(
            from: selected,
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
        guard let selected = MetalDocumentProcessingClient.shared.colorRangeSelection(
            pixelData: pixelData,
            width: width,
            height: height,
            request: request
        ) else {
            return nil
        }

        let expandedMask = request.expansion > 0
            ? expandedSelectionMask(selected, width: width, height: height, expansion: request.expansion)
            : selected
        return croppedSelection(from: expandedMask, width: width, height: height, mode: mode)
    }

    static func expandedSelectionMask(_ source: [UInt8], width: Int, height: Int, expansion: Int) -> [UInt8] {
        guard expansion > 0 else { return source }
        return MetalDocumentProcessingClient.shared.expandedMask(source, width: width, height: height, expansion: expansion)
            ?? [UInt8](repeating: 0, count: width * height)
    }

    static func contractedSelectionMask(_ source: [UInt8], width: Int, height: Int, contraction: Int) -> [UInt8] {
        guard contraction > 0 else { return source }
        return MetalDocumentProcessingClient.shared.contractedMask(source, width: width, height: height, contraction: contraction)
            ?? [UInt8](repeating: 0, count: width * height)
    }

    static func featheredSelectionMask(_ source: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8] {
        guard radius > 0 else { return source }
        return MetalDocumentProcessingClient.shared.featheredMask(source, width: width, height: height, radius: radius)
            ?? [UInt8](repeating: 0, count: width * height)
    }

    static func invertedSelectionMask(_ source: [UInt8]) -> [UInt8] {
        MetalDocumentProcessingClient.shared.invertMask(source)
            ?? [UInt8](repeating: 0, count: source.count)
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
