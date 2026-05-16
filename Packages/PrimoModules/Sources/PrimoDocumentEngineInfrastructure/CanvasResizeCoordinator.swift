import Foundation
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentStrokeInfrastructure

struct RuntimeResizeCanvasPlan: Sendable {
    enum Mode: Sendable {
        case scale
        case extent
    }

    let mode: Mode
    let documentGeneration: UUID
    let before: SwiftDocumentStoreSnapshot
    let sourceWidth: Int
    let sourceHeight: Int
    let targetWidth: Int
    let targetHeight: Int
    let layers: [SwiftDocumentLayerRecord]
    let gpuServices: DocumentRuntimeGpuServices

    func resizedLayers() -> [SwiftDocumentLayerRecord]? {
        switch mode {
        case .scale:
            return scaledLayers()
        case .extent:
            return extentAdjustedLayers()
        }
    }

    private func scaledLayers() -> [SwiftDocumentLayerRecord]? {
        guard let targetGeometry = PixelGeometry(width: targetWidth, height: targetHeight) else {
            return nil
        }
        let widthScale = Double(targetWidth) / Double(sourceWidth)
        let heightScale = Double(targetHeight) / Double(sourceHeight)
        let textScale = min(widthScale, heightScale)
        var output: [SwiftDocumentLayerRecord] = []
        output.reserveCapacity(layers.count)
        for var layer in layers {
            guard let scaled = gpuServices.scaledPixelData(
                layer.pixelData,
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                targetWidth: targetWidth,
                targetHeight: targetHeight
            ) else {
                return nil
            }
            guard layer.replacePixelData(scaled, geometry: targetGeometry) else {
                return nil
            }
            if let mask = layer.maskData {
                guard let scaledMask = gpuServices.scaledMaskData(
                    mask,
                    sourceWidth: sourceWidth,
                    sourceHeight: sourceHeight,
                    targetWidth: targetWidth,
                    targetHeight: targetHeight
                ) else {
                    return nil
                }
                guard layer.replaceMaskData(scaledMask, geometry: targetGeometry) else {
                    return nil
                }
            }
            if let textLayer = layer.textLayer {
                layer.textLayer = TextLayerData(
                    validatingText: textLayer.text,
                    positionX: textLayer.positionX * widthScale,
                    positionY: textLayer.positionY * heightScale,
                    fontPostScriptName: textLayer.fontPostScriptName,
                    fontDisplayName: textLayer.fontDisplayName,
                    fontSize: max(1, textLayer.fontSize * textScale),
                    scale: textLayer.scale,
                    rotationDegrees: textLayer.rotationDegrees,
                    red: textLayer.red,
                    green: textLayer.green,
                    blue: textLayer.blue,
                    alpha: textLayer.alpha
                )
            }
            output.append(layer)
        }
        return output
    }

    private func extentAdjustedLayers() -> [SwiftDocumentLayerRecord]? {
        guard let targetGeometry = PixelGeometry(width: targetWidth, height: targetHeight) else {
            return nil
        }
        let offsetX = (targetWidth - sourceWidth) / 2
        let offsetY = (targetHeight - sourceHeight) / 2
        var output: [SwiftDocumentLayerRecord] = []
        output.reserveCapacity(layers.count)
        for var layer in layers {
            guard let translated = gpuServices.translatedPixelData(
                layer.pixelData,
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                targetWidth: targetWidth,
                targetHeight: targetHeight,
                offsetX: offsetX,
                offsetY: offsetY
            ) else {
                return nil
            }
            guard layer.replacePixelData(translated, geometry: targetGeometry) else {
                return nil
            }
            if let mask = layer.maskData {
                guard let translatedMask = gpuServices.translatedMaskData(
                    mask,
                    sourceWidth: sourceWidth,
                    sourceHeight: sourceHeight,
                    targetWidth: targetWidth,
                    targetHeight: targetHeight,
                    offsetX: offsetX,
                    offsetY: offsetY
                ) else {
                    return nil
                }
                guard layer.replaceMaskData(translatedMask, geometry: targetGeometry) else {
                    return nil
                }
            }
            if let textLayer = layer.textLayer {
                layer.textLayer = TextLayerData(
                    validatingText: textLayer.text,
                    positionX: textLayer.positionX + Double(offsetX),
                    positionY: textLayer.positionY + Double(offsetY),
                    fontPostScriptName: textLayer.fontPostScriptName,
                    fontDisplayName: textLayer.fontDisplayName,
                    fontSize: textLayer.fontSize,
                    scale: textLayer.scale,
                    rotationDegrees: textLayer.rotationDegrees,
                    red: textLayer.red,
                    green: textLayer.green,
                    blue: textLayer.blue,
                    alpha: textLayer.alpha
                )
            }
            output.append(layer)
        }
        return output
    }
}

enum CanvasResizeCoordinator {
    static func makeResizeCanvasPlan(
        width: Int,
        height: Int,
        mode: RuntimeResizeCanvasPlan.Mode,
        snapshot: SwiftDocumentStoreSnapshot,
        beforeSnapshot: () -> SwiftDocumentStoreSnapshot,
        documentGeneration: UUID,
        gpuServices: DocumentRuntimeGpuServices
    ) -> Result<RuntimeResizeCanvasPlan?, DocumentMutationFailure> {
        guard width > 0 && height > 0 else {
            return .failure(.invalidCanvasSize(width: width, height: height))
        }
        let sourceSize = PaintDocumentCanvasSize(width: snapshot.canvasWidth, height: snapshot.canvasHeight)
        let targetSize = PaintDocumentCanvasSize(width: width, height: height)
        guard sourceSize != targetSize else { return .success(nil) }
        let before = beforeSnapshot()
        return .success(
            RuntimeResizeCanvasPlan(
                mode: mode,
                documentGeneration: documentGeneration,
                before: before,
                sourceWidth: sourceSize.width,
                sourceHeight: sourceSize.height,
                targetWidth: targetSize.width,
                targetHeight: targetSize.height,
                layers: before.layers,
                gpuServices: gpuServices
            )
        )
    }

    static func applyResizeCanvasPlan(
        _ plan: RuntimeResizeCanvasPlan,
        layers: [SwiftDocumentLayerRecord],
        documentGeneration: UUID,
        store: SwiftDocumentStore
    ) -> DocumentMutationResult {
        guard store.snapshot.revision == plan.before.revision,
              documentGeneration == plan.documentGeneration,
              store.snapshot.canvasWidth == plan.sourceWidth,
              store.snapshot.canvasHeight == plan.sourceHeight,
              store.snapshot.layers.count == plan.before.layers.count,
              layers.count == plan.before.layers.count else {
            return .failure(.gpu(.staleSnapshot(operation: "resizeCanvas")))
        }
        guard let resizedSnapshot = SwiftDocumentStoreSnapshot(
            canvasWidth: plan.targetWidth,
            canvasHeight: plan.targetHeight,
            activeLayerIndex: store.snapshot.activeLayerIndex,
            paperStyle: store.snapshot.paperStyle,
            revision: store.snapshot.revision,
            nextFolderID: store.snapshot.nextFolderID,
            layers: layers,
            folders: store.snapshot.folders,
            thumbnailCache: store.snapshot.thumbnailCache,
            timelapseFrames: store.snapshot.timelapseFrames,
            timelapseEvents: store.snapshot.timelapseEvents,
            timelapseUsesOperationPersistence: store.snapshot.timelapseUsesOperationPersistence
        ) else {
            return .failure(.inconsistentComposition(operation: "resizeCanvas", reason: "invalid snapshot"))
        }
        guard store.update({
            $0 = resizedSnapshot
            $0.thumbnailCache.removeAll()
            return true
        }) else {
            return .failure(.inconsistentComposition(operation: "resizeCanvas", reason: "invalid snapshot"))
        }
        return .success(())
    }
}
