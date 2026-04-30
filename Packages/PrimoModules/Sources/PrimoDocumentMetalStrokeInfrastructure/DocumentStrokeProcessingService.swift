import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentGPUContracts
import PrimoDocumentMetalRuntimeInfrastructure

public struct DocumentStrokeProcessingService: Sendable {
    public let strokeService: GpuStrokeRenderingService
    public let compositingService: GpuLayerCompositingService
    public let materializationService: GpuSurfaceMaterializationService

    public init(
        strokeService: GpuStrokeRenderingService = GpuStrokeRenderingService(),
        compositingService: GpuLayerCompositingService = GpuLayerCompositingService(),
        materializationService: GpuSurfaceMaterializationService = GpuSurfaceMaterializationService()
    ) {
        self.strokeService = strokeService
        self.compositingService = compositingService
        self.materializationService = materializationService
    }

    public func resetInteractiveStrokeState() {
        strokeService.resetExecutionSession()
    }

    public func materializedPixelData(for handle: MetalBufferHandle) -> Data? {
        materializationService.materializedPixelData(for: handle)
    }

    public func makePreviewSurface(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        basePixelData: Data,
        baseBufferHandle: MetalBufferHandle? = nil,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool,
        usesResponsivePreview: Bool = false
    ) -> StrokePreviewResult? {
        guard let preview = makeInteractiveStrokePreview(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            basePixelData: basePixelData,
            baseBufferHandle: baseBufferHandle,
            samples: samples,
            brush: brush,
            preserveAlphaLockedPixels: preserveAlphaLockedPixels,
            usesResponsivePreview: usesResponsivePreview
        ) else {
            return nil
        }

        guard let gpuBufferHandle = preview.gpuBufferHandle,
              let dirtyRect = preview.dirtyRect,
              let incrementalUpdate = preview.incrementalUpdate else {
            strokeService.release(preview.gpuBufferHandle)
            return nil
        }

        return StrokePreviewResult(
            baseSnapshot: snapshot,
            surface: GpuLayerSurface(
                layerIndex: activeLayerIndex,
                width: snapshot.width,
                height: snapshot.height,
                handle: GpuSurfaceHandle(buffer: gpuBufferHandle)
            ),
            dirtyRegion: GpuSurfaceRegion(
                originX: dirtyRect.originX,
                originY: dirtyRect.originY,
                width: dirtyRect.width,
                height: dirtyRect.height
            ),
            incrementalUpdate: incrementalUpdate,
            isApproximatePreview: preview.isApproximatePreview
        )
    }

    public func makeCommittedSurface(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool
    ) -> (handle: MetalBufferHandle, dirtyRect: (originX: Int, originY: Int, width: Int, height: Int), fallbackPixelData: Data?)? {
        guard let baseLayer = snapshot.layers.first(where: { $0.index == activeLayerIndex }) else {
            return nil
        }

        guard let gpuOutput = strokeService.executeStroke(
            MetalStrokeExecutionRequest(
                basePixelData: baseLayer.pixelData,
                baseBufferHandle: baseLayer.gpuBufferHandle,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height,
                samples: samples,
                brush: brush,
                mode: .commit,
                snapshotRevision: snapshot.revision,
                activeLayerIndex: activeLayerIndex
            )
        ) else {
            return nil
        }
        guard let handle = gpuOutput.gpuBufferHandle else {
            return nil
        }
        if preserveAlphaLockedPixels {
            guard let alphaPreservedHandle = materializationService.preservingExistingAlphaBufferHandle(
                sourceHandle: handle,
                existingHandle: baseLayer.gpuBufferHandle,
                existingPixelData: baseLayer.pixelData,
                width: snapshot.width,
                height: snapshot.height
            ) else {
                strokeService.release(handle)
                return nil
            }
            strokeService.release(handle)
            return (alphaPreservedHandle, gpuOutput.dirtyRect, nil)
        }
        return (handle, gpuOutput.dirtyRect, gpuOutput.pixelData)
    }

    public func makeCommittedPixels(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool
    ) -> Data? {
        guard let baseLayer = snapshot.layers.first(where: { $0.index == activeLayerIndex }) else {
            return nil
        }

        if let gpuOutput = strokeService.executeStroke(
            MetalStrokeExecutionRequest(
                basePixelData: baseLayer.pixelData,
                baseBufferHandle: baseLayer.gpuBufferHandle,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height,
                samples: samples,
                brush: brush,
                mode: .commit,
                snapshotRevision: snapshot.revision,
                activeLayerIndex: activeLayerIndex
            )
        ) {
            if preserveAlphaLockedPixels {
                return materializationService.preservingExistingAlpha(
                    source: gpuOutput.pixelData,
                    existing: baseLayer.pixelData,
                    width: snapshot.width,
                    height: snapshot.height
                )
            }
            return gpuOutput.pixelData
        }
        return nil
    }

    public func stageCommittedSnapshot(
        baseSnapshot: MetalDocumentSnapshot,
        committedPixels: Data,
        lastCommittedRenderRevision: Int,
        activeLayerIndex: Int,
        stagedCompositePixelData: Data?
    ) -> MetalDocumentSnapshot? {
        let compositePixelData: Data
        if let stagedCompositePixelData {
            compositePixelData = stagedCompositePixelData
        } else if let composited = compositingService.compositedPreviewPixelData(
            snapshot: baseSnapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: committedPixels
        ) {
            compositePixelData = composited
        } else {
            return nil
        }

        let layers = baseSnapshot.layers.map { layer in
            guard layer.index == activeLayerIndex else { return layer }
            return MetalLayerSnapshot.unsafeUnchecked(
                index: layer.index,
                opacity: layer.opacity,
                visible: layer.visible,
                isClipped: layer.isClipped,
                blendMode: layer.blendMode,
                thumbnailSurface: layer.thumbnailSurface,
                thumbnailData: layer.thumbnailData,
                pixelData: committedPixels
            )
        }

        return MetalDocumentSnapshot.unsafeUnchecked(
            width: baseSnapshot.width,
            height: baseSnapshot.height,
            revision: max(baseSnapshot.revision, lastCommittedRenderRevision) + 1,
            compositePixelData: compositePixelData,
            layers: layers
        )
    }

    private func makeInteractiveStrokePreview(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        basePixelData: Data,
        baseBufferHandle: MetalBufferHandle? = nil,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool,
        usesResponsivePreview: Bool = false
    ) -> DocumentInteractiveStrokePreviewResult? {
        let previewBrush = usesResponsivePreview
            ? GpuRenderingSupport.responsivePreviewBrush(from: brush)
            : brush
        let usesGpuOnlyResponsivePreview = usesResponsivePreview &&
            GpuRenderingSupport.shouldUseGpuOnlyResponsivePreview(for: brush)
        let usesApproximatePreview = previewBrush != brush || usesGpuOnlyResponsivePreview

        if !preserveAlphaLockedPixels,
           (GpuRenderingSupport.shouldUseIncrementalPreviewUpdate(for: previewBrush) || usesGpuOnlyResponsivePreview),
           let gpuResult = strokeService.executeStrokeMutation(
               MetalStrokeExecutionRequest(
                   basePixelData: basePixelData,
                   baseBufferHandle: baseBufferHandle,
                   canvasWidth: snapshot.width,
                   canvasHeight: snapshot.height,
                   samples: samples,
                   brush: previewBrush,
                   mode: .interactive,
                   snapshotRevision: snapshot.revision,
                   activeLayerIndex: activeLayerIndex
               )
           ),
           let bufferHandle = gpuResult.gpuBufferHandle {
            if let incrementalUpdate = compositingService.compositedPreviewIncrementalUpdate(
                snapshot: snapshot,
                activeLayerIndex: activeLayerIndex,
                adjustedActiveLayerBufferHandle: bufferHandle,
                dirtyRect: gpuResult.dirtyRect
            ) {
                return DocumentInteractiveStrokePreviewResult(
                    pixelData: nil,
                    gpuBufferHandle: bufferHandle,
                    dirtyRect: gpuResult.dirtyRect,
                    rectPixelData: usesApproximatePreview && !usesGpuOnlyResponsivePreview ? gpuResult.rectPixelData : nil,
                    incrementalUpdate: incrementalUpdate,
                    isApproximatePreview: usesApproximatePreview
                )
            }
            strokeService.release(bufferHandle)
            if usesResponsivePreview {
                return nil
            }
        }

        guard !usesResponsivePreview else {
            return nil
        }

        guard let gpuResult = strokeService.executeStroke(
            MetalStrokeExecutionRequest(
                basePixelData: basePixelData,
                baseBufferHandle: baseBufferHandle,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height,
                samples: samples,
                brush: previewBrush,
                mode: .interactive,
                snapshotRevision: snapshot.revision,
                activeLayerIndex: activeLayerIndex
            )
        ) else {
            return nil
        }

        if preserveAlphaLockedPixels {
            guard
                let sourceHandle = gpuResult.gpuBufferHandle,
                let alphaPreservedHandle = materializationService.preservingExistingAlphaBufferHandle(
                    sourceHandle: sourceHandle,
                    existingHandle: baseBufferHandle,
                    existingPixelData: basePixelData,
                    width: snapshot.width,
                    height: snapshot.height
                )
            else {
                strokeService.release(gpuResult.gpuBufferHandle)
                return nil
            }
            strokeService.release(sourceHandle)
            let alphaPreservedPixels = materializationService.materializedPixelData(for: alphaPreservedHandle)
            guard let incrementalUpdate = compositingService.compositedPreviewIncrementalUpdate(
                snapshot: snapshot,
                activeLayerIndex: activeLayerIndex,
                adjustedActiveLayerBufferHandle: alphaPreservedHandle,
                dirtyRect: gpuResult.dirtyRect
            ) ?? alphaPreservedPixels.flatMap({
                livePreviewIncrementalUpdate(
                    snapshot: snapshot,
                    activeLayerIndex: activeLayerIndex,
                    adjustedActiveLayerPixels: $0,
                    dirtyRect: gpuResult.dirtyRect
                )
            }) else {
                strokeService.release(alphaPreservedHandle)
                return nil
            }
            return DocumentInteractiveStrokePreviewResult(
                pixelData: nil,
                gpuBufferHandle: alphaPreservedHandle,
                dirtyRect: gpuResult.dirtyRect,
                rectPixelData: nil,
                incrementalUpdate: incrementalUpdate,
                isApproximatePreview: usesApproximatePreview
            )
        }

        let adjustedPixels: Data
        adjustedPixels = gpuResult.pixelData

        let incrementalUpdate = livePreviewIncrementalUpdate(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedPixels,
            dirtyRect: gpuResult.dirtyRect
        )

        return DocumentInteractiveStrokePreviewResult(
            pixelData: adjustedPixels,
            gpuBufferHandle: gpuResult.gpuBufferHandle,
            dirtyRect: gpuResult.dirtyRect,
            rectPixelData: gpuResult.rectPixelData ?? Self.pixelData(
                in: gpuResult.dirtyRect,
                from: adjustedPixels,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height
            ),
            incrementalUpdate: incrementalUpdate,
            isApproximatePreview: usesApproximatePreview
        )
    }

    private func materializedIncrementalUpdateIfNeeded(
        _ update: IncrementalLayerUpdate
    ) -> IncrementalLayerUpdate {
        guard update.pixelData.isEmpty, let handle = update.gpuBufferHandle else {
            return update
        }
        guard let pixelData = materializationService.materializedPixelData(for: handle) else {
            return update
        }
        return IncrementalLayerUpdate.unsafeUnchecked(
            id: update.id,
            layerIndex: update.layerIndex,
            originX: update.originX,
            originY: update.originY,
            width: update.width,
            height: update.height,
            transferKind: update.transferKind,
            gpuBufferHandle: update.gpuBufferHandle,
            pixelData: pixelData
        )
    }

    private func livePreviewIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        if let incrementalUpdate = compositingService.compositedPreviewIncrementalUpdate(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            dirtyRect: dirtyRect
        ) {
            return incrementalUpdate
        }
        guard let composite = compositingService.compositedPreviewPixelData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels
        ) else {
            return nil
        }
        return IncrementalLayerUpdate.unsafeUnchecked(
            layerIndex: -1,
            originX: 0,
            originY: 0,
            width: snapshot.width,
            height: snapshot.height,
            pixelData: composite
        )
    }

    private static func pixelData(
        in dirtyRect: (originX: Int, originY: Int, width: Int, height: Int),
        from pixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> Data? {
        guard dirtyRect.width > 0, dirtyRect.height > 0 else { return nil }
        guard dirtyRect.originX >= 0, dirtyRect.originY >= 0 else { return nil }
        guard dirtyRect.originX + dirtyRect.width <= canvasWidth else { return nil }
        guard dirtyRect.originY + dirtyRect.height <= canvasHeight else { return nil }
        guard pixelData.count == canvasWidth * canvasHeight * 4 else { return nil }

        var rectPixelData = Data(count: dirtyRect.width * dirtyRect.height * 4)
        rectPixelData.withUnsafeMutableBytes { destinationBytes in
            pixelData.withUnsafeBytes { sourceBytes in
                guard
                    let destination = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    let source = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else {
                    return
                }
                for row in 0..<dirtyRect.height {
                    let srcOffset = ((dirtyRect.originY + row) * canvasWidth + dirtyRect.originX) * 4
                    let dstOffset = row * dirtyRect.width * 4
                    memcpy(destination + dstOffset, source + srcOffset, dirtyRect.width * 4)
                }
            }
        }
        return rectPixelData
    }

}
