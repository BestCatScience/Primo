#if canImport(UIKit)
import PrimoCanvasPresentationDomain
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain
import UIKit

final class CanvasTransformPreviewView: UIView {
    private let compositePreviewSurfaceView = CanvasPixelSurfaceView()
    private let shapePreviewSurfaceView = CanvasPixelSurfaceView()
    private let previewRenderer: any CanvasPreviewRendering
    private let layerTransformProcessor: any LayerTransformProcessing

    init(
        previewRenderer: any CanvasPreviewRendering,
        layerTransformProcessor: any LayerTransformProcessing
    ) {
        self.previewRenderer = previewRenderer
        self.layerTransformProcessor = layerTransformProcessor
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        compositePreviewSurfaceView.alpha = 1.0
        compositePreviewSurfaceView.isHidden = true
        addSubview(compositePreviewSurfaceView)
        shapePreviewSurfaceView.alpha = 1.0
        shapePreviewSurfaceView.isHidden = true
        addSubview(shapePreviewSurfaceView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        snapshot: MetalDocumentSnapshot?,
        activeLayerIndex: Int,
        activeStroke: Stroke?,
        strokePreviewCompositePixelData: Data?,
        adjustmentPreviewPixelData: Data?,
        selection: CanvasSelection?,
        paperStyle: CanvasPaperStyle,
        previewStyle: PreviewStrokeStyle,
        currentTool: StudioToolKind,
        transformPreviewOffset: CGSize,
        transformPreviewScaleX: CGFloat,
        transformPreviewScaleY: CGFloat,
        transformPreviewRotationDegrees: Double,
        transformPivot: CGPoint?,
        transformMode: CanvasTransformMode,
        transformQuadOffsets: TransformQuadOffsets,
        activeTextLayer: TextLayerData?,
        geometry viewport: CanvasViewportGeometry,
        renderSurfaceView: CanvasRenderSurfaceView
    ) {
        frame = viewport.bounds
        updateStrokePreview(
            activeStroke,
            style: previewStyle,
            currentTool: currentTool,
            snapshot: snapshot,
            geometry: viewport
        )
        updateTransformPreview(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            strokePreviewCompositePixelData: strokePreviewCompositePixelData,
            adjustmentPreviewPixelData: adjustmentPreviewPixelData,
            selection: selection,
            paperStyle: paperStyle,
            currentTool: currentTool,
            transformPreviewOffset: transformPreviewOffset,
            transformPreviewScaleX: transformPreviewScaleX,
            transformPreviewScaleY: transformPreviewScaleY,
            transformPreviewRotationDegrees: transformPreviewRotationDegrees,
            transformPivot: transformPivot,
            transformMode: transformMode,
            transformQuadOffsets: transformQuadOffsets,
            activeTextLayer: activeTextLayer,
            geometry: viewport,
            renderSurfaceView: renderSurfaceView
        )
    }

    private func updateStrokePreview(
        _ stroke: Stroke?,
        style: PreviewStrokeStyle,
        currentTool: StudioToolKind,
        snapshot: MetalDocumentSnapshot?,
        geometry viewport: CanvasViewportGeometry
    ) {
        guard let stroke, currentTool == .shape, stroke.points.count >= 2 else {
            shapePreviewSurfaceView.update(surface: nil)
            return
        }
        guard let snapshot,
              let surface = previewRenderer.shapePreviewSurface(
                stroke: stroke,
                style: style,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height
              ) else {
            shapePreviewSurfaceView.update(surface: nil)
            return
        }
        shapePreviewSurfaceView.update(surface: surface)
        shapePreviewSurfaceView.frame = viewport.contentRect
    }

    private func updateTransformPreview(
        snapshot: MetalDocumentSnapshot?,
        activeLayerIndex: Int,
        strokePreviewCompositePixelData: Data?,
        adjustmentPreviewPixelData: Data?,
        selection: CanvasSelection?,
        paperStyle: CanvasPaperStyle,
        currentTool: StudioToolKind,
        transformPreviewOffset: CGSize,
        transformPreviewScaleX: CGFloat,
        transformPreviewScaleY: CGFloat,
        transformPreviewRotationDegrees: Double,
        transformPivot: CGPoint?,
        transformMode: CanvasTransformMode,
        transformQuadOffsets: TransformQuadOffsets,
        activeTextLayer: TextLayerData?,
        geometry viewport: CanvasViewportGeometry,
        renderSurfaceView: CanvasRenderSurfaceView
    ) {
        guard
            currentTool == .move,
            transformPreviewOffset != .zero ||
            abs(transformPreviewScaleX - 1.0) > 0.001 ||
            abs(transformPreviewScaleY - 1.0) > 0.001 ||
            abs(transformPreviewRotationDegrees) > 0.001 ||
            !transformQuadOffsets.isZero,
            let snapshot
        else {
            if
                let snapshot,
                let strokePreviewCompositePixelData,
                let surface = previewRenderer.paperCompositeSurface(
                    pixelData: strokePreviewCompositePixelData,
                    width: snapshot.width,
                    height: snapshot.height,
                    paperStyle: paperStyle
                )
            {
                compositePreviewSurfaceView.update(surface: surface)
                compositePreviewSurfaceView.frame = viewport.contentRect
                renderSurfaceView.isHidden = true
                return
            }

            if
                let snapshot,
                let adjustmentPreviewPixelData,
                let surface = previewRenderer.paperCompositeSurface(
                    pixelData: adjustmentPreviewPixelData,
                    width: snapshot.width,
                    height: snapshot.height,
                    paperStyle: paperStyle
                )
            {
                compositePreviewSurfaceView.update(surface: surface)
                compositePreviewSurfaceView.frame = viewport.contentRect
                renderSurfaceView.isHidden = true
                return
            }

            compositePreviewSurfaceView.update(surface: nil)
            compositePreviewSurfaceView.frame = .zero
            renderSurfaceView.isHidden = false
            return
        }

        guard let surface = makeCompositePreviewSurface(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            selection: selection,
            paperStyle: paperStyle,
            transformPreviewOffset: transformPreviewOffset,
            transformPreviewScaleX: transformPreviewScaleX,
            transformPreviewScaleY: transformPreviewScaleY,
            transformPreviewRotationDegrees: transformPreviewRotationDegrees,
            transformPivot: transformPivot,
            transformMode: transformMode,
            transformQuadOffsets: transformQuadOffsets,
            activeTextLayer: activeTextLayer
        ) else {
            compositePreviewSurfaceView.update(surface: nil)
            compositePreviewSurfaceView.frame = .zero
            renderSurfaceView.isHidden = false
            return
        }

        compositePreviewSurfaceView.update(surface: surface)
        compositePreviewSurfaceView.frame = viewport.contentRect
        renderSurfaceView.isHidden = true
    }

    private func makeCompositePreviewSurface(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        selection: CanvasSelection?,
        paperStyle: CanvasPaperStyle,
        transformPreviewOffset: CGSize,
        transformPreviewScaleX: CGFloat,
        transformPreviewScaleY: CGFloat,
        transformPreviewRotationDegrees: Double,
        transformPivot: CGPoint?,
        transformMode: CanvasTransformMode,
        transformQuadOffsets: TransformQuadOffsets,
        activeTextLayer: TextLayerData?
    ) -> DocumentCompositeSurface? {
        guard let activeLayer = snapshot.layers.first(where: { $0.index == activeLayerIndex }) else {
            return nil
        }

        let transformedLayerData: Data?
        if let activeTextLayer, selection == nil {
            transformedLayerData = makeTransformedTextLayerPreview(
                textLayer: activeTextLayer,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height,
                transformPreviewOffset: transformPreviewOffset,
                transformPreviewScaleX: transformPreviewScaleX,
                transformPreviewScaleY: transformPreviewScaleY,
                transformPreviewRotationDegrees: transformPreviewRotationDegrees
            )
        } else {
            transformedLayerData = layerTransformProcessor.transformedLayerPixels(
                source: activeLayer.pixelData,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height,
                selection: selection,
                translation: transformPreviewOffset,
                scaleX: transformPreviewScaleX,
                scaleY: transformPreviewScaleY,
                rotationDegrees: transformPreviewRotationDegrees,
                pivot: transformPivot,
                mode: .freeform,
                quadOffsets: activeTextLayer == nil ? transformQuadOffsets : .zero
            ) ?? activeLayer.pixelData
        }
        guard let transformedLayerData else { return nil }

        guard let composite = previewRenderer.compositePreviewImageData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: transformedLayerData
        ) else { return nil }

        return previewRenderer.paperCompositeSurface(
            pixelData: composite,
            width: snapshot.width,
            height: snapshot.height,
            paperStyle: paperStyle
        )
    }

    private func makeTransformedTextLayerPreview(
        textLayer: TextLayerData,
        canvasWidth: Int,
        canvasHeight: Int,
        transformPreviewOffset: CGSize,
        transformPreviewScaleX: CGFloat,
        transformPreviewScaleY: CGFloat,
        transformPreviewRotationDegrees: Double
    ) -> Data? {
        var transformed = textLayer
        transformed.position = CGPoint(
            x: transformed.position.x + transformPreviewOffset.width,
            y: transformed.position.y + transformPreviewOffset.height
        )
        transformed.scale = min(max(transformed.scale * Double((transformPreviewScaleX + transformPreviewScaleY) * 0.5), 0.2), 6.0)
        transformed.rotationDegrees += transformPreviewRotationDegrees
        return previewRenderer.transformedTextPreviewSurface(
            textLayer: transformed,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )?.pixelData
    }

}
#endif
