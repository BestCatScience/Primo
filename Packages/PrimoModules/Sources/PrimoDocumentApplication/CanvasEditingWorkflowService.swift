import CoreGraphics
import Foundation
import PrimoCanvasPresentationDomain
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts

public enum CanvasEditingCommand: Equatable, Sendable {
    case applyTransform
}

public struct CanvasEditingContext: Sendable {
    public let transformHasPreview: Bool
    public let transformPreviewOffset: CGSize
    public let transformPreviewScaleX: CGFloat
    public let transformPreviewScaleY: CGFloat
    public let transformPreviewRotationDegrees: Double
    public let transformMode: CanvasTransformMode
    public let transformPivot: CGPoint?
    public let transformQuadOffsets: TransformQuadOffsets
    public let activeLayerIndex: Int
    public let activeTextLayer: TextLayerData?
    public let selection: CanvasSelection?
    public let canvasGeometry: PixelGeometry

    public init(
        transformHasPreview: Bool,
        transformPreviewOffset: CGSize,
        transformPreviewScaleX: CGFloat,
        transformPreviewScaleY: CGFloat,
        transformPreviewRotationDegrees: Double,
        transformMode: CanvasTransformMode,
        transformPivot: CGPoint?,
        transformQuadOffsets: TransformQuadOffsets,
        activeLayerIndex: Int,
        activeTextLayer: TextLayerData?,
        selection: CanvasSelection?,
        canvasGeometry: PixelGeometry
    ) {
        self.transformHasPreview = transformHasPreview
        self.transformPreviewOffset = transformPreviewOffset
        self.transformPreviewScaleX = transformPreviewScaleX
        self.transformPreviewScaleY = transformPreviewScaleY
        self.transformPreviewRotationDegrees = transformPreviewRotationDegrees
        self.transformMode = transformMode
        self.transformPivot = transformPivot
        self.transformQuadOffsets = transformQuadOffsets
        self.activeLayerIndex = activeLayerIndex
        self.activeTextLayer = activeTextLayer
        self.selection = selection
        self.canvasGeometry = canvasGeometry
    }
}

public enum CanvasEditingOutcome: Equatable, Sendable {
    case noPreview
    case resetTransformPreview
    case appliedTextTransform
    case appliedPixelTransform(layerIndex: Int, selection: CanvasSelection?)
    case failure(DocumentMutationFailure)
}

public struct CanvasEditingWorkflowService: Sendable {
    package let documentContentService: DocumentContentService
    package let layerTransformProcessor: any LayerTransformProcessing

    public init(
        documentContentService: DocumentContentService,
        layerTransformProcessor: any LayerTransformProcessing
    ) {
        self.documentContentService = documentContentService
        self.layerTransformProcessor = layerTransformProcessor
    }

    public func execute(
        _ command: CanvasEditingCommand,
        state context: CanvasEditingContext
    ) -> CanvasEditingOutcome {
        switch command {
        case .applyTransform:
            return applyTransform(in: context)
        }
    }

    private func applyTransform(in context: CanvasEditingContext) -> CanvasEditingOutcome {
        guard context.transformHasPreview else { return .noPreview }
        let translation = CGSize(
            width: context.transformPreviewOffset.width.rounded(),
            height: context.transformPreviewOffset.height.rounded()
        )

        if context.selection == nil,
           let textLayer = context.activeTextLayer {
            guard let scaleFactor = PositiveFiniteDouble(Double((context.transformPreviewScaleX + context.transformPreviewScaleY) * 0.5)),
                  let rotationDeltaDegrees = FiniteDouble(context.transformPreviewRotationDegrees) else {
                return .resetTransformPreview
            }
            guard let transformedTextLayer = textLayer.transformed(
                translation: translation,
                scaleFactor: scaleFactor,
                rotationDeltaDegrees: rotationDeltaDegrees
            ) else {
                return .resetTransformPreview
            }
            switch documentContentService.setTextLayer(context.activeLayerIndex, transformedTextLayer) {
            case .success:
                return .appliedTextTransform
            case let .failure(failure):
                return .failure(failure)
            }
        }

        let source: Data
        switch documentContentService.pixelDataForLayer(context.activeLayerIndex) {
        case let .success(pixelData):
            source = pixelData
        case let .failure(failure):
            return .failure(failure)
        }
        let canvasWidth = context.canvasGeometry.width
        let canvasHeight = context.canvasGeometry.height
        guard let sourceSurface = RgbaSurface(width: canvasWidth, height: canvasHeight, data: source) else {
            return .resetTransformPreview
        }
        guard let transformed = layerTransformProcessor.transformedLayerPixels(
            source: sourceSurface,
            selection: context.selection,
            translation: translation,
            scaleX: context.transformPreviewScaleX,
            scaleY: context.transformPreviewScaleY,
            rotationDegrees: context.transformPreviewRotationDegrees,
            pivot: context.transformPivot,
            mode: context.transformMode,
            quadOffsets: context.transformQuadOffsets
        ) else {
            return .resetTransformPreview
        }

        let transformedSelection = layerTransformProcessor.transformedSelection(
            context.selection,
            translation: translation,
            scaleX: context.transformPreviewScaleX,
            scaleY: context.transformPreviewScaleY,
            rotationDegrees: context.transformPreviewRotationDegrees,
            pivot: context.transformPivot,
            mode: context.transformMode,
            quadOffsets: context.transformQuadOffsets,
            canvasGeometry: context.canvasGeometry
        )

        switch documentContentService.replaceLayerPixels(context.activeLayerIndex, transformed) {
        case .success:
            return .appliedPixelTransform(
                layerIndex: context.activeLayerIndex,
                selection: transformedSelection
            )
        case let .failure(failure):
            return .failure(failure)
        }
    }
}
