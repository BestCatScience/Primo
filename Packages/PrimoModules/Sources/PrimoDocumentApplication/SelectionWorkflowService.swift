import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain

public struct SelectionWorkflowService: Sendable {
    public let gpuOperations: DocumentGpuOperationGateway

    public init(gpuOperations: DocumentGpuOperationGateway) {
        self.gpuOperations = gpuOperations
    }

    public func combinedSelection(
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

            guard let canvasGeometry = canvasGeometry(from: canvasSize) else { return nil }
            let canvasWidth = canvasGeometry.width
            let canvasHeight = canvasGeometry.height
            guard
                let baseMask = expandedMask(from: existing, canvasWidth: canvasWidth, canvasHeight: canvasHeight),
                let incomingMask = expandedMask(from: incoming, canvasWidth: canvasWidth, canvasHeight: canvasHeight),
                let combined = gpuOperations.combinedSelectionMask(
                    baseMask,
                    incomingMask,
                    mode == .add ? .add : .subtract,
                    canvasWidth,
                    canvasHeight
                ).value
            else {
                return nil
            }

            return croppedSelection(from: combined, width: canvasWidth, height: canvasHeight, mode: incoming.mode)
        }
    }

    public func expandedMask(from selection: CanvasSelection, canvasWidth: Int, canvasHeight: Int) -> [UInt8]? {
        guard let canvasGeometry = PixelGeometry(width: canvasWidth, height: canvasHeight) else { return nil }
        guard let selectionGeometry = PixelGeometry(width: selection.maskWidth, height: selection.maskHeight) else { return nil }
        guard selection.maskData.count == selectionGeometry.maskByteCount else { return nil }
        let originX = max(Int(selection.bounds.minX.rounded(.down)), 0)
        let originY = max(Int(selection.bounds.minY.rounded(.down)), 0)
        let width = min(selection.maskWidth, canvasWidth - originX)
        let height = min(selection.maskHeight, canvasHeight - originY)
        guard width > 0, height > 0 else {
            return [UInt8](repeating: 0, count: canvasGeometry.maskByteCount)
        }

        return gpuOperations.expandedSelectionMask(
            ExpandedSelectionMaskRequest(
                maskData: selection.maskData,
                maskWidth: selection.maskWidth,
                maskHeight: selection.maskHeight,
                originX: originX,
                originY: originY,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight
            )
        ).value
    }

    public func adjustedSelection(
        _ selection: CanvasSelection?,
        canvasSize: CGSize,
        expansion: Int,
        isInverted: Bool
    ) -> CanvasSelection? {
        guard let selection else { return nil }
        guard let canvasGeometry = canvasGeometry(from: canvasSize) else { return nil }
        let canvasWidth = canvasGeometry.width
        let canvasHeight = canvasGeometry.height
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

    public func invertedSelection(
        _ selection: CanvasSelection?,
        canvasSize: CGSize,
        mode: SelectionToolMode
    ) -> CanvasSelection? {
        guard let canvasGeometry = canvasGeometry(from: canvasSize) else { return nil }
        let canvasWidth = canvasGeometry.width
        let canvasHeight = canvasGeometry.height

        if let selection {
            return adjustedSelection(
                selection,
                canvasSize: canvasSize,
                expansion: 0,
                isInverted: true
            )
        }

        let fullMask = [UInt8](repeating: 255, count: canvasGeometry.maskByteCount)
        return croppedSelection(from: fullMask, width: canvasWidth, height: canvasHeight, mode: mode)
    }

    public func featheredSelection(
        _ selection: CanvasSelection?,
        canvasSize: CGSize,
        radius: Int
    ) -> CanvasSelection? {
        guard let selection else { return nil }
        guard let canvasGeometry = canvasGeometry(from: canvasSize) else { return nil }
        let canvasWidth = canvasGeometry.width
        let canvasHeight = canvasGeometry.height
        guard let mask = expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight) else {
            return nil
        }
        let featheredMask = featheredSelectionMask(mask, width: canvasWidth, height: canvasHeight, radius: radius)
        return croppedSelection(from: featheredMask, width: canvasWidth, height: canvasHeight, mode: selection.mode)
    }

    public func makeLassoSelection(from points: [CGPoint], canvasSize: CGSize) -> CanvasSelection? {
        guard points.count >= 3 else { return nil }

        let polygon = closedPolygon(simplifiedLassoPoints(points), canvasSize: canvasSize)
        guard polygon.count >= 3 else { return nil }

        guard let canvasGeometry = canvasGeometry(from: canvasSize) else { return nil }
        let canvasWidth = canvasGeometry.width
        let canvasHeight = canvasGeometry.height
        guard let mask = gpuOperations.lassoSelection(polygon, canvasWidth, canvasHeight).value else {
            return nil
        }
        return croppedSelection(from: mask, width: canvasWidth, height: canvasHeight, mode: .lasso)
    }

    public func makeAutoSelection(
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
        guard let geometry = PixelGeometry(width: width, height: height) else { return nil }

        let startX = min(max(Int(point.x.rounded()), 0), width - 1)
        let startY = min(max(Int(point.y.rounded()), 0), height - 1)
        guard layer.pixelData.count == geometry.rgbaByteCount else { return nil }

        guard let selected = gpuOperations.autoSelection(
            layer.pixelData,
            width,
            height,
            startX,
            startY,
            thresholdMode,
            opacityTolerance,
            colorTolerance,
            max(0, expansion)
        ).value else {
            return nil
        }
        return croppedSelection(from: selected, width: width, height: height, mode: .auto)
    }

    public func makeColorRangeSelection(
        request: ColorRangeSelectionRequest,
        snapshot: MetalDocumentSnapshot?,
        activeLayerIndex: Int,
        mode: SelectionToolMode
    ) -> CanvasSelection? {
        guard let snapshot else { return nil }
        let width = snapshot.width
        let height = snapshot.height
        guard let geometry = PixelGeometry(width: width, height: height) else { return nil }

        let pixelData: Data
        switch request.source {
        case .activeLayer:
            guard let layer = snapshot.layers.first(where: { $0.index == activeLayerIndex }) else { return nil }
            pixelData = layer.pixelData
        case .canvas:
            pixelData = snapshot.compositePixelData
        }

        guard pixelData.count == geometry.rgbaByteCount else { return nil }
        guard let selected = gpuOperations.colorRangeSelection(pixelData, width, height, request).value else {
            return nil
        }

        let expandedMask = request.expansion > 0
            ? expandedSelectionMask(selected, width: width, height: height, expansion: request.expansion)
            : selected
        return croppedSelection(from: expandedMask, width: width, height: height, mode: mode)
    }

    public func expandedSelectionMask(_ source: [UInt8], width: Int, height: Int, expansion: Int) -> [UInt8] {
        guard expansion > 0 else { return source }
        guard let geometry = PixelGeometry(width: width, height: height), source.count == geometry.maskByteCount else { return source }
        return gpuOperations.expandedMask(source, width, height, expansion).value
            ?? [UInt8](repeating: 0, count: geometry.maskByteCount)
    }

    public func contractedSelectionMask(_ source: [UInt8], width: Int, height: Int, contraction: Int) -> [UInt8] {
        guard contraction > 0 else { return source }
        guard let geometry = PixelGeometry(width: width, height: height), source.count == geometry.maskByteCount else { return source }
        return gpuOperations.contractedMask(source, width, height, contraction).value
            ?? [UInt8](repeating: 0, count: geometry.maskByteCount)
    }

    public func featheredSelectionMask(_ source: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8] {
        guard radius > 0 else { return source }
        guard let geometry = PixelGeometry(width: width, height: height), source.count == geometry.maskByteCount else { return source }
        return gpuOperations.featheredMask(source, width, height, radius).value
            ?? [UInt8](repeating: 0, count: geometry.maskByteCount)
    }

    public func invertedSelectionMask(_ source: [UInt8]) -> [UInt8] {
        gpuOperations.invertMask(source).value
            ?? [UInt8](repeating: 0, count: source.count)
    }

    public func croppedSelection(from source: [UInt8], width: Int, height: Int, mode: SelectionToolMode) -> CanvasSelection? {
        guard let geometry = PixelGeometry(width: width, height: height), source.count == geometry.maskByteCount else {
            return nil
        }
        guard let cropped = gpuOperations.croppedSelectionMask(source, width, height) else {
            return nil
        }

        return CanvasSelection(
            validatingBounds: cropped.bounds,
            maskWidth: cropped.maskWidth,
            maskHeight: cropped.maskHeight,
            maskData: cropped.maskData,
            mode: mode
        )
    }

    public func closedPolygon(_ points: [CGPoint], canvasSize: CGSize) -> [CGPoint] {
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

    private func canvasGeometry(from canvasSize: CGSize) -> PixelGeometry? {
        let width = Int(canvasSize.width.rounded())
        let height = Int(canvasSize.height.rounded())
        return PixelGeometry(width: width, height: height)
    }

    private func simplifiedLassoPoints(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > CanvasSizePolicy.maxLassoPointCount else { return points }
        let stride = max(1, Int(ceil(Double(points.count) / Double(CanvasSizePolicy.maxLassoPointCount))))
        var simplified: [CGPoint] = []
        simplified.reserveCapacity(CanvasSizePolicy.maxLassoPointCount)
        for (index, point) in points.enumerated() where index % stride == 0 {
            if let last = simplified.last, hypot(last.x - point.x, last.y - point.y) < 2 {
                continue
            }
            simplified.append(point)
            if simplified.count == CanvasSizePolicy.maxLassoPointCount {
                break
            }
        }
        return simplified
    }
}
