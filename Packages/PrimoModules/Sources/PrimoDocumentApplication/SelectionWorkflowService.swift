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

            let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
            let canvasHeight = max(Int(canvasSize.height.rounded()), 1)
            guard
                let baseMask = expandedMask(from: existing, canvasWidth: canvasWidth, canvasHeight: canvasHeight),
                let incomingMask = expandedMask(from: incoming, canvasWidth: canvasWidth, canvasHeight: canvasHeight),
                let combined = gpuOperations.combinedSelectionMask(
                    baseMask,
                    incomingMask,
                    mode == .add ? .add : .subtract,
                    canvasWidth,
                    canvasHeight
                )
            else {
                return nil
            }

            return croppedSelection(from: combined, width: canvasWidth, height: canvasHeight, mode: incoming.mode)
        }
    }

    public func expandedMask(from selection: CanvasSelection, canvasWidth: Int, canvasHeight: Int) -> [UInt8]? {
        let originX = max(Int(selection.bounds.minX.rounded(.down)), 0)
        let originY = max(Int(selection.bounds.minY.rounded(.down)), 0)
        let width = min(selection.maskWidth, canvasWidth - originX)
        let height = min(selection.maskHeight, canvasHeight - originY)
        guard width > 0, height > 0 else {
            return [UInt8](repeating: 0, count: canvasWidth * canvasHeight)
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
        )
    }

    public func adjustedSelection(
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

    public func invertedSelection(
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

    public func featheredSelection(
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

    public func makeLassoSelection(from points: [CGPoint], canvasSize: CGSize) -> CanvasSelection? {
        guard points.count >= 3 else { return nil }

        let polygon = closedPolygon(points, canvasSize: canvasSize)
        guard polygon.count >= 3 else { return nil }

        let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
        let canvasHeight = max(Int(canvasSize.height.rounded()), 1)
        guard let mask = gpuOperations.lassoSelection(polygon, canvasWidth, canvasHeight) else {
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
        guard width > 0, height > 0 else { return nil }

        let startX = min(max(Int(point.x.rounded()), 0), width - 1)
        let startY = min(max(Int(point.y.rounded()), 0), height - 1)
        guard layer.pixelData.count == width * height * 4 else { return nil }

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
        ) else {
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
        guard let selected = gpuOperations.colorRangeSelection(pixelData, width, height, request) else {
            return nil
        }

        let expandedMask = request.expansion > 0
            ? expandedSelectionMask(selected, width: width, height: height, expansion: request.expansion)
            : selected
        return croppedSelection(from: expandedMask, width: width, height: height, mode: mode)
    }

    public func expandedSelectionMask(_ source: [UInt8], width: Int, height: Int, expansion: Int) -> [UInt8] {
        guard expansion > 0 else { return source }
        return gpuOperations.expandedMask(source, width, height, expansion)
            ?? [UInt8](repeating: 0, count: width * height)
    }

    public func contractedSelectionMask(_ source: [UInt8], width: Int, height: Int, contraction: Int) -> [UInt8] {
        guard contraction > 0 else { return source }
        return gpuOperations.contractedMask(source, width, height, contraction)
            ?? [UInt8](repeating: 0, count: width * height)
    }

    public func featheredSelectionMask(_ source: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8] {
        guard radius > 0 else { return source }
        return gpuOperations.featheredMask(source, width, height, radius)
            ?? [UInt8](repeating: 0, count: width * height)
    }

    public func invertedSelectionMask(_ source: [UInt8]) -> [UInt8] {
        gpuOperations.invertMask(source)
            ?? [UInt8](repeating: 0, count: source.count)
    }

    public func croppedSelection(from source: [UInt8], width: Int, height: Int, mode: SelectionToolMode) -> CanvasSelection? {
        guard let cropped = gpuOperations.croppedSelectionMask(source, width, height) else {
            return nil
        }

        return CanvasSelection(
            bounds: cropped.bounds,
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
}
