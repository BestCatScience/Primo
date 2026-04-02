import AVFoundation
import ComposableArchitecture
import QuartzCore
import SwiftUI
import UIKit
import simd

struct CanvasView: UIViewRepresentable {
    let store: StoreOf<CanvasFeature>

    func makeUIView(context: Context) -> RasterCanvasContainerView {
        let view = RasterCanvasContainerView()
        view.sendAction = { store.send($0) }
        return view
    }

    func updateUIView(_ uiView: RasterCanvasContainerView, context: Context) {
        uiView.documentSize = store.canvasSize
        uiView.update(
            snapshot: store.renderSnapshot,
            activeLayerIndex: store.activeLayerIndex,
            incrementalUpdate: store.pendingIncrementalUpdate,
            paperStyle: store.paperStyle,
            previewStyle: store.previewStyle,
            currentTool: store.currentTool,
            selectionMode: store.selectionMode,
            selection: store.selection,
            selectionPreviewPoints: store.selectionPreviewPoints,
            transformPreviewOffset: store.transformPreviewOffset,
            viewportOffset: store.viewportOffset,
            zoomScale: store.zoomScale,
        )
    }
}

final class RasterCanvasContainerView: UIView, InputHandlerDelegate, UIGestureRecognizerDelegate {
    var documentSize: CGSize = .zero
    var sendAction: ((CanvasFeature.Action) -> Void)?

    private let metalCanvasView = MetalCanvasView()
    private let selectionOverlayView = UIImageView()
    private let compositePreviewImageView = UIImageView()
    private let inputHandler = InputHandler()
    private let selectionOutlineLayer = CAShapeLayer()
    private let selectionPreviewLayer = CAShapeLayer()

    private var viewportOffset: CGSize = .zero
    private var zoomScale: CGFloat = 1.0
    private var currentTool: StudioToolKind = .brush
    private var transformPreviewOffset: CGSize = .zero
    private var panStartLocation: CGPoint?
    private var panStartOffset: CGSize = .zero
    private var panDidMove = false
    private var isCanvasPanGestureActive = false
    private var pinchStartScale: CGFloat = 1.0
    private var pinchAnchorDocumentPoint: CGPoint?
    private var isPinchGestureActive = false
    private var lastNavigationGestureEndedAt: CFTimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        clipsToBounds = true

        inputHandler.delegate = self
        inputHandler.pointMapper = { [weak self] location, view in
            guard let self else { return SIMD2(Float(location.x), Float(location.y)) }
            let point = self.canvasPoint(from: location, in: view)
            return SIMD2(Float(point.x), Float(point.y))
        }

        metalCanvasView.isUserInteractionEnabled = false
        addSubview(metalCanvasView)

        selectionOverlayView.isUserInteractionEnabled = false
        selectionOverlayView.contentMode = .scaleToFill
        selectionOverlayView.alpha = 0.55
        addSubview(selectionOverlayView)

        compositePreviewImageView.isUserInteractionEnabled = false
        compositePreviewImageView.contentMode = .scaleToFill
        compositePreviewImageView.alpha = 1.0
        addSubview(compositePreviewImageView)

        selectionOutlineLayer.strokeColor = UIColor.white.withAlphaComponent(0.92).cgColor
        selectionOutlineLayer.fillColor = UIColor.clear.cgColor
        selectionOutlineLayer.lineWidth = 1.5
        selectionOutlineLayer.lineDashPattern = [6, 4]
        layer.addSublayer(selectionOutlineLayer)

        selectionPreviewLayer.strokeColor = UIColor.white.withAlphaComponent(0.8).cgColor
        selectionPreviewLayer.fillColor = UIColor.clear.cgColor
        selectionPreviewLayer.lineWidth = 1.25
        selectionPreviewLayer.lineDashPattern = [4, 4]
        layer.addSublayer(selectionPreviewLayer)

        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchRecognizer.delegate = self
        pinchRecognizer.cancelsTouchesInView = false
        addGestureRecognizer(pinchRecognizer)

        let undoTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerUndoTap(_:)))
        undoTapRecognizer.numberOfTouchesRequired = 2
        undoTapRecognizer.numberOfTapsRequired = 1
        undoTapRecognizer.cancelsTouchesInView = false
        undoTapRecognizer.delegate = self
        undoTapRecognizer.require(toFail: pinchRecognizer)
        addGestureRecognizer(undoTapRecognizer)

        let redoTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleThreeFingerRedoTap(_:)))
        redoTapRecognizer.numberOfTouchesRequired = 3
        redoTapRecognizer.numberOfTapsRequired = 1
        redoTapRecognizer.cancelsTouchesInView = false
        redoTapRecognizer.delegate = self
        redoTapRecognizer.require(toFail: pinchRecognizer)
        addGestureRecognizer(redoTapRecognizer)

        addInteraction(UIPencilInteraction())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        metalCanvasView.frame = bounds
        selectionOutlineLayer.frame = bounds
        selectionPreviewLayer.frame = bounds
    }

    func update(
        snapshot: MetalDocumentSnapshot?,
        activeLayerIndex: Int,
        incrementalUpdate: IncrementalLayerUpdate?,
        paperStyle: CanvasPaperStyle,
        previewStyle: PreviewStrokeStyle,
        currentTool: StudioToolKind,
        selectionMode: SelectionToolMode,
        selection: CanvasSelection?,
        selectionPreviewPoints: [CGPoint],
        transformPreviewOffset: CGSize,
        viewportOffset: CGSize,
        zoomScale: CGFloat
    ) {
        self.currentTool = currentTool
        self.transformPreviewOffset = transformPreviewOffset
        self.viewportOffset = viewportOffset
        self.zoomScale = zoomScale
        metalCanvasView.updateDocumentSize(documentSize)
        metalCanvasView.update(snapshot: snapshot, viewportOffset: viewportOffset, zoomScale: zoomScale, paperStyle: paperStyle)
        if let incrementalUpdate {
            metalCanvasView.applyIncrementalUpdate(incrementalUpdate)
        }
        inputHandler.tool = currentTool
        inputHandler.selectionMode = selectionMode
        inputHandler.brushSize = Float(previewStyle.radius * 2.0)
        inputHandler.brushColor = previewStyle.simdColor
        updateSelectionOverlay(selection)
        updateSelectionPreview(selectionPreviewPoints)
        updateTransformPreview(snapshot: snapshot, activeLayerIndex: activeLayerIndex, selection: selection)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handlePanTouchesIfNeeded(touches, phase: .began) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handlePanTouchesIfNeeded(touches, phase: .moved) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handlePanTouchesIfNeeded(touches, phase: .ended) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if handlePanTouchesIfNeeded(touches, phase: .cancelled) { return }
        inputHandler.handleTouches(touches, with: event, in: self)
    }

    func didUpdateStroke(_ stroke: Stroke) {
        sendAction?(.strokeUpdated(stroke))
    }

    func didEndStroke(_ stroke: Stroke) {
        sendAction?(.strokeEnded(stroke))
    }

    func didRequestFill(at sample: StylusSample) {
        sendAction?(.fillRequested(sample))
    }

    func didUpdateSelectionPath(_ points: [CGPoint]) {
        sendAction?(.selectionPreviewUpdated(points))
    }

    func didEndSelectionPath(_ points: [CGPoint]) {
        sendAction?(.selectionPathEnded(points))
    }

    func didRequestAutoSelection(at sample: StylusSample) {
        sendAction?(.autoSelectionRequested(sample))
    }

    func didBeginTransform() {
        sendAction?(.transformGestureBegan)
    }

    func didUpdateTransform(translation: CGSize) {
        sendAction?(.transformPreviewChanged(translation))
    }

    func didEndTransform(translation: CGSize) {
        sendAction?(.transformEnded(translation))
    }

    private func canvasPoint(from location: CGPoint, in view: UIView) -> CGPoint {
        let fitted = contentRect()
        guard fitted.width > 0, fitted.height > 0, documentSize.width > 0, documentSize.height > 0 else { return .zero }

        let local = convert(location, from: view)
        let x = ((local.x - fitted.minX) / fitted.width) * documentSize.width
        let y = ((local.y - fitted.minY) / fitted.height) * documentSize.height
        return CGPoint(x: x, y: y)
    }

    private func contentRect() -> CGRect {
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        guard documentSize.width > 0, documentSize.height > 0 else { return .zero }
        let fittedRect = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledSize = CGSize(width: fittedRect.width * zoomScale, height: fittedRect.height * zoomScale)
        return CGRect(
            x: fittedRect.midX - (scaledSize.width / 2) + viewportOffset.width,
            y: fittedRect.midY - (scaledSize.height / 2) + viewportOffset.height,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }

    private func updateSelectionOverlay(_ selection: CanvasSelection?) {
        guard
            currentTool == .select || currentTool == .move,
            let selection,
            !selection.isEmpty,
            let image = makeSelectionOverlayImage(selection)
        else {
            selectionOverlayView.image = nil
            selectionOverlayView.frame = .zero
            selectionOutlineLayer.path = nil
            return
        }

        var rect = viewRect(forDocumentRect: selection.bounds)
        if currentTool == .move {
            let translatedOrigin = viewPoint(
                fromDocumentPoint: CGPoint(
                    x: selection.bounds.minX + transformPreviewOffset.width,
                    y: selection.bounds.minY + transformPreviewOffset.height
                )
            )
            rect.origin = translatedOrigin
        }
        selectionOverlayView.image = image
        selectionOverlayView.frame = rect
        selectionOutlineLayer.path = UIBezierPath(rect: rect).cgPath
    }

    private func updateTransformPreview(snapshot: MetalDocumentSnapshot?, activeLayerIndex: Int, selection: CanvasSelection?) {
        guard
            currentTool == .move,
            transformPreviewOffset != .zero,
            let snapshot,
            let image = makeCompositePreviewImage(snapshot: snapshot, activeLayerIndex: activeLayerIndex, selection: selection)
        else {
            compositePreviewImageView.image = nil
            compositePreviewImageView.frame = .zero
            metalCanvasView.isHidden = false
            return
        }

        compositePreviewImageView.image = image
        compositePreviewImageView.frame = contentRect()
        metalCanvasView.isHidden = true
    }

    private func updateSelectionPreview(_ points: [CGPoint]) {
        guard currentTool == .select, points.count >= 2 else {
            selectionPreviewLayer.path = nil
            return
        }

        let path = UIBezierPath()
        for (index, point) in points.enumerated() {
            let mapped = viewPoint(fromDocumentPoint: point)
            if index == 0 {
                path.move(to: mapped)
            } else {
                path.addLine(to: mapped)
            }
        }
        selectionPreviewLayer.path = path.cgPath
    }

    private func viewRect(forDocumentRect rect: CGRect) -> CGRect {
        let fitted = contentRect()
        guard fitted.width > 0, fitted.height > 0, documentSize.width > 0, documentSize.height > 0 else { return .zero }
        let minPoint = viewPoint(fromDocumentPoint: rect.origin)
        let maxPoint = viewPoint(fromDocumentPoint: CGPoint(x: rect.maxX, y: rect.maxY))
        return CGRect(
            x: minPoint.x,
            y: minPoint.y,
            width: max(1, maxPoint.x - minPoint.x),
            height: max(1, maxPoint.y - minPoint.y)
        )
    }

    private func viewPoint(fromDocumentPoint point: CGPoint) -> CGPoint {
        let fitted = contentRect()
        guard fitted.width > 0, fitted.height > 0, documentSize.width > 0, documentSize.height > 0 else { return .zero }
        return CGPoint(
            x: fitted.minX + ((point.x / documentSize.width) * fitted.width),
            y: fitted.minY + ((point.y / documentSize.height) * fitted.height)
        )
    }

    private func makeSelectionOverlayImage(_ selection: CanvasSelection) -> UIImage? {
        let width = selection.maskWidth
        let height = selection.maskHeight
        guard width > 0, height > 0 else { return nil }
        let expectedCount = width * height
        guard selection.maskData.count == expectedCount else { return nil }

        var rgba = Data(count: expectedCount * 4)
        rgba.withUnsafeMutableBytes { destinationBytes in
            selection.maskData.withUnsafeBytes { sourceBytes in
                guard
                    let destinationBase = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    let sourceBase = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else { return }

                for index in 0..<expectedCount {
                    let alpha = sourceBase[index]
                    let destinationIndex = index * 4
                    destinationBase[destinationIndex] = 91
                    destinationBase[destinationIndex + 1] = 181
                    destinationBase[destinationIndex + 2] = 255
                    destinationBase[destinationIndex + 3] = UInt8((Float(alpha) / 255.0) * 96.0)
                }
            }
        }

        guard let provider = CGDataProvider(data: rgba as CFData) else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            return nil
        }
        return UIImage(cgImage: image)
    }

    private func makeCompositePreviewImage(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        selection: CanvasSelection?
    ) -> UIImage? {
        guard let activeLayer = snapshot.layers.first(where: { $0.index == activeLayerIndex }) else {
            return nil
        }

        guard let transformedLayerData = makeTransformedLayerPreview(
            layerData: activeLayer.pixelData,
            canvasWidth: snapshot.width,
            canvasHeight: snapshot.height,
            selection: selection
        ) else {
            return nil
        }

        var composite = Data(count: snapshot.width * snapshot.height * 4)
        composite.withUnsafeMutableBytes { destinationBytes in
            guard let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for layer in snapshot.layers.sorted(by: { $0.index < $1.index }) where layer.visible {
                let sourceData = layer.index == activeLayerIndex ? transformedLayerData : layer.pixelData
                sourceData.withUnsafeBytes { sourceBytes in
                    guard let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                    for pixelIndex in 0..<(snapshot.width * snapshot.height) {
                        let offset = pixelIndex * 4
                        blendPixel(
                            destination: destination + offset,
                            source: source + offset,
                            opacity: CGFloat(layer.opacity),
                            blendMode: layer.blendMode
                        )
                    }
                }
            }
        }

        return makeLayerImage(pixelData: composite, width: snapshot.width, height: snapshot.height)
    }

    private func makeLayerImage(pixelData: Data, width: Int, height: Int) -> UIImage? {
        guard width > 0, height > 0, pixelData.count == width * height * 4 else { return nil }
        guard let provider = CGDataProvider(data: pixelData as CFData) else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            return nil
        }
        return UIImage(cgImage: image)
    }

    private func makeTransformedLayerPreview(
        layerData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selection: CanvasSelection?
    ) -> Data? {
        guard layerData.count == canvasWidth * canvasHeight * 4 else { return nil }
        let source = [UInt8](layerData)
        var destination = source
        let dx = Int(transformPreviewOffset.width.rounded())
        let dy = Int(transformPreviewOffset.height.rounded())
        guard dx != 0 || dy != 0 else { return layerData }

        if let selection {
            let mask = expandedMask(for: selection, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
            for index in 0..<(canvasWidth * canvasHeight) where mask[index] != 0 {
                let offset = index * 4
                guard source[offset + 3] != 0 else { continue }
                destination[offset] = 0
                destination[offset + 1] = 0
                destination[offset + 2] = 0
                destination[offset + 3] = 0
            }

            for y in 0..<canvasHeight {
                for x in 0..<canvasWidth {
                    let sourceIndex = (y * canvasWidth) + x
                    guard mask[sourceIndex] != 0 else { continue }
                    let sourceOffset = sourceIndex * 4
                    guard source[sourceOffset + 3] != 0 else { continue }
                    let destinationX = x + dx
                    let destinationY = y + dy
                    guard destinationX >= 0, destinationX < canvasWidth, destinationY >= 0, destinationY < canvasHeight else { continue }
                    let destinationOffset = ((destinationY * canvasWidth) + destinationX) * 4
                    destination[destinationOffset] = source[sourceOffset]
                    destination[destinationOffset + 1] = source[sourceOffset + 1]
                    destination[destinationOffset + 2] = source[sourceOffset + 2]
                    destination[destinationOffset + 3] = source[sourceOffset + 3]
                }
            }
        } else {
            destination = [UInt8](repeating: 0, count: source.count)
            for y in 0..<canvasHeight {
                for x in 0..<canvasWidth {
                    let sourceOffset = ((y * canvasWidth) + x) * 4
                    guard source[sourceOffset + 3] != 0 else { continue }
                    let destinationX = x + dx
                    let destinationY = y + dy
                    guard destinationX >= 0, destinationX < canvasWidth, destinationY >= 0, destinationY < canvasHeight else { continue }
                    let destinationOffset = ((destinationY * canvasWidth) + destinationX) * 4
                    destination[destinationOffset] = source[sourceOffset]
                    destination[destinationOffset + 1] = source[sourceOffset + 1]
                    destination[destinationOffset + 2] = source[sourceOffset + 2]
                    destination[destinationOffset + 3] = source[sourceOffset + 3]
                }
            }
        }

        return Data(destination)
    }

    private func expandedMask(for selection: CanvasSelection, canvasWidth: Int, canvasHeight: Int) -> [UInt8] {
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

    private func blendPixel(
        destination: UnsafeMutablePointer<UInt8>,
        source: UnsafePointer<UInt8>,
        opacity: CGFloat,
        blendMode: LayerBlendMode
    ) {
        let srcAlpha = (CGFloat(source[3]) / 255.0) * opacity
        guard srcAlpha > 0.001 else { return }
        let dstAlpha = CGFloat(destination[3]) / 255.0
        let outAlpha = srcAlpha + (dstAlpha * (1 - srcAlpha))
        guard outAlpha > 0.001 else { return }

        let srcR = CGFloat(source[0]) / 255.0
        let srcG = CGFloat(source[1]) / 255.0
        let srcB = CGFloat(source[2]) / 255.0
        let dstR = CGFloat(destination[0]) / 255.0
        let dstG = CGFloat(destination[1]) / 255.0
        let dstB = CGFloat(destination[2]) / 255.0
        let blended = blendColor(backdrop: (dstR, dstG, dstB), source: (srcR, srcG, srcB), blendMode: blendMode)

        let outR = (
            srcAlpha * ((1 - dstAlpha) * srcR + (dstAlpha * blended.r)) +
            (dstAlpha * (1 - srcAlpha) * dstR)
        ) / outAlpha
        let outG = (
            srcAlpha * ((1 - dstAlpha) * srcG + (dstAlpha * blended.g)) +
            (dstAlpha * (1 - srcAlpha) * dstG)
        ) / outAlpha
        let outB = (
            srcAlpha * ((1 - dstAlpha) * srcB + (dstAlpha * blended.b)) +
            (dstAlpha * (1 - srcAlpha) * dstB)
        ) / outAlpha

        destination[0] = UInt8(max(0, min(255, Int((outR * 255.0).rounded()))))
        destination[1] = UInt8(max(0, min(255, Int((outG * 255.0).rounded()))))
        destination[2] = UInt8(max(0, min(255, Int((outB * 255.0).rounded()))))
        destination[3] = UInt8(max(0, min(255, Int((outAlpha * 255.0).rounded()))))
    }

    private func blendColor(
        backdrop: (r: CGFloat, g: CGFloat, b: CGFloat),
        source: (r: CGFloat, g: CGFloat, b: CGFloat),
        blendMode: LayerBlendMode
    ) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        if blendMode == .darkerColor {
            return luminosity(source) < luminosity(backdrop) ? source : backdrop
        }

        if blendMode == .lighterColor {
            return luminosity(source) > luminosity(backdrop) ? source : backdrop
        }

        if blendMode == .hue {
            var output = source
            output = setSaturation(output, saturation(backdrop))
            output = setLuminosity(output, luminosity(backdrop))
            return (
                r: max(0, min(1, output.r)),
                g: max(0, min(1, output.g)),
                b: max(0, min(1, output.b))
            )
        }

        if blendMode == .saturation {
            var output = backdrop
            output = setSaturation(output, saturation(source))
            output = setLuminosity(output, luminosity(backdrop))
            return (
                r: max(0, min(1, output.r)),
                g: max(0, min(1, output.g)),
                b: max(0, min(1, output.b))
            )
        }

        if blendMode == .color {
            var output = source
            output = setSaturation(output, saturation(source))
            output = setLuminosity(output, luminosity(backdrop))
            return (
                r: max(0, min(1, output.r)),
                g: max(0, min(1, output.g)),
                b: max(0, min(1, output.b))
            )
        }

        if blendMode == .luminosity {
            var output = backdrop
            output = setLuminosity(output, luminosity(source))
            return (
                r: max(0, min(1, output.r)),
                g: max(0, min(1, output.g)),
                b: max(0, min(1, output.b))
            )
        }

        return (
            r: max(0, min(1, blendChannel(backdrop: backdrop.r, source: source.r, blendMode: blendMode))),
            g: max(0, min(1, blendChannel(backdrop: backdrop.g, source: source.g, blendMode: blendMode))),
            b: max(0, min(1, blendChannel(backdrop: backdrop.b, source: source.b, blendMode: blendMode)))
        )
    }

    private func blendChannel(backdrop: CGFloat, source: CGFloat, blendMode: LayerBlendMode) -> CGFloat {
        switch blendMode {
        case .normal:
            return source
        case .darken:
            return min(backdrop, source)
        case .multiply:
            return backdrop * source
        case .colorBurn:
            return source <= 0 ? 0 : max(0, 1 - ((1 - backdrop) / max(0.001, source)))
        case .linearBurn:
            return max(0, backdrop + source - 1)
        case .subtract:
            return max(0, backdrop - source)
        case .lighten:
            return max(backdrop, source)
        case .screen:
            return 1 - ((1 - backdrop) * (1 - source))
        case .add:
            return min(1, backdrop + source)
        case .colorDodge:
            return source >= 1 ? 1 : min(1, backdrop / max(0.001, 1 - source))
        case .glowDodge:
            return source >= 1 ? 1 : min(1, backdrop / max(0.0005, 1 - (source * 0.92)))
        case .overlay:
            return backdrop <= 0.5 ? (2 * backdrop * source) : (1 - 2 * (1 - backdrop) * (1 - source))
        case .softLight:
            return source <= 0.5
                ? (backdrop - ((1 - 2 * source) * backdrop * (1 - backdrop)))
                : (backdrop + ((2 * source - 1) * ((backdrop <= 0.25)
                    ? ((((16 * backdrop - 12) * backdrop) + 4) * backdrop)
                    : sqrt(backdrop)) - backdrop))
        case .hardLight:
            return source <= 0.5 ? (2 * backdrop * source) : (1 - 2 * (1 - backdrop) * (1 - source))
        case .difference:
            return abs(backdrop - source)
        case .vividLight:
            return source <= 0.5
                ? blendChannel(backdrop: backdrop, source: 2 * source, blendMode: .colorBurn)
                : blendChannel(backdrop: backdrop, source: 2 * (source - 0.5), blendMode: .colorDodge)
        case .linearLight:
            return max(0, min(1, backdrop + 2 * source - 1))
        case .pinLight:
            return source <= 0.5 ? min(backdrop, 2 * source) : max(backdrop, 2 * (source - 0.5))
        case .hardMix:
            return blendChannel(backdrop: backdrop, source: source, blendMode: .vividLight) < 0.5 ? 0 : 1
        case .exclusion:
            return backdrop + source - (2 * backdrop * source)
        case .darkerColor, .lighterColor, .hue, .saturation, .color, .luminosity:
            return source
        case .divide:
            return min(1, backdrop / max(0.001, source))
        case .addGlow:
            return min(1, backdrop + source * 1.35)
        }
    }

    private func luminosity(_ color: (r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat {
        (0.3 * color.r) + (0.59 * color.g) + (0.11 * color.b)
    }

    private func saturation(_ color: (r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat {
        max(color.r, color.g, color.b) - min(color.r, color.g, color.b)
    }

    private func clipColor(_ color: (r: CGFloat, g: CGFloat, b: CGFloat)) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let lum = luminosity(color)
        let minimum = min(color.r, color.g, color.b)
        let maximum = max(color.r, color.g, color.b)
        var output = color

        if minimum < 0 {
            let scale = lum / max(0.001, lum - minimum)
            output = (
                r: lum + ((output.r - lum) * scale),
                g: lum + ((output.g - lum) * scale),
                b: lum + ((output.b - lum) * scale)
            )
        }

        if maximum > 1 {
            let adjustedMaximum = max(output.r, output.g, output.b)
            let scale = (1 - lum) / max(0.001, adjustedMaximum - lum)
            output = (
                r: lum + ((output.r - lum) * scale),
                g: lum + ((output.g - lum) * scale),
                b: lum + ((output.b - lum) * scale)
            )
        }

        return output
    }

    private func setLuminosity(_ color: (r: CGFloat, g: CGFloat, b: CGFloat), _ lum: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let delta = lum - luminosity(color)
        return clipColor(
            (
                r: color.r + delta,
                g: color.g + delta,
                b: color.b + delta
            )
        )
    }

    private func setSaturation(_ color: (r: CGFloat, g: CGFloat, b: CGFloat), _ sat: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let original = [color.r, color.g, color.b]
        var components = original
        var minIndex = 0
        var midIndex = 1
        var maxIndex = 2

        if original[minIndex] > original[midIndex] { swap(&minIndex, &midIndex) }
        if original[midIndex] > original[maxIndex] { swap(&midIndex, &maxIndex) }
        if original[minIndex] > original[midIndex] { swap(&minIndex, &midIndex) }

        if original[maxIndex] > original[minIndex] {
            components[midIndex] = ((original[midIndex] - original[minIndex]) * sat) / (original[maxIndex] - original[minIndex])
            components[maxIndex] = sat
        } else {
            components[midIndex] = 0
            components[maxIndex] = 0
        }
        components[minIndex] = 0

        return (r: components[0], g: components[1], b: components[2])
    }

    private enum PanPhase {
        case began
        case moved
        case ended
        case cancelled
    }

    private func handlePanTouchesIfNeeded(_ touches: Set<UITouch>, phase: PanPhase) -> Bool {
        guard currentTool == .move, let touch = touches.first, touch.type != .pencil else {
            if phase == .ended || phase == .cancelled {
                panStartLocation = nil
                panDidMove = false
                isCanvasPanGestureActive = false
            }
            return false
        }

        let location = touch.preciseLocation(in: self)
        switch phase {
        case .began:
            panStartLocation = location
            panStartOffset = viewportOffset
            panDidMove = false
            isCanvasPanGestureActive = true
        case .moved:
            guard let panStartLocation else { return true }
            let deltaX = location.x - panStartLocation.x
            let deltaY = location.y - panStartLocation.y
            if hypot(deltaX, deltaY) > 3.0 {
                panDidMove = true
            }
            let nextOffset = CGSize(
                width: panStartOffset.width + deltaX,
                height: panStartOffset.height + deltaY
            )
            let clampedOffset = clampedViewportOffset(nextOffset)
            sendAction?(.viewportOffsetChanged(clampedOffset))
        case .ended, .cancelled:
            if panDidMove {
                lastNavigationGestureEndedAt = CACurrentMediaTime()
            }
            panStartLocation = nil
            panDidMove = false
            isCanvasPanGestureActive = false
        }
        return true
    }

    private func shouldSuppressHistoryTap() -> Bool {
        if isPinchGestureActive || isCanvasPanGestureActive || pinchAnchorDocumentPoint != nil {
            return true
        }
        return (CACurrentMediaTime() - lastNavigationGestureEndedAt) < 0.22
    }

    private func clampedViewportOffset(_ proposedOffset: CGSize) -> CGSize {
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        let fitted = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledWidth = fitted.width * zoomScale
        let scaledHeight = fitted.height * zoomScale
        let horizontalLimit = max(0, (scaledWidth - drawableRect.width) / 2 + 120)
        let verticalLimit = max(0, (scaledHeight - drawableRect.height) / 2 + 120)
        return CGSize(
            width: min(max(proposedOffset.width, -horizontalLimit), horizontalLimit),
            height: min(max(proposedOffset.height, -verticalLimit), verticalLimit)
        )
    }

    @objc
    private func handleTwoFingerUndoTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        guard !shouldSuppressHistoryTap() else { return }
        sendAction?(.requestLocalUndo)
    }

    @objc
    private func handleThreeFingerRedoTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        guard !shouldSuppressHistoryTap() else { return }
        sendAction?(.requestLocalRedo)
    }

    @objc
    private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard documentSize.width > 0, documentSize.height > 0 else { return }

        let location = recognizer.location(in: self)
        switch recognizer.state {
        case .began:
            isPinchGestureActive = true
            pinchStartScale = zoomScale
            pinchAnchorDocumentPoint = documentPoint(at: location, in: contentRect())

        case .changed:
            guard let pinchAnchorDocumentPoint else { return }
            let newScale = min(max(pinchStartScale * recognizer.scale, 0.6), 4.0)
            let newOffset = offsetKeepingDocumentPointStable(
                pinchAnchorDocumentPoint,
                at: location,
                zoomScale: newScale
            )
            sendAction?(.zoomScaleChanged(newScale))
            sendAction?(.viewportOffsetChanged(newOffset))

        case .ended, .cancelled, .failed:
            if isPinchGestureActive {
                lastNavigationGestureEndedAt = CACurrentMediaTime()
            }
            isPinchGestureActive = false
            pinchAnchorDocumentPoint = nil

        default:
            break
        }
    }

    private func documentPoint(at viewPoint: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: ((viewPoint.x - rect.minX) / max(rect.width, 1)) * documentSize.width,
            y: ((viewPoint.y - rect.minY) / max(rect.height, 1)) * documentSize.height
        )
    }

    private func offsetKeepingDocumentPointStable(_ documentPoint: CGPoint, at viewPoint: CGPoint, zoomScale: CGFloat) -> CGSize {
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        let fittedRect = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledSize = CGSize(width: fittedRect.width * zoomScale, height: fittedRect.height * zoomScale)
        let normalizedX = documentPoint.x / max(documentSize.width, 1)
        let normalizedY = documentPoint.y / max(documentSize.height, 1)
        let desiredOrigin = CGPoint(
            x: viewPoint.x - (normalizedX * scaledSize.width),
            y: viewPoint.y - (normalizedY * scaledSize.height)
        )
        let baseOrigin = CGPoint(
            x: fittedRect.midX - (scaledSize.width / 2),
            y: fittedRect.midY - (scaledSize.height / 2)
        )
        return clampedViewportOffset(
            CGSize(width: desiredOrigin.x - baseOrigin.x, height: desiredOrigin.y - baseOrigin.y),
            zoomScale: zoomScale
        )
    }

    private func clampedViewportOffset(_ proposedOffset: CGSize, zoomScale: CGFloat) -> CGSize {
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        let fitted = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledWidth = fitted.width * zoomScale
        let scaledHeight = fitted.height * zoomScale
        let horizontalLimit = max(0, (scaledWidth - drawableRect.width) / 2 + 120)
        let verticalLimit = max(0, (scaledHeight - drawableRect.height) / 2 + 120)
        return CGSize(
            width: min(max(proposedOffset.width, -horizontalLimit), horizontalLimit),
            height: min(max(proposedOffset.height, -verticalLimit), verticalLimit)
        )
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

private extension PreviewStrokeStyle {
    var simdColor: SIMD4<Float> {
        guard let components = color.components else {
            return SIMD4(0, 0, 0, 1)
        }

        switch components.count {
        case 4:
            return SIMD4(Float(components[0]), Float(components[1]), Float(components[2]), Float(components[3]))
        case 2:
            return SIMD4(Float(components[0]), Float(components[0]), Float(components[0]), Float(components[1]))
        default:
            return SIMD4(0, 0, 0, 1)
        }
    }
}
