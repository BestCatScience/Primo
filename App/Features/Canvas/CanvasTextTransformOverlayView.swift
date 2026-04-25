import PrimoDocumentContracts
import PrimoDocumentDomain
import UIKit

final class CanvasTextTransformOverlayView: UIView, UIGestureRecognizerDelegate {
    private let boxView = TransformOutlineView()
    private let rotationStemView = UIView()
    private let topLeftHandleView = UIView()
    private let topRightHandleView = UIView()
    private let bottomLeftHandleView = UIView()
    private let scaleHandleView = UIView()
    private let leftMidHandleView = UIView()
    private let rightMidHandleView = UIView()
    private let bottomMidHandleView = UIView()
    private let rotationHandleView = UIView()
    private let pivotHandleView = UIView()
    private let canvasImageRenderer: CanvasImageRenderer

    private var context: Context?
    private var currentTransformGeometry: TextTransformGeometry?
    private var handleStartScale = CGSize(width: 1, height: 1)
    private var rotationHandleStartAngle: CGFloat = 0
    private var pivotTouchOffset: CGPoint = .zero
    private var activeTransformHandle: TransformOverlayHandle = .bottomRight

    var documentGpuOperationGateway: DocumentGpuOperationGateway?
    var sendAction: ((CanvasFeature.Action) -> Void)?

    init(canvasImageRenderer: CanvasImageRenderer) {
        self.canvasImageRenderer = canvasImageRenderer
        super.init(frame: .zero)
        isUserInteractionEnabled = true
        backgroundColor = .clear
        configureViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(context: Context) {
        self.context = context
        frame = context.geometry.bounds

        let geometry: TextTransformGeometry?
        if let selection = context.selection {
            geometry = transformGeometry(for: selection.bounds, context: context)
        } else if let activeTextLayer = context.activeTextLayer {
            geometry = textTransformGeometry(for: activeTextLayer, context: context)
        } else if
            let snapshot = context.snapshot,
            let activeLayer = snapshot.layers.first(where: { $0.index == context.activeLayerIndex })
        {
            geometry = layerTransformGeometry(
                layerData: activeLayer.pixelData,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height,
                context: context
            )
        } else {
            geometry = nil
        }

        guard context.currentTool == .move, let geometry else {
            hideOverlay()
            return
        }

        currentTransformGeometry = geometry
        boxView.isHidden = false
        rotationStemView.isHidden = context.transformMode != .standard
        topLeftHandleView.isHidden = false
        topRightHandleView.isHidden = false
        bottomLeftHandleView.isHidden = false
        scaleHandleView.isHidden = false
        leftMidHandleView.isHidden = false
        rightMidHandleView.isHidden = false
        bottomMidHandleView.isHidden = false
        rotationHandleView.isHidden = context.transformMode != .standard
        pivotHandleView.isHidden = context.transformMode != .standard

        let polygonPath = UIBezierPath()
        polygonPath.move(to: geometry.topLeft)
        polygonPath.addLine(to: geometry.topRight)
        polygonPath.addLine(to: geometry.bottomRight)
        polygonPath.addLine(to: geometry.bottomLeft)
        polygonPath.close()
        boxView.frame = bounds
        boxView.updatePath(polygonPath)

        rotationStemView.bounds = CGRect(x: 0, y: 0, width: 2, height: geometry.rotationStemLength)
        rotationStemView.center = CGPoint(
            x: (geometry.topMidpoint.x + geometry.rotationHandleCenter.x) / 2,
            y: (geometry.topMidpoint.y + geometry.rotationHandleCenter.y) / 2
        )
        rotationStemView.transform = .identity

        let cornerHandleSize = CGSize(width: 18, height: 18)
        topLeftHandleView.bounds = CGRect(origin: .zero, size: cornerHandleSize)
        topLeftHandleView.center = geometry.topLeft
        topLeftHandleView.transform = .identity

        topRightHandleView.bounds = CGRect(origin: .zero, size: cornerHandleSize)
        topRightHandleView.center = geometry.topRight
        topRightHandleView.transform = .identity

        bottomLeftHandleView.bounds = CGRect(origin: .zero, size: cornerHandleSize)
        bottomLeftHandleView.center = geometry.bottomLeft
        bottomLeftHandleView.transform = .identity

        let scaleHandleSize = CGSize(width: 22, height: 22)
        scaleHandleView.bounds = CGRect(origin: .zero, size: scaleHandleSize)
        scaleHandleView.center = geometry.bottomRight
        scaleHandleView.transform = .identity

        let edgeHandleSize = CGSize(width: 16, height: 16)
        leftMidHandleView.bounds = CGRect(origin: .zero, size: edgeHandleSize)
        leftMidHandleView.center = geometry.leftMidpoint
        leftMidHandleView.transform = .identity

        rightMidHandleView.bounds = CGRect(origin: .zero, size: edgeHandleSize)
        rightMidHandleView.center = geometry.rightMidpoint
        rightMidHandleView.transform = .identity

        bottomMidHandleView.bounds = CGRect(origin: .zero, size: edgeHandleSize)
        bottomMidHandleView.center = geometry.bottomMidpoint
        bottomMidHandleView.transform = .identity

        let rotationHandleSize = CGSize(width: 26, height: 26)
        rotationHandleView.bounds = CGRect(origin: .zero, size: rotationHandleSize)
        rotationHandleView.center = geometry.rotationHandleCenter
        rotationHandleView.transform = .identity

        let pivotHandleSize = CGSize(width: 24, height: 24)
        pivotHandleView.bounds = CGRect(origin: .zero, size: pivotHandleSize)
        pivotHandleView.center = geometry.pivotCenter
        pivotHandleView.transform = .identity
    }

    func ownsGesture(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        switch gestureRecognizer.view {
        case boxView,
             topLeftHandleView,
             topRightHandleView,
             bottomLeftHandleView,
             scaleHandleView,
             leftMidHandleView,
             rightMidHandleView,
             bottomMidHandleView,
             rotationHandleView,
             pivotHandleView:
            return true
        default:
            return false
        }
    }

    func containsInteractivePoint(_ point: CGPoint) -> Bool {
        let expandedFrames = [
            topLeftHandleView.frame.insetBy(dx: -10, dy: -10),
            topRightHandleView.frame.insetBy(dx: -10, dy: -10),
            bottomLeftHandleView.frame.insetBy(dx: -10, dy: -10),
            scaleHandleView.frame.insetBy(dx: -10, dy: -10),
            leftMidHandleView.frame.insetBy(dx: -10, dy: -10),
            rightMidHandleView.frame.insetBy(dx: -10, dy: -10),
            bottomMidHandleView.frame.insetBy(dx: -10, dy: -10),
            rotationHandleView.frame.insetBy(dx: -10, dy: -10),
            pivotHandleView.frame.insetBy(dx: -10, dy: -10)
        ]
        if expandedFrames.contains(where: { !$0.isEmpty && $0.contains(point) }) {
            return true
        }
        return !boxView.isHidden && boxView.point(inside: point, with: nil)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        containsInteractivePoint(point)
    }

    private func configureViews() {
        boxView.isHidden = true
        let textBoxPanRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleBoxPan(_:)))
        textBoxPanRecognizer.delegate = self
        boxView.addGestureRecognizer(textBoxPanRecognizer)
        addSubview(boxView)

        rotationStemView.isHidden = true
        rotationStemView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.92)
        rotationStemView.layer.cornerRadius = 1
        addSubview(rotationStemView)

        configureTextHandle(scaleHandleView, symbol: "arrow.up.left.and.arrow.down.right")
        installScalePan(on: scaleHandleView)
        addSubview(scaleHandleView)

        configurePassiveTransformHandle(topLeftHandleView)
        installScalePan(on: topLeftHandleView)
        addSubview(topLeftHandleView)

        configurePassiveTransformHandle(topRightHandleView)
        installScalePan(on: topRightHandleView)
        addSubview(topRightHandleView)

        configurePassiveTransformHandle(bottomLeftHandleView)
        installScalePan(on: bottomLeftHandleView)
        addSubview(bottomLeftHandleView)

        configurePassiveTransformHandle(leftMidHandleView)
        installScalePan(on: leftMidHandleView)
        addSubview(leftMidHandleView)

        configurePassiveTransformHandle(rightMidHandleView)
        installScalePan(on: rightMidHandleView)
        addSubview(rightMidHandleView)

        configurePassiveTransformHandle(bottomMidHandleView)
        installScalePan(on: bottomMidHandleView)
        addSubview(bottomMidHandleView)

        configureTextHandle(rotationHandleView, symbol: "rotate.right.fill")
        let rotationHandlePanRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleRotationPan(_:)))
        rotationHandlePanRecognizer.delegate = self
        rotationHandleView.addGestureRecognizer(rotationHandlePanRecognizer)
        addSubview(rotationHandleView)

        configureTextHandle(pivotHandleView, symbol: "scope")
        let pivotHandlePanRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePivotPan(_:)))
        pivotHandlePanRecognizer.delegate = self
        pivotHandleView.addGestureRecognizer(pivotHandlePanRecognizer)
        addSubview(pivotHandleView)
    }

    private func installScalePan(on handle: UIView) {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleScalePan(_:)))
        panRecognizer.delegate = self
        handle.addGestureRecognizer(panRecognizer)
    }

    private func hideOverlay() {
        currentTransformGeometry = nil
        boxView.isHidden = true
        boxView.updatePath(nil)
        rotationStemView.isHidden = true
        topLeftHandleView.isHidden = true
        topRightHandleView.isHidden = true
        bottomLeftHandleView.isHidden = true
        scaleHandleView.isHidden = true
        leftMidHandleView.isHidden = true
        rightMidHandleView.isHidden = true
        bottomMidHandleView.isHidden = true
        rotationHandleView.isHidden = true
        pivotHandleView.isHidden = true
    }

    private func configureTextHandle(_ handle: UIView, symbol: String) {
        handle.isHidden = true
        let isRotationHandle = symbol.contains("rotate")
        handle.backgroundColor = isRotationHandle
            ? UIColor.systemBlue.withAlphaComponent(0.98)
            : UIColor.white.withAlphaComponent(0.98)
        handle.layer.cornerRadius = isRotationHandle ? 15 : 5
        handle.layer.borderColor = isRotationHandle
            ? UIColor.white.withAlphaComponent(0.92).cgColor
            : UIColor.systemBlue.withAlphaComponent(0.96).cgColor
        handle.layer.borderWidth = isRotationHandle ? 1.1 : 1.6
        handle.layer.shadowColor = UIColor.black.cgColor
        handle.layer.shadowOpacity = 0.16
        handle.layer.shadowRadius = 5
        handle.layer.shadowOffset = CGSize(width: 0, height: 2)
        handle.isUserInteractionEnabled = true

        let imageView = UIImageView(image: UIImage(systemName: symbol))
        imageView.tintColor = isRotationHandle
            ? UIColor.white.withAlphaComponent(0.96)
            : UIColor.systemBlue.withAlphaComponent(0.96)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        handle.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: handle.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: handle.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 14),
            imageView.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    private func configurePassiveTransformHandle(_ handle: UIView) {
        handle.isHidden = true
        handle.backgroundColor = UIColor.white.withAlphaComponent(0.98)
        handle.layer.cornerRadius = 4
        handle.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.96).cgColor
        handle.layer.borderWidth = 1.4
        handle.layer.shadowColor = UIColor.black.cgColor
        handle.layer.shadowOpacity = 0.12
        handle.layer.shadowRadius = 4
        handle.layer.shadowOffset = CGSize(width: 0, height: 1)
        handle.isUserInteractionEnabled = true
    }

    private func textTransformGeometry(for textLayer: TextLayerData, context: Context) -> TextTransformGeometry? {
        guard context.geometry.documentSize.width > 0, context.geometry.documentSize.height > 0 else { return nil }
        var transformed = textLayer
        transformed.position = CGPoint(
            x: transformed.position.x + context.transformPreviewOffset.width,
            y: transformed.position.y + context.transformPreviewOffset.height
        )
        transformed.scale = min(max(transformed.scale * Double((context.transformPreviewScaleX + context.transformPreviewScaleY) * 0.5), 0.2), 6.0)
        transformed.rotationDegrees += context.transformPreviewRotationDegrees

        guard let documentGpuOperationGateway,
              let drawRect = canvasImageRenderer.transformedTextLayoutRect(
            gpuOperations: documentGpuOperationGateway,
            textLayer: transformed,
            canvasSize: context.geometry.documentSize
        ) else {
            return nil
        }
        let quad = TransformQuad(
            topLeft: CGPoint(x: drawRect.minX, y: drawRect.minY),
            topRight: CGPoint(x: drawRect.maxX, y: drawRect.minY),
            bottomLeft: CGPoint(x: drawRect.minX, y: drawRect.maxY),
            bottomRight: CGPoint(x: drawRect.maxX, y: drawRect.maxY)
        )
        return geometry(sourceRect: drawRect, quad: quad, pivot: transformed.position, context: context)
    }

    private func layerTransformGeometry(layerData: Data, canvasWidth: Int, canvasHeight: Int, context: Context) -> TextTransformGeometry? {
        let source = [UInt8](layerData)
        guard let bounds = transformationBounds(selection: nil, source: source, canvasWidth: canvasWidth, canvasHeight: canvasHeight) else {
            return nil
        }
        return transformGeometry(for: bounds, context: context)
    }

    private func transformGeometry(for rect: CGRect, mode: CanvasTransformMode? = nil, context: Context) -> TextTransformGeometry {
        let resolvedQuad = effectiveTransformQuad(for: rect, mode: mode, context: context)
        return geometry(sourceRect: rect, quad: resolvedQuad, pivot: visualTransformPivot(for: rect, context: context), context: context)
    }

    private func geometry(sourceRect: CGRect, quad: TransformQuad, pivot: CGPoint, context: Context) -> TextTransformGeometry {
        let corners = quad.points.map(context.geometry.viewPoint(fromDocumentPoint:))
        let topMidpoint = context.geometry.viewPoint(fromDocumentPoint: quad.topMidpoint)
        let leftMidpoint = context.geometry.viewPoint(fromDocumentPoint: quad.leftMidpoint)
        let rightMidpoint = context.geometry.viewPoint(fromDocumentPoint: quad.rightMidpoint)
        let bottomMidpoint = context.geometry.viewPoint(fromDocumentPoint: quad.bottomMidpoint)
        let centerView = context.geometry.viewPoint(fromDocumentPoint: quad.center)
        let topEdgeVector = CGPoint(x: corners[1].x - corners[0].x, y: corners[1].y - corners[0].y)
        let topEdgeLength = max(hypot(topEdgeVector.x, topEdgeVector.y), 1)
        let outwardNormal = CGPoint(x: -(topEdgeVector.y / topEdgeLength), y: topEdgeVector.x / topEdgeLength)
        let rotationHandleCenter = CGPoint(
            x: topMidpoint.x + (outwardNormal.x * -30),
            y: topMidpoint.y + (outwardNormal.y * -30)
        )
        let bounds = transformedRect(for: quad, context: context)
        return TextTransformGeometry(
            sourceRect: sourceRect,
            quad: quad,
            bounds: bounds,
            center: centerView,
            topLeft: corners[0],
            topRight: corners[1],
            bottomLeft: corners[2],
            bottomRight: corners[3],
            topMidpoint: topMidpoint,
            leftMidpoint: leftMidpoint,
            rightMidpoint: rightMidpoint,
            bottomMidpoint: bottomMidpoint,
            rotationHandleCenter: rotationHandleCenter,
            pivotCenter: context.geometry.viewPoint(fromDocumentPoint: pivot),
            rotationStemLength: max(hypot(rotationHandleCenter.x - topMidpoint.x, rotationHandleCenter.y - topMidpoint.y), 18)
        )
    }

    private func effectiveTransformQuad(for rect: CGRect, mode overrideMode: CanvasTransformMode? = nil, context: Context) -> TransformQuad {
        AppFeature.effectiveTransformQuad(
            bounds: rect,
            translation: context.transformPreviewOffset,
            scaleX: context.transformPreviewScaleX,
            scaleY: context.transformPreviewScaleY,
            rotationDegrees: context.transformPreviewRotationDegrees,
            pivot: context.transformPivot,
            mode: overrideMode ?? context.transformMode,
            quadOffsets: context.transformQuadOffsets
        ).effective
    }

    private func affineTransformQuad(for rect: CGRect, context: Context) -> TransformQuad {
        AppFeature.affineTransformQuad(
            bounds: rect,
            translation: context.transformPreviewOffset,
            scaleX: context.transformPreviewScaleX,
            scaleY: context.transformPreviewScaleY,
            rotationDegrees: context.transformPreviewRotationDegrees,
            pivot: context.transformPivot
        ).quad
    }

    private func visualTransformPivot(for rect: CGRect, context: Context) -> CGPoint {
        let fallbackPivot = CGPoint(x: rect.midX, y: rect.midY)
        let sourcePivot = context.transformPivot ?? fallbackPivot
        return CGPoint(
            x: sourcePivot.x + context.transformPreviewOffset.width,
            y: sourcePivot.y + context.transformPreviewOffset.height
        )
    }

    private func transformedRect(for quad: TransformQuad, context: Context) -> CGRect {
        let corners = quad.points.map(context.geometry.viewPoint(fromDocumentPoint:))
        let minX = corners.map(\.x).min() ?? 0
        let maxX = corners.map(\.x).max() ?? 0
        let minY = corners.map(\.y).min() ?? 0
        let maxY = corners.map(\.y).max() ?? 0
        return CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))
    }

    private func transformationBounds(selection: CanvasSelection?, source: [UInt8], canvasWidth: Int, canvasHeight: Int) -> CGRect? {
        if let selection, !selection.isEmpty {
            return selection.bounds
        }

        var minX = canvasWidth
        var minY = canvasHeight
        var maxX = -1
        var maxY = -1
        for y in 0..<canvasHeight {
            for x in 0..<canvasWidth {
                if source[((y * canvasWidth) + x) * 4 + 3] == 0 { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    @objc
    private func handleBoxPan(_ recognizer: UIPanGestureRecognizer) {
        guard let context, context.currentTool == .move, currentTransformGeometry != nil else { return }
        let translation = recognizer.translation(in: self)
        let documentOffset = context.geometry.documentTranslation(from: translation)
        switch recognizer.state {
        case .began:
            sendAction?(.transformGestureBegan)
            sendAction?(.transformPreviewChanged(.zero))
        case .changed:
            sendAction?(.transformPreviewChanged(documentOffset))
        case .ended, .cancelled, .failed:
            sendAction?(.transformEnded(documentOffset))
        default:
            break
        }
    }

    @objc
    private func handleScalePan(_ recognizer: UIPanGestureRecognizer) {
        guard let context, context.currentTool == .move, let geometry = currentTransformGeometry else { return }
        let handle = transformHandle(for: recognizer.view)
        let location = recognizer.location(in: self)

        switch recognizer.state {
        case .began:
            activeTransformHandle = handle
            handleStartScale = CGSize(width: context.transformPreviewScaleX, height: context.transformPreviewScaleY)
        case .changed:
            sendScaleOrQuadUpdate(handle: handle, location: location, recognizer: recognizer, geometry: geometry, context: context)
        case .ended, .cancelled, .failed:
            sendScaleOrQuadUpdate(handle: handle, location: location, recognizer: recognizer, geometry: geometry, context: context)
        default:
            break
        }
    }

    private func sendScaleOrQuadUpdate(
        handle: TransformOverlayHandle,
        location: CGPoint,
        recognizer: UIPanGestureRecognizer,
        geometry: TextTransformGeometry,
        context: Context
    ) {
        if context.transformMode == .standard {
            let translation = recognizer.translation(in: self)
            let nextScale = freeformScale(from: handleStartScale, translation: translation, handle: handle, context: context)
            sendAction?(.transformScaleSet(x: nextScale.width, y: nextScale.height))
        } else {
            sendAction?(.transformQuadOffsetsSet(quadOffsetsForDraggedHandle(handle, location: location, geometry: geometry, context: context)))
        }
    }

    @objc
    private func handleRotationPan(_ recognizer: UIPanGestureRecognizer) {
        guard let context, context.transformMode == .standard else { return }
        guard context.currentTool == .move, let geometry = currentTransformGeometry else { return }
        let location = recognizer.location(in: self)
        let angle = atan2(location.y - geometry.pivotCenter.y, location.x - geometry.pivotCenter.x)

        switch recognizer.state {
        case .began:
            rotationHandleStartAngle = angle
            sendAction?(.transformRotationGestureBegan)
        case .changed:
            sendAction?(.transformRotationChanged(angle - rotationHandleStartAngle))
        case .ended, .cancelled, .failed:
            sendAction?(.transformRotationEnded(angle - rotationHandleStartAngle))
        default:
            break
        }
    }

    @objc
    private func handlePivotPan(_ recognizer: UIPanGestureRecognizer) {
        guard let context, context.transformMode == .standard else { return }
        guard context.currentTool == .move, let geometry = currentTransformGeometry else { return }
        let location = recognizer.location(in: self)

        switch recognizer.state {
        case .began:
            pivotTouchOffset = CGPoint(
                x: geometry.pivotCenter.x - location.x,
                y: geometry.pivotCenter.y - location.y
            )
        case .changed, .ended:
            let targetViewPoint = CGPoint(
                x: location.x + pivotTouchOffset.x,
                y: location.y + pivotTouchOffset.y
            )
            let documentPoint = context.geometry.documentPoint(fromViewPoint: targetViewPoint)
            sendAction?(.transformPivotSet(CGPoint(
                x: documentPoint.x - context.transformPreviewOffset.width,
                y: documentPoint.y - context.transformPreviewOffset.height
            )))
        default:
            break
        }
    }

    private func transformHandle(for view: UIView?) -> TransformOverlayHandle {
        switch view {
        case topLeftHandleView: return .topLeft
        case topRightHandleView: return .topRight
        case bottomLeftHandleView: return .bottomLeft
        case leftMidHandleView: return .leftEdge
        case rightMidHandleView: return .rightEdge
        case bottomMidHandleView: return .bottomEdge
        default: return .bottomRight
        }
    }

    private func freeformScale(from startScale: CGSize, translation: CGPoint, handle: TransformOverlayHandle, context: Context) -> CGSize {
        let xDelta = translation.x / 160.0
        let yDelta = translation.y / 160.0
        var scaleX = startScale.width
        var scaleY = startScale.height

        switch handle {
        case .topLeft:
            scaleX -= xDelta
            scaleY -= yDelta
        case .topRight:
            scaleX += xDelta
            scaleY -= yDelta
        case .bottomLeft:
            scaleX -= xDelta
            scaleY += yDelta
        case .bottomRight:
            scaleX += xDelta
            scaleY += yDelta
        case .leftEdge:
            scaleX -= xDelta
        case .rightEdge:
            scaleX += xDelta
        case .bottomEdge:
            scaleY += yDelta
        }

        if context.transformMode == .standard && context.transformLocksAspectRatio {
            let startWidth = max(startScale.width, 0.0001)
            let startHeight = max(startScale.height, 0.0001)
            let ratioX = scaleX / startWidth
            let ratioY = scaleY / startHeight
            let uniformRatio: CGFloat

            switch handle {
            case .leftEdge, .rightEdge:
                uniformRatio = ratioX
            case .bottomEdge:
                uniformRatio = ratioY
            case .topLeft, .topRight, .bottomLeft, .bottomRight:
                uniformRatio = abs(ratioX - 1.0) >= abs(ratioY - 1.0) ? ratioX : ratioY
            }

            scaleX = startScale.width * uniformRatio
            scaleY = startScale.height * uniformRatio
        }

        return CGSize(width: min(max(scaleX, 0.2), 6.0), height: min(max(scaleY, 0.2), 6.0))
    }

    private func quadOffsetsForDraggedHandle(
        _ handle: TransformOverlayHandle,
        location: CGPoint,
        geometry: TextTransformGeometry,
        context: Context
    ) -> TransformQuadOffsets {
        let documentPoint = context.geometry.documentPoint(fromViewPoint: location)
        let affineQuad = affineTransformQuad(for: geometry.sourceRect, context: context)
        var adjustedQuad = geometry.quad

        switch handle {
        case .topLeft:
            adjustedQuad.topLeft = documentPoint
        case .topRight:
            adjustedQuad.topRight = documentPoint
        case .bottomLeft:
            adjustedQuad.bottomLeft = documentPoint
        case .bottomRight:
            adjustedQuad.bottomRight = documentPoint
        case .leftEdge:
            let existing = geometry.quad.leftMidpoint
            let documentDelta = CGSize(width: documentPoint.x - existing.x, height: documentPoint.y - existing.y)
            adjustedQuad.topLeft.x += documentDelta.width
            adjustedQuad.topLeft.y += documentDelta.height
            adjustedQuad.bottomLeft.x += documentDelta.width
            adjustedQuad.bottomLeft.y += documentDelta.height
        case .rightEdge:
            let existing = geometry.quad.rightMidpoint
            let documentDelta = CGSize(width: documentPoint.x - existing.x, height: documentPoint.y - existing.y)
            adjustedQuad.topRight.x += documentDelta.width
            adjustedQuad.topRight.y += documentDelta.height
            adjustedQuad.bottomRight.x += documentDelta.width
            adjustedQuad.bottomRight.y += documentDelta.height
        case .bottomEdge:
            let existing = geometry.quad.bottomMidpoint
            let documentDelta = CGSize(width: documentPoint.x - existing.x, height: documentPoint.y - existing.y)
            adjustedQuad.bottomLeft.x += documentDelta.width
            adjustedQuad.bottomLeft.y += documentDelta.height
            adjustedQuad.bottomRight.x += documentDelta.width
            adjustedQuad.bottomRight.y += documentDelta.height
        }

        return TransformQuadOffsets(
            topLeft: CGSize(width: adjustedQuad.topLeft.x - affineQuad.topLeft.x, height: adjustedQuad.topLeft.y - affineQuad.topLeft.y),
            topRight: CGSize(width: adjustedQuad.topRight.x - affineQuad.topRight.x, height: adjustedQuad.topRight.y - affineQuad.topRight.y),
            bottomLeft: CGSize(width: adjustedQuad.bottomLeft.x - affineQuad.bottomLeft.x, height: adjustedQuad.bottomLeft.y - affineQuad.bottomLeft.y),
            bottomRight: CGSize(width: adjustedQuad.bottomRight.x - affineQuad.bottomRight.x, height: adjustedQuad.bottomRight.y - affineQuad.bottomRight.y)
        )
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer.view === boxView else { return true }
        let location = touch.location(in: self)
        if topLeftHandleView.frame.insetBy(dx: -8, dy: -8).contains(location) { return false }
        if topRightHandleView.frame.insetBy(dx: -8, dy: -8).contains(location) { return false }
        if bottomLeftHandleView.frame.insetBy(dx: -8, dy: -8).contains(location) { return false }
        if scaleHandleView.frame.insetBy(dx: -8, dy: -8).contains(location) { return false }
        if leftMidHandleView.frame.insetBy(dx: -8, dy: -8).contains(location) { return false }
        if rightMidHandleView.frame.insetBy(dx: -8, dy: -8).contains(location) { return false }
        if bottomMidHandleView.frame.insetBy(dx: -8, dy: -8).contains(location) { return false }
        if rotationHandleView.frame.insetBy(dx: -8, dy: -8).contains(location) { return false }
        if pivotHandleView.frame.insetBy(dx: -8, dy: -8).contains(location) { return false }
        return true
    }
}

extension CanvasTextTransformOverlayView {
    struct Context {
        let snapshot: MetalDocumentSnapshot?
        let activeLayerIndex: Int
        let currentTool: StudioToolKind
        let selection: CanvasSelection?
        let transformPreviewOffset: CGSize
        let transformPreviewScaleX: CGFloat
        let transformPreviewScaleY: CGFloat
        let transformPreviewRotationDegrees: Double
        let transformPivot: CGPoint?
        let transformMode: CanvasTransformMode
        let transformLocksAspectRatio: Bool
        let transformQuadOffsets: TransformQuadOffsets
        let activeTextLayer: TextLayerData?
        let geometry: CanvasViewportGeometry
    }

    private enum TransformOverlayHandle {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
        case leftEdge
        case rightEdge
        case bottomEdge
    }

    private struct TextTransformGeometry {
        let sourceRect: CGRect
        let quad: TransformQuad
        let bounds: CGRect
        let center: CGPoint
        let topLeft: CGPoint
        let topRight: CGPoint
        let bottomLeft: CGPoint
        let bottomRight: CGPoint
        let topMidpoint: CGPoint
        let leftMidpoint: CGPoint
        let rightMidpoint: CGPoint
        let bottomMidpoint: CGPoint
        let rotationHandleCenter: CGPoint
        let pivotCenter: CGPoint
        let rotationStemLength: CGFloat
    }
}

private final class TransformOutlineView: UIView {
    private let fillLayer = CAShapeLayer()
    private let strokeLayer = CAShapeLayer()
    private let shadowLayer = CAShapeLayer()
    private var currentPath: UIBezierPath?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false

        shadowLayer.fillColor = UIColor.systemBlue.withAlphaComponent(0.045).cgColor
        shadowLayer.strokeColor = UIColor.clear.cgColor
        shadowLayer.shadowColor = UIColor.black.cgColor
        shadowLayer.shadowOpacity = 0.12
        shadowLayer.shadowRadius = 5
        shadowLayer.shadowOffset = CGSize(width: 0, height: 2)
        layer.addSublayer(shadowLayer)

        fillLayer.fillColor = UIColor.systemBlue.withAlphaComponent(0.045).cgColor
        fillLayer.strokeColor = UIColor.clear.cgColor
        layer.addSublayer(fillLayer)

        strokeLayer.fillColor = UIColor.clear.cgColor
        strokeLayer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.96).cgColor
        strokeLayer.lineWidth = 1.1
        strokeLayer.lineJoin = .round
        layer.addSublayer(strokeLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fillLayer.frame = bounds
        strokeLayer.frame = bounds
        shadowLayer.frame = bounds
    }

    func updatePath(_ path: UIBezierPath?) {
        currentPath = path
        let cgPath = path?.cgPath
        fillLayer.path = cgPath
        strokeLayer.path = cgPath
        shadowLayer.path = cgPath
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let currentPath else { return false }
        return currentPath.contains(point)
    }
}
