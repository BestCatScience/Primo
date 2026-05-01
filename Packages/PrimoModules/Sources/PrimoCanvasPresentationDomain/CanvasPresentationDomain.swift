import AVFoundation
import CoreGraphics
import Foundation
import PrimoCanvasInputDomain
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts

public enum CanvasPresentationAction: Sendable {
    case strokeUpdated(Stroke)
    case strokeEnded(Stroke)
    case strokeCancelled
    case fillRequested(StylusSample)
    case colorSampled(SampledColor)
    case selectionPreviewUpdated([CGPoint])
    case selectionPathEnded([CGPoint])
    case selectionMoveBegan(CGPoint)
    case selectionMoveUpdated(CGSize)
    case selectionMoveEnded(CGSize)
    case selectionMoveCancelled
    case autoSelectionRequested(StylusSample)
    case textPlacementRequested(CGPoint)
    case viewportOffsetChanged(CGSize)
    case zoomScaleChanged(CGFloat)
    case requestLocalUndo
    case requestLocalRedo
    case pencilInteractionToggleRequested
}

public struct CanvasPresentationActionSink: Sendable {
    private let sendAction: @MainActor @Sendable (CanvasPresentationAction) -> Void

    public init(_ sendAction: @escaping @MainActor @Sendable (CanvasPresentationAction) -> Void) {
        self.sendAction = sendAction
    }

    @MainActor
    public func send(_ action: CanvasPresentationAction) {
        sendAction(action)
    }
}

public struct CanvasPresentationState: Sendable {
    public var documentSize: CGSize
    public var snapshot: MetalDocumentSnapshot?
    public var activeLayerIndex: Int
    public var activeStroke: Stroke?
    public var incrementalUpdate: IncrementalLayerUpdate?
    public var adjustmentPreviewPixelData: Data?
    public var paperStyle: CanvasPaperStyle
    public var previewStyle: PreviewStrokeStyle
    public var currentTool: StudioToolKind
    public var allowsFingerTouchInput: Bool
    public var selectionMode: SelectionToolMode
    public var shapeMode: ShapeToolMode
    public var eyedropperSamplingSource: EyedropperSamplingSource
    public var selection: CanvasSelection?
    public var selectionPreviewPoints: [CGPoint]
    public var selectionMoveOffset: CGSize
    public var activeTextLayer: TextLayerData?
    public var viewportOffset: CGSize
    public var zoomScale: CGFloat
    public var previewResetNonce: Int

    public init(
        documentSize: CGSize,
        snapshot: MetalDocumentSnapshot?,
        activeLayerIndex: Int,
        activeStroke: Stroke?,
        incrementalUpdate: IncrementalLayerUpdate?,
        adjustmentPreviewPixelData: Data?,
        paperStyle: CanvasPaperStyle,
        previewStyle: PreviewStrokeStyle,
        currentTool: StudioToolKind,
        allowsFingerTouchInput: Bool = false,
        selectionMode: SelectionToolMode,
        shapeMode: ShapeToolMode,
        eyedropperSamplingSource: EyedropperSamplingSource,
        selection: CanvasSelection?,
        selectionPreviewPoints: [CGPoint],
        selectionMoveOffset: CGSize = .zero,
        activeTextLayer: TextLayerData?,
        viewportOffset: CGSize,
        zoomScale: CGFloat,
        previewResetNonce: Int
    ) {
        self.documentSize = documentSize
        self.snapshot = snapshot
        self.activeLayerIndex = activeLayerIndex
        self.activeStroke = activeStroke
        self.incrementalUpdate = incrementalUpdate
        self.adjustmentPreviewPixelData = adjustmentPreviewPixelData
        self.paperStyle = paperStyle
        self.previewStyle = previewStyle
        self.currentTool = currentTool
        self.allowsFingerTouchInput = allowsFingerTouchInput
        self.selectionMode = selectionMode
        self.shapeMode = shapeMode
        self.eyedropperSamplingSource = eyedropperSamplingSource
        self.selection = selection
        self.selectionPreviewPoints = selectionPreviewPoints
        self.selectionMoveOffset = selectionMoveOffset
        self.activeTextLayer = activeTextLayer
        self.viewportOffset = viewportOffset
        self.zoomScale = zoomScale
        self.previewResetNonce = previewResetNonce
    }
}

public struct CanvasPresentationEnvironment: Sendable {
    public var previewRenderer: any CanvasPreviewRendering
    public var eyedropperSampler: any CanvasEyedropperSampling
    public var selectionProcessor: any SelectionMaskProcessing

    public init(
        previewRenderer: any CanvasPreviewRendering,
        eyedropperSampler: any CanvasEyedropperSampling,
        selectionProcessor: any SelectionMaskProcessing
    ) {
        self.previewRenderer = previewRenderer
        self.eyedropperSampler = eyedropperSampler
        self.selectionProcessor = selectionProcessor
    }
}

public struct CanvasViewportGeometry: Sendable, Equatable {
    public var bounds: CGRect
    public var documentSize: CGSize
    public var viewportOffset: CGSize
    public var zoomScale: CGFloat

    public init(bounds: CGRect, documentSize: CGSize, viewportOffset: CGSize, zoomScale: CGFloat) {
        self.bounds = bounds
        self.documentSize = documentSize
        self.viewportOffset = viewportOffset
        self.zoomScale = zoomScale
    }

    public var contentRect: CGRect {
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        guard documentSize.width > 0, documentSize.height > 0 else { return .zero }
        let fitted = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledSize = CGSize(width: fitted.width * zoomScale, height: fitted.height * zoomScale)
        return CGRect(
            x: fitted.midX - (scaledSize.width / 2) + viewportOffset.width,
            y: fitted.midY - (scaledSize.height / 2) + viewportOffset.height,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }

    public func documentPoint(fromViewPoint viewPoint: CGPoint) -> CGPoint {
        let rect = contentRect
        return CGPoint(
            x: ((viewPoint.x - rect.minX) / max(rect.width, 1)) * documentSize.width,
            y: ((viewPoint.y - rect.minY) / max(rect.height, 1)) * documentSize.height
        )
    }

    public func viewPoint(fromDocumentPoint point: CGPoint) -> CGPoint {
        let rect = contentRect
        guard rect.width > 0, rect.height > 0, documentSize.width > 0, documentSize.height > 0 else {
            return .zero
        }
        return CGPoint(
            x: rect.minX + ((point.x / documentSize.width) * rect.width),
            y: rect.minY + ((point.y / documentSize.height) * rect.height)
        )
    }

    public func viewRect(forDocumentRect rect: CGRect) -> CGRect {
        guard contentRect.width > 0, contentRect.height > 0, documentSize.width > 0, documentSize.height > 0 else {
            return .zero
        }
        let minPoint = viewPoint(fromDocumentPoint: rect.origin)
        let maxPoint = viewPoint(fromDocumentPoint: CGPoint(x: rect.maxX, y: rect.maxY))
        return CGRect(
            x: minPoint.x,
            y: minPoint.y,
            width: max(1, maxPoint.x - minPoint.x),
            height: max(1, maxPoint.y - minPoint.y)
        )
    }

    public func documentTranslation(from viewTranslation: CGPoint) -> CGSize {
        let rect = contentRect
        guard rect.width > 0, rect.height > 0 else { return .zero }
        return CGSize(
            width: (viewTranslation.x / rect.width) * documentSize.width,
            height: (viewTranslation.y / rect.height) * documentSize.height
        )
    }

    public func clampedViewportOffset(_ proposedOffset: CGSize, zoomScale overrideZoomScale: CGFloat? = nil) -> CGSize {
        let resolvedZoomScale = overrideZoomScale ?? zoomScale
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        guard documentSize.width > 0, documentSize.height > 0 else { return .zero }
        let fitted = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledWidth = fitted.width * resolvedZoomScale
        let scaledHeight = fitted.height * resolvedZoomScale
        let horizontalLimit = max(0, (scaledWidth - drawableRect.width) / 2 + 120)
        let verticalLimit = max(0, (scaledHeight - drawableRect.height) / 2 + 120)
        return CGSize(
            width: min(max(proposedOffset.width, -horizontalLimit), horizontalLimit),
            height: min(max(proposedOffset.height, -verticalLimit), verticalLimit)
        )
    }

    public func offsetKeepingDocumentPointStable(
        _ documentPoint: CGPoint,
        at viewPoint: CGPoint,
        zoomScale newZoomScale: CGFloat
    ) -> CGSize {
        let paperRect = bounds.insetBy(dx: 6, dy: 6)
        let drawableRect = paperRect.insetBy(dx: 8, dy: 8)
        guard documentSize.width > 0, documentSize.height > 0 else { return .zero }
        let fittedRect = AVMakeRect(aspectRatio: documentSize, insideRect: drawableRect)
        let scaledSize = CGSize(width: fittedRect.width * newZoomScale, height: fittedRect.height * newZoomScale)
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
            zoomScale: newZoomScale
        )
    }
}

public protocol CanvasPreviewRendering: Sendable {
    func eyedropperLoupeSurface(
        sourcePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        gridSize: Int,
        paperStyle: CanvasPaperStyle,
        blendWithPaper: Bool
    ) -> DocumentCompositeSurface?
    func selectionOverlaySurface(maskData: Data, width: Int, height: Int) -> DocumentCompositeSurface?
    func compositePreviewImageData(snapshot: MetalDocumentSnapshot, activeLayerIndex: Int, adjustedActiveLayerPixels: Data) -> Data?
    func paperCompositeSurface(pixelData: Data, width: Int, height: Int, paperStyle: CanvasPaperStyle) -> DocumentCompositeSurface?
    func shapePreviewSurface(stroke: Stroke, style: PreviewStrokeStyle, canvasWidth: Int, canvasHeight: Int) -> DocumentCompositeSurface?
    func transformedTextPreviewSurface(textLayer: TextLayerData, canvasWidth: Int, canvasHeight: Int) -> DocumentCompositeSurface?
    func transformedTextLayoutRect(textLayer: TextLayerData, canvasSize: CGSize) -> CGRect?
}

public protocol CanvasEyedropperSampling: Sendable {
    func sampledColor(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        source: EyedropperSamplingSource,
        point: CGPoint,
        paperStyle: CanvasPaperStyle
    ) -> SampledColor?
}

public protocol SelectionMaskProcessing: Sendable {
    func selectionOverlaySurface(maskData: Data, width: Int, height: Int) -> DocumentCompositeSurface?
}

public protocol LayerTransformProcessing: Sendable {
    func transformedLayerPixels(
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
    ) -> Data?

    func transformedSelection(
        _ selection: CanvasSelection?,
        translation: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat,
        rotationDegrees: Double,
        pivot: CGPoint?,
        mode: CanvasTransformMode,
        quadOffsets: TransformQuadOffsets,
        canvasSize: CGSize
    ) -> CanvasSelection?

    func transformationBounds(
        selection: CanvasSelection?,
        pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> CGRect?
}

public enum CanvasTransformGeometry {
    public static func affineTransformedPoint(
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

    public static func affineTransformQuad(
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

    public static func effectiveTransformQuad(
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
}
