import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain

extension AppFeature {
    static func combinedSelection(
        existing: CanvasSelection?,
        incoming: CanvasSelection?,
        mode: SelectionCombineMode,
        canvasSize: CGSize,
        gpuOperations: DocumentGpuOperationGateway
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
                let baseMask = expandedMask(from: existing, canvasWidth: canvasWidth, canvasHeight: canvasHeight, gpuOperations: gpuOperations),
                let incomingMask = expandedMask(from: incoming, canvasWidth: canvasWidth, canvasHeight: canvasHeight, gpuOperations: gpuOperations),
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

            return croppedSelection(from: combined, width: canvasWidth, height: canvasHeight, mode: incoming.mode, gpuOperations: gpuOperations)
        }
    }

    static func expandedMask(from selection: CanvasSelection, canvasWidth: Int, canvasHeight: Int, gpuOperations: DocumentGpuOperationGateway) -> [UInt8]? {
        let originX = max(Int(selection.bounds.minX.rounded(.down)), 0)
        let originY = max(Int(selection.bounds.minY.rounded(.down)), 0)
        let width = min(selection.maskWidth, canvasWidth - originX)
        let height = min(selection.maskHeight, canvasHeight - originY)
        guard width > 0, height > 0 else {
            return [UInt8](repeating: 0, count: canvasWidth * canvasHeight)
        }

        return gpuOperations.expandedSelectionMask(
            selection.maskData,
            selection.maskWidth,
            selection.maskHeight,
            originX,
            originY,
            canvasWidth,
            canvasHeight
        )
    }

    static func adjustedSelection(
        _ selection: CanvasSelection?,
        canvasSize: CGSize,
        expansion: Int,
        isInverted: Bool,
        gpuOperations: DocumentGpuOperationGateway
    ) -> CanvasSelection? {
        guard let selection else { return nil }
        let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
        let canvasHeight = max(Int(canvasSize.height.rounded()), 1)
        guard var mask = expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight, gpuOperations: gpuOperations) else {
            return nil
        }

        if expansion > 0 {
            mask = expandedSelectionMask(mask, width: canvasWidth, height: canvasHeight, expansion: expansion, gpuOperations: gpuOperations)
        } else if expansion < 0 {
            mask = contractedSelectionMask(mask, width: canvasWidth, height: canvasHeight, contraction: abs(expansion), gpuOperations: gpuOperations)
        }

        if isInverted {
            mask = invertedSelectionMask(mask, gpuOperations: gpuOperations)
        }

        return croppedSelection(from: mask, width: canvasWidth, height: canvasHeight, mode: selection.mode, gpuOperations: gpuOperations)
    }

    static func invertedSelection(
        _ selection: CanvasSelection?,
        canvasSize: CGSize,
        mode: SelectionToolMode,
        gpuOperations: DocumentGpuOperationGateway
    ) -> CanvasSelection? {
        let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
        let canvasHeight = max(Int(canvasSize.height.rounded()), 1)

        if let selection {
            return adjustedSelection(
                selection,
                canvasSize: canvasSize,
                expansion: 0,
                isInverted: true,
                gpuOperations: gpuOperations
            )
        }

        let fullMask = [UInt8](repeating: 255, count: canvasWidth * canvasHeight)
        return croppedSelection(from: fullMask, width: canvasWidth, height: canvasHeight, mode: mode, gpuOperations: gpuOperations)
    }

    static func featheredSelection(
        _ selection: CanvasSelection?,
        canvasSize: CGSize,
        radius: Int,
        gpuOperations: DocumentGpuOperationGateway
    ) -> CanvasSelection? {
        guard let selection else { return nil }
        let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
        let canvasHeight = max(Int(canvasSize.height.rounded()), 1)
        guard let mask = expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight, gpuOperations: gpuOperations) else {
            return nil
        }
        let featheredMask = featheredSelectionMask(mask, width: canvasWidth, height: canvasHeight, radius: radius, gpuOperations: gpuOperations)
        return croppedSelection(from: featheredMask, width: canvasWidth, height: canvasHeight, mode: selection.mode, gpuOperations: gpuOperations)
    }

    static func makeLassoSelection(from points: [CGPoint], canvasSize: CGSize, gpuOperations: DocumentGpuOperationGateway) -> CanvasSelection? {
        guard points.count >= 3 else { return nil }

        let polygon = closedPolygon(points, canvasSize: canvasSize)
        guard polygon.count >= 3 else { return nil }

        let canvasWidth = max(Int(canvasSize.width.rounded()), 1)
        let canvasHeight = max(Int(canvasSize.height.rounded()), 1)
        guard let mask = gpuOperations.lassoSelection(
            polygon,
            canvasWidth,
            canvasHeight
        ) else {
            return nil
        }
        return croppedSelection(from: mask, width: canvasWidth, height: canvasHeight, mode: .lasso, gpuOperations: gpuOperations)
    }

    static func makeAutoSelection(
        at point: CGPoint,
        snapshot: MetalDocumentSnapshot?,
        layerIndex: Int,
        thresholdMode: FillThresholdMode,
        opacityTolerance: Double,
        colorTolerance: Double,
        expansion: Int,
        gpuOperations: DocumentGpuOperationGateway
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
        return croppedSelection(
            from: selected,
            width: width,
            height: height,
            mode: .auto,
            gpuOperations: gpuOperations
        )
    }

    static func makeColorRangeSelection(
        request: ColorRangeSelectionRequest,
        snapshot: MetalDocumentSnapshot?,
        activeLayerIndex: Int,
        mode: SelectionToolMode,
        gpuOperations: DocumentGpuOperationGateway
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
        guard let selected = gpuOperations.colorRangeSelection(
            pixelData,
            width,
            height,
            request
        ) else {
            return nil
        }

        let expandedMask = request.expansion > 0
            ? expandedSelectionMask(selected, width: width, height: height, expansion: request.expansion, gpuOperations: gpuOperations)
            : selected
        return croppedSelection(from: expandedMask, width: width, height: height, mode: mode, gpuOperations: gpuOperations)
    }

    static func expandedSelectionMask(_ source: [UInt8], width: Int, height: Int, expansion: Int, gpuOperations: DocumentGpuOperationGateway) -> [UInt8] {
        guard expansion > 0 else { return source }
        return gpuOperations.expandedMask(source, width, height, expansion)
            ?? [UInt8](repeating: 0, count: width * height)
    }

    static func contractedSelectionMask(_ source: [UInt8], width: Int, height: Int, contraction: Int, gpuOperations: DocumentGpuOperationGateway) -> [UInt8] {
        guard contraction > 0 else { return source }
        return gpuOperations.contractedMask(source, width, height, contraction)
            ?? [UInt8](repeating: 0, count: width * height)
    }

    static func featheredSelectionMask(_ source: [UInt8], width: Int, height: Int, radius: Int, gpuOperations: DocumentGpuOperationGateway) -> [UInt8] {
        guard radius > 0 else { return source }
        return gpuOperations.featheredMask(source, width, height, radius)
            ?? [UInt8](repeating: 0, count: width * height)
    }

    static func invertedSelectionMask(_ source: [UInt8], gpuOperations: DocumentGpuOperationGateway) -> [UInt8] {
        gpuOperations.invertMask(source)
            ?? [UInt8](repeating: 0, count: source.count)
    }

    static func croppedSelection(from source: [UInt8], width: Int, height: Int, mode: SelectionToolMode, gpuOperations: DocumentGpuOperationGateway) -> CanvasSelection? {
        guard let cropped = gpuOperations.croppedSelectionMask(
            source,
            width,
            height
        ) else {
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
