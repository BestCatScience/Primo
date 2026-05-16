import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain

public struct SelectionWorkflowService: Sendable {
    private let combinedSelectionMaskHandler: @Sendable ([UInt8], [UInt8], DocumentSelectionCombineMode, Int, Int) -> DocumentRenderingResult<[UInt8]>
    private let expandedSelectionMaskHandler: @Sendable (ExpandedSelectionMaskRequest) -> DocumentRenderingResult<[UInt8]>
    private let lassoSelectionHandler: @Sendable ([CGPoint], Int, Int) -> DocumentRenderingResult<[UInt8]>
    private let autoSelectionHandler: @Sendable (Data, Int, Int, Int, Int, FillThresholdMode, Double, Double, Int) -> DocumentRenderingResult<[UInt8]>
    private let colorRangeSelectionHandler: @Sendable (Data, Int, Int, ColorRangeSelectionRequest) -> DocumentRenderingResult<[UInt8]>
    private let expandedMaskHandler: @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>
    private let contractedMaskHandler: @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>
    private let featheredMaskHandler: @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>
    private let invertMaskHandler: @Sendable ([UInt8]) -> DocumentRenderingResult<[UInt8]>
    private let croppedSelectionMaskHandler: @Sendable ([UInt8], Int, Int) -> DocumentCroppedSelectionMask?

    public init(
        combinedSelectionMask: @escaping @Sendable ([UInt8], [UInt8], DocumentSelectionCombineMode, Int, Int) -> DocumentRenderingResult<[UInt8]>,
        expandedSelectionMask: @escaping @Sendable (ExpandedSelectionMaskRequest) -> DocumentRenderingResult<[UInt8]>,
        lassoSelection: @escaping @Sendable ([CGPoint], Int, Int) -> DocumentRenderingResult<[UInt8]>,
        autoSelection: @escaping @Sendable (Data, Int, Int, Int, Int, FillThresholdMode, Double, Double, Int) -> DocumentRenderingResult<[UInt8]>,
        colorRangeSelection: @escaping @Sendable (Data, Int, Int, ColorRangeSelectionRequest) -> DocumentRenderingResult<[UInt8]>,
        expandedMask: @escaping @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>,
        contractedMask: @escaping @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>,
        featheredMask: @escaping @Sendable ([UInt8], Int, Int, Int) -> DocumentRenderingResult<[UInt8]>,
        invertMask: @escaping @Sendable ([UInt8]) -> DocumentRenderingResult<[UInt8]>,
        croppedSelectionMask: @escaping @Sendable ([UInt8], Int, Int) -> DocumentCroppedSelectionMask?
    ) {
        self.combinedSelectionMaskHandler = combinedSelectionMask
        self.expandedSelectionMaskHandler = expandedSelectionMask
        self.lassoSelectionHandler = lassoSelection
        self.autoSelectionHandler = autoSelection
        self.colorRangeSelectionHandler = colorRangeSelection
        self.expandedMaskHandler = expandedMask
        self.contractedMaskHandler = contractedMask
        self.featheredMaskHandler = featheredMask
        self.invertMaskHandler = invertMask
        self.croppedSelectionMaskHandler = croppedSelectionMask
    }

    public init(operations: DocumentSelectionMaskOperations) {
        self.init(
            combinedSelectionMask: operations.combinedSelectionMask,
            expandedSelectionMask: operations.expandedSelectionMask,
            lassoSelection: operations.lassoSelection,
            autoSelection: operations.autoSelection,
            colorRangeSelection: operations.colorRangeSelection,
            expandedMask: operations.expandedMask,
            contractedMask: operations.contractedMask,
            featheredMask: operations.featheredMask,
            invertMask: operations.invertMask,
            croppedSelectionMask: operations.croppedSelectionMask
        )
    }

    public func combinedSelection(
        existing: CanvasSelection?,
        incoming: CanvasSelection?,
        mode: SelectionCombineMode,
        canvasGeometry: PixelGeometry
    ) -> CanvasSelection? {
        switch mode {
        case .replace:
            return incoming
        case .add, .subtract:
            guard let incoming else { return existing }
            guard let existing else {
                return mode == .add ? incoming : nil
            }

            let canvasWidth = canvasGeometry.width
            let canvasHeight = canvasGeometry.height
            guard
                let baseMask = expandedMask(from: existing, canvasWidth: canvasWidth, canvasHeight: canvasHeight),
                let incomingMask = expandedMask(from: incoming, canvasWidth: canvasWidth, canvasHeight: canvasHeight),
                let combined = combinedSelectionMaskHandler(
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

    public func makeRectangleSelection(
        from startPoint: CGPoint,
        to endPoint: CGPoint,
        canvasGeometry: PixelGeometry
    ) -> CanvasSelection? {
        let canvasWidth = canvasGeometry.width
        let canvasHeight = canvasGeometry.height
        let minX = min(startPoint.x, endPoint.x)
        let maxX = max(startPoint.x, endPoint.x)
        let minY = min(startPoint.y, endPoint.y)
        let maxY = max(startPoint.y, endPoint.y)
        let left = max(Int(floor(minX)), 0)
        let top = max(Int(floor(minY)), 0)
        let right = min(Int(ceil(maxX)), canvasWidth)
        let bottom = min(Int(ceil(maxY)), canvasHeight)
        guard right > left, bottom > top else { return nil }

        var mask = [UInt8](repeating: 0, count: canvasGeometry.maskByteCount)
        for y in top..<bottom {
            let rowStart = y * canvasWidth
            for x in left..<right {
                mask[rowStart + x] = 255
            }
        }
        return croppedSelection(from: mask, width: canvasWidth, height: canvasHeight, mode: .rectangle)
    }

    public func expandedMask(from selection: CanvasSelection, canvasGeometry: PixelGeometry) -> MaskSurface? {
        expandedMask(
            from: selection,
            canvasWidth: canvasGeometry.width,
            canvasHeight: canvasGeometry.height
        ).flatMap { MaskSurface(geometry: canvasGeometry, data: Data($0)) }
    }

    package func expandedMask(from selection: CanvasSelection, canvasWidth: Int, canvasHeight: Int) -> [UInt8]? {
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

        return expandedSelectionMaskHandler(
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
        canvasGeometry: PixelGeometry,
        expansion: Int,
        isInverted: Bool
    ) -> CanvasSelection? {
        guard let selection else { return nil }
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
        canvasGeometry: PixelGeometry,
        mode: SelectionToolMode
    ) -> CanvasSelection? {
        let canvasWidth = canvasGeometry.width
        let canvasHeight = canvasGeometry.height

        if let selection {
            return adjustedSelection(
                selection,
                canvasGeometry: canvasGeometry,
                expansion: 0,
                isInverted: true
            )
        }

        let fullMask = [UInt8](repeating: 255, count: canvasGeometry.maskByteCount)
        return croppedSelection(from: fullMask, width: canvasWidth, height: canvasHeight, mode: mode)
    }

    public func featheredSelection(
        _ selection: CanvasSelection?,
        canvasGeometry: PixelGeometry,
        radius: Int
    ) -> CanvasSelection? {
        guard let selection else { return nil }
        let canvasWidth = canvasGeometry.width
        let canvasHeight = canvasGeometry.height
        guard let mask = expandedMask(from: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight) else {
            return nil
        }
        let featheredMask = featheredSelectionMask(mask, width: canvasWidth, height: canvasHeight, radius: radius)
        return croppedSelection(from: featheredMask, width: canvasWidth, height: canvasHeight, mode: selection.mode)
    }

    public func makeLassoSelection(from points: [CGPoint], canvasGeometry: PixelGeometry) -> CanvasSelection? {
        guard points.count >= 3 else { return nil }

        let polygon = closedPolygon(simplifiedLassoPoints(points), canvasGeometry: canvasGeometry)
        guard polygon.count >= 3 else { return nil }

        let canvasWidth = canvasGeometry.width
        let canvasHeight = canvasGeometry.height
        guard let mask = lassoSelectionHandler(polygon, canvasWidth, canvasHeight).value else {
            return nil
        }
        return croppedSelection(from: mask, width: canvasWidth, height: canvasHeight, mode: .lasso)
    }

    public func makeAutoSelection(
        at point: CGPoint,
        snapshot: MetalDocumentSnapshot?,
        layerIndex: ExistingLayerIndex,
        thresholdMode: FillThresholdMode,
        opacityTolerance: Double,
        colorTolerance: Double,
        expansion: Int
    ) -> CanvasSelection? {
        makeAutoSelection(
            at: point,
            snapshot: snapshot,
            layerIndex: layerIndex.rawValue,
            thresholdMode: thresholdMode,
            opacityTolerance: opacityTolerance,
            colorTolerance: colorTolerance,
            expansion: expansion
        )
    }

    package func makeAutoSelection(
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

        guard let selected = autoSelectionHandler(
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
        activeLayerIndex: ExistingLayerIndex,
        mode: SelectionToolMode
    ) -> CanvasSelection? {
        guard let snapshot else { return nil }
        let width = snapshot.width
        let height = snapshot.height
        guard let geometry = PixelGeometry(width: width, height: height) else { return nil }

        let pixelData: Data
        switch request.source {
        case .activeLayer:
            guard let layer = snapshot.layers.first(where: { $0.index == activeLayerIndex.rawValue }) else { return nil }
            pixelData = layer.pixelData
        case .canvas:
            pixelData = snapshot.compositePixelData
        }

        guard pixelData.count == geometry.rgbaByteCount else { return nil }
        guard let selected = colorRangeSelectionHandler(pixelData, width, height, request).value else {
            return nil
        }

        let expandedMask = request.expansion > 0
            ? expandedSelectionMask(selected, width: width, height: height, expansion: request.expansion)
            : selected
        return croppedSelection(from: expandedMask, width: width, height: height, mode: mode)
    }

    public func expandedSelectionMask(_ source: MaskSurface, expansion: Int) -> MaskSurface {
        let data = expandedSelectionMask(
            [UInt8](source.data),
            width: source.width,
            height: source.height,
            expansion: expansion
        )
        return MaskSurface(geometry: source.geometry, data: Data(data)) ?? source
    }

    package func expandedSelectionMask(_ source: [UInt8], width: Int, height: Int, expansion: Int) -> [UInt8] {
        guard expansion > 0 else { return source }
        guard let geometry = PixelGeometry(width: width, height: height), source.count == geometry.maskByteCount else { return source }
        return expandedMaskHandler(source, width, height, expansion).value
            ?? [UInt8](repeating: 0, count: geometry.maskByteCount)
    }

    public func contractedSelectionMask(_ source: MaskSurface, contraction: Int) -> MaskSurface {
        let data = contractedSelectionMask(
            [UInt8](source.data),
            width: source.width,
            height: source.height,
            contraction: contraction
        )
        return MaskSurface(geometry: source.geometry, data: Data(data)) ?? source
    }

    package func contractedSelectionMask(_ source: [UInt8], width: Int, height: Int, contraction: Int) -> [UInt8] {
        guard contraction > 0 else { return source }
        guard let geometry = PixelGeometry(width: width, height: height), source.count == geometry.maskByteCount else { return source }
        return contractedMaskHandler(source, width, height, contraction).value
            ?? [UInt8](repeating: 0, count: geometry.maskByteCount)
    }

    public func featheredSelectionMask(_ source: MaskSurface, radius: Int) -> MaskSurface {
        let data = featheredSelectionMask(
            [UInt8](source.data),
            width: source.width,
            height: source.height,
            radius: radius
        )
        return MaskSurface(geometry: source.geometry, data: Data(data)) ?? source
    }

    package func featheredSelectionMask(_ source: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8] {
        guard radius > 0 else { return source }
        guard let geometry = PixelGeometry(width: width, height: height), source.count == geometry.maskByteCount else { return source }
        return featheredMaskHandler(source, width, height, radius).value
            ?? [UInt8](repeating: 0, count: geometry.maskByteCount)
    }

    public func invertedSelectionMask(_ source: MaskSurface) -> MaskSurface {
        let data = invertedSelectionMask([UInt8](source.data))
        return MaskSurface(geometry: source.geometry, data: Data(data)) ?? source
    }

    package func invertedSelectionMask(_ source: [UInt8]) -> [UInt8] {
        invertMaskHandler(source).value
            ?? [UInt8](repeating: 0, count: source.count)
    }

    public func croppedSelection(from source: MaskSurface, mode: SelectionToolMode) -> CanvasSelection? {
        croppedSelection(
            from: [UInt8](source.data),
            width: source.width,
            height: source.height,
            mode: mode
        )
    }

    package func croppedSelection(from source: [UInt8], width: Int, height: Int, mode: SelectionToolMode) -> CanvasSelection? {
        guard let geometry = PixelGeometry(width: width, height: height), source.count == geometry.maskByteCount else {
            return nil
        }
        guard let cropped = croppedSelectionMaskHandler(source, width, height) else {
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

    public func closedPolygon(_ points: [CGPoint], canvasGeometry: PixelGeometry) -> [CGPoint] {
        let maxX = CGFloat(max(canvasGeometry.width - 1, 0))
        let maxY = CGFloat(max(canvasGeometry.height - 1, 0))
        let clamped = points.map {
            CGPoint(
                x: min(max($0.x, 0), maxX),
                y: min(max($0.y, 0), maxY)
            )
        }
        guard let first = clamped.first, let last = clamped.last else { return [] }
        if hypot(first.x - last.x, first.y - last.y) <= 4 {
            return clamped
        }
        return clamped + [first]
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
