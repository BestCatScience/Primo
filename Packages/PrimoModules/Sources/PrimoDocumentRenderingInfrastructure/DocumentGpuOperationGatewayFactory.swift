import CoreGraphics
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentMetalRuntimeInfrastructure

public enum DocumentGpuOperationGatewayFactory {
    public static func live(
        renderingClient: DocumentRenderingClient = .live
    ) -> DocumentGpuOperationGateway {
        let layerMutationService = MetalLayerMutationService()
        let resourceStore = MetalResourceStore()

        return DocumentGpuOperationGateway(
            compositedPaperPreviewRGBA: { pixelData, width, height, paperStyle in
                renderingClient.compositedPaperPreviewRGBA(
                    pixelData: pixelData,
                    width: width,
                    height: height,
                    paperStyle: paperStyle
                )
            },
            compositedPreviewPixelData: { snapshot, activeLayerIndex, adjustedActiveLayerPixels in
                renderingClient.compositedPreviewPixelData(
                    snapshot: snapshot,
                    activeLayerIndex: activeLayerIndex,
                    adjustedActiveLayerPixels: adjustedActiveLayerPixels
                )
            },
            compositedPreviewIncrementalUpdate: { snapshot, activeLayerIndex, adjustedActiveLayerPixels, dirtyRect in
                renderingClient.compositedPreviewIncrementalUpdate(
                    snapshot: snapshot,
                    activeLayerIndex: activeLayerIndex,
                    adjustedActiveLayerPixels: adjustedActiveLayerPixels,
                    dirtyRect: (
                        originX: dirtyRect.originX,
                        originY: dirtyRect.originY,
                        width: dirtyRect.width,
                        height: dirtyRect.height
                    )
                )
            },
            processedLayerPixelData: { pixelData, canvasWidth, canvasHeight, request in
                renderingClient.processedLayerPixelData(
                    pixelData: pixelData,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    request: request
                )
            },
            alphaMask: { pixelData, width, height in
                renderingClient.alphaMask(pixelData: pixelData, width: width, height: height)
            },
            croppedSelectionMask: { mask, width, height in
                renderingClient.croppedSelectionMask(mask: mask, width: width, height: height)
                    .map {
                        DocumentCroppedSelectionMask(
                            bounds: $0.bounds,
                            maskData: $0.maskData,
                            maskWidth: $0.maskWidth,
                            maskHeight: $0.maskHeight
                        )
                    }
            },
            combinedSelectionMask: { base, incoming, mode, width, height in
                renderingClient.combinedSelectionMask(
                    base: base,
                    incoming: incoming,
                    mode: mode == .add ? .add : .subtract,
                    width: width,
                    height: height
                )
            },
            expandedSelectionMask: { maskData, maskWidth, maskHeight, originX, originY, canvasWidth, canvasHeight in
                renderingClient.expandedSelectionMask(
                    maskData: maskData,
                    maskWidth: maskWidth,
                    maskHeight: maskHeight,
                    originX: originX,
                    originY: originY,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight
                )
            },
            lassoSelection: { points, canvasWidth, canvasHeight in
                renderingClient.lassoSelection(points: points, canvasWidth: canvasWidth, canvasHeight: canvasHeight)
            },
            autoSelection: { pixelData, width, height, seedX, seedY, thresholdMode, opacityTolerance, colorTolerance, expansion in
                renderingClient.autoSelection(
                    pixelData: pixelData,
                    width: width,
                    height: height,
                    seedX: seedX,
                    seedY: seedY,
                    thresholdMode: thresholdMode,
                    opacityTolerance: opacityTolerance,
                    colorTolerance: colorTolerance,
                    expansion: expansion
                )
            },
            colorRangeSelection: { pixelData, width, height, request in
                renderingClient.colorRangeSelection(pixelData: pixelData, width: width, height: height, request: request)
            },
            expandedMask: { source, width, height, expansion in
                renderingClient.expandedMask(source, width: width, height: height, expansion: expansion)
            },
            contractedMask: { source, width, height, contraction in
                renderingClient.contractedMask(source, width: width, height: height, contraction: contraction)
            },
            featheredMask: { source, width, height, radius in
                renderingClient.featheredMask(source, width: width, height: height, radius: radius)
            },
            invertMask: { source in
                renderingClient.invertMask(source)
            },
            transformedSelectionMask: { mask, canvasWidth, canvasHeight, translation, scaleX, scaleY, rotationDegrees, pivot, sourceQuad, destinationQuad, usesFreeformQuad in
                renderingClient.transformedSelectionMask(
                    expandedSelectionMask: mask,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    translation: translation,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    rotationDegrees: rotationDegrees,
                    pivot: pivot,
                    sourceQuad: sourceQuad,
                    destinationQuad: destinationQuad,
                    usesFreeformQuad: usesFreeformQuad
                )
            },
            transformedLayerPixelData: { source, canvasWidth, canvasHeight, mask, translation, scaleX, scaleY, rotationDegrees, pivot, sourceQuad, destinationQuad, usesFreeformQuad in
                renderingClient.transformedLayerPixelData(
                    source: source,
                    canvasWidth: canvasWidth,
                    canvasHeight: canvasHeight,
                    expandedSelectionMask: mask,
                    translation: translation,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    rotationDegrees: rotationDegrees,
                    pivot: pivot,
                    sourceQuad: sourceQuad,
                    destinationQuad: destinationQuad,
                    usesFreeformQuad: usesFreeformQuad
                )
            },
            scaledPixelData: { source, sourceWidth, sourceHeight, targetWidth, targetHeight in
                layerMutationService.scaledPixelData(
                    source,
                    sourceWidth: sourceWidth,
                    sourceHeight: sourceHeight,
                    targetWidth: targetWidth,
                    targetHeight: targetHeight
                )
            },
            translatedPixelData: { source, sourceWidth, sourceHeight, targetWidth, targetHeight, offsetX, offsetY in
                layerMutationService.translatedPixelData(
                    source,
                    sourceWidth: sourceWidth,
                    sourceHeight: sourceHeight,
                    targetWidth: targetWidth,
                    targetHeight: targetHeight,
                    offsetX: offsetX,
                    offsetY: offsetY
                )
            },
            releaseSurfaceHandle: { handle in
                resourceStore.release(handle)
            }
        )
    }
}
