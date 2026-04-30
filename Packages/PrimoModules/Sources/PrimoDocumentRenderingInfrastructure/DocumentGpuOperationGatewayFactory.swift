import Foundation
import PrimoDocumentRenderingContracts

public enum DocumentGpuOperationGatewayFactory {
    public static func live() -> DocumentGpuOperationGateway {
        gateway(backend: MetalDocumentGpuOperationBackendFactory.live())
    }

    static func gateway(backend: DocumentGpuOperationBackend) -> DocumentGpuOperationGateway {
        DocumentGpuOperationGateway(
            compositedPaperPreviewRGBA: { pixelData, width, height, paperStyle in
                renderingResult(
                    backend.compositedPaperPreviewRGBA(pixelData, width, height, paperStyle),
                    operation: "compositedPaperPreviewRGBA"
                )
            },
            compositedPreviewPixelData: { snapshot, activeLayerIndex, adjustedActiveLayerPixels in
                renderingResult(
                    backend.compositedPreviewPixelData(snapshot, activeLayerIndex, adjustedActiveLayerPixels),
                    operation: "compositedPreviewPixelData"
                )
            },
            compositedPreviewIncrementalUpdate: { snapshot, activeLayerIndex, adjustedActiveLayerPixels, dirtyRect in
                renderingResult(
                    backend.compositedPreviewIncrementalUpdate(snapshot, activeLayerIndex, adjustedActiveLayerPixels, dirtyRect),
                    operation: "compositedPreviewIncrementalUpdate"
                )
            },
            selectionOverlayRGBA: { maskData, width, height in
                renderingResult(backend.selectionOverlayRGBA(maskData, width, height), operation: "selectionOverlayRGBA")
            },
            eyedropperLoupeRGBA: { sourcePixelData, canvasWidth, canvasHeight, centerX, centerY, gridSize, paperStyle, blendWithPaper in
                renderingResult(
                    backend.eyedropperLoupeRGBA(
                        sourcePixelData,
                        canvasWidth,
                        canvasHeight,
                        centerX,
                        centerY,
                        gridSize,
                        paperStyle,
                        blendWithPaper
                    ),
                    operation: "eyedropperLoupeRGBA"
                )
            },
            shapePreviewSurface: { samples, brush, canvasWidth, canvasHeight in
                renderingResult(
                    backend.shapePreviewSurface(samples, brush, canvasWidth, canvasHeight),
                    operation: "shapePreviewSurface"
                )
            },
            textLayerSurface: { textLayer, canvasSize in
                renderingResult(backend.textLayerSurface(textLayer, canvasSize), operation: "textLayerSurface")
            },
            textLayoutRect: backend.textLayoutRect,
            processedLayerPixelData: { pixelData, width, height, request in
                renderingResult(
                    backend.processedLayerPixelData(pixelData, width, height, request),
                    operation: "processedLayerPixelData"
                )
            },
            alphaMask: { pixelData, width, height in
                renderingResult(backend.alphaMask(pixelData, width, height), operation: "alphaMask")
            },
            croppedSelectionMask: backend.croppedSelectionMask,
            combinedSelectionMask: { base, incoming, mode, width, height in
                renderingResult(
                    backend.combinedSelectionMask(base, incoming, mode, width, height),
                    operation: "combinedSelectionMask"
                )
            },
            expandedSelectionMask: { request in
                renderingResult(backend.expandedSelectionMask(request), operation: "expandedSelectionMask")
            },
            lassoSelection: { points, width, height in
                renderingResult(backend.lassoSelection(points, width, height), operation: "lassoSelection")
            },
            autoSelection: { pixelData, width, height, seedX, seedY, thresholdMode, opacityTolerance, colorTolerance, expansion in
                renderingResult(
                    backend.autoSelection(
                        pixelData,
                        width,
                        height,
                        seedX,
                        seedY,
                        thresholdMode,
                        opacityTolerance,
                        colorTolerance,
                        expansion
                    ),
                    operation: "autoSelection"
                )
            },
            colorRangeSelection: { pixelData, width, height, request in
                renderingResult(
                    backend.colorRangeSelection(pixelData, width, height, request),
                    operation: "colorRangeSelection"
                )
            },
            expandedMask: { mask, width, height, expansion in
                renderingResult(backend.expandedMask(mask, width, height, expansion), operation: "expandedMask")
            },
            contractedMask: { mask, width, height, contraction in
                renderingResult(backend.contractedMask(mask, width, height, contraction), operation: "contractedMask")
            },
            featheredMask: { mask, width, height, radius in
                renderingResult(backend.featheredMask(mask, width, height, radius), operation: "featheredMask")
            },
            invertMask: { mask in
                renderingResult(backend.invertMask(mask), operation: "invertMask")
            },
            transformedSelectionMask: { request in
                renderingResult(backend.transformedSelectionMask(request), operation: "transformedSelectionMask")
            },
            transformedLayerPixelData: { request in
                renderingResult(backend.transformedLayerPixelData(request), operation: "transformedLayerPixelData")
            },
            scaledPixelData: { source, sourceWidth, sourceHeight, targetWidth, targetHeight in
                renderingResult(
                    backend.scaledPixelData(source, sourceWidth, sourceHeight, targetWidth, targetHeight),
                    operation: "scaledPixelData"
                )
            },
            translatedPixelData: { source, sourceWidth, sourceHeight, targetWidth, targetHeight, offsetX, offsetY in
                renderingResult(
                    backend.translatedPixelData(source, sourceWidth, sourceHeight, targetWidth, targetHeight, offsetX, offsetY),
                    operation: "translatedPixelData"
                )
            },
            releaseSurfaceHandle: backend.releaseSurfaceHandle
        )
    }

    private static func renderingResult<Value>(_ value: Value?, operation: String) -> DocumentRenderingResult<Value> {
        value.map(DocumentRenderingResult.success) ?? .failure(.kernelFailed(operation: operation))
    }
}
