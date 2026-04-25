import CoreGraphics
import Foundation
import PrimoDocumentContracts

public struct DocumentStrokePreviewPlan: Sendable {
    public let baseSnapshot: MetalDocumentSnapshot
    public let adjustedBufferHandle: MetalBufferHandle
    public let dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    public let incrementalUpdate: IncrementalLayerUpdate?
    public let isApproximatePreview: Bool

    public init(
        baseSnapshot: MetalDocumentSnapshot,
        adjustedBufferHandle: MetalBufferHandle,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int),
        incrementalUpdate: IncrementalLayerUpdate?,
        isApproximatePreview: Bool = false
    ) {
        self.baseSnapshot = baseSnapshot
        self.adjustedBufferHandle = adjustedBufferHandle
        self.dirtyRect = dirtyRect
        self.incrementalUpdate = incrementalUpdate
        self.isApproximatePreview = isApproximatePreview
    }
}

public struct DocumentStrokeProcessingService: Sendable {
    public let strokeGateway: StrokeRenderingGateway
    public let compositingGateway: LayerCompositingGateway
    public let materializationGateway: SurfaceMaterializationGateway

    public init(
        strokeGateway: StrokeRenderingGateway = StrokeRenderingGateway(),
        compositingGateway: LayerCompositingGateway = LayerCompositingGateway(),
        materializationGateway: SurfaceMaterializationGateway = SurfaceMaterializationGateway()
    ) {
        self.strokeGateway = strokeGateway
        self.compositingGateway = compositingGateway
        self.materializationGateway = materializationGateway
    }

    public func resetInteractiveStrokeState() {
        strokeGateway.resetExecutionSession()
    }

    public func makePreviewPlan(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        basePixelData: Data,
        baseBufferHandle: MetalBufferHandle? = nil,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool,
        usesResponsiveOilPreview: Bool = false
    ) -> DocumentStrokePreviewPlan? {
        guard let preview = makeInteractiveStrokePreview(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            basePixelData: basePixelData,
            baseBufferHandle: baseBufferHandle,
            samples: samples,
            brush: brush,
            preserveAlphaLockedPixels: preserveAlphaLockedPixels,
            usesResponsiveOilPreview: usesResponsiveOilPreview
        ) else {
            return nil
        }

        guard let gpuBufferHandle = preview.gpuBufferHandle,
              let dirtyRect = preview.dirtyRect else {
            return nil
        }

        return DocumentStrokePreviewPlan(
            baseSnapshot: snapshot,
            adjustedBufferHandle: gpuBufferHandle,
            dirtyRect: dirtyRect,
            incrementalUpdate: preview.incrementalUpdate,
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

        guard let gpuOutput = strokeGateway.executeStroke(
            MetalStrokeExecutionRequest(
                basePixelData: baseLayer.pixelData,
                baseBufferHandle: baseLayer.gpuBufferHandle,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height,
                samples: samples,
                brush: brush,
                mode: .interactive,
                snapshotRevision: snapshot.revision,
                activeLayerIndex: activeLayerIndex
            )
        ) else {
            return nil
        }
        guard !preserveAlphaLockedPixels else { return nil }
        guard let handle = gpuOutput.gpuBufferHandle else {
            return nil
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

        if let gpuOutput = strokeGateway.rasterizedStrokePixelData(
            basePixelData: baseLayer.pixelData,
            baseBufferHandle: baseLayer.gpuBufferHandle,
            canvasWidth: snapshot.width,
            canvasHeight: snapshot.height,
            samples: samples,
            brush: brush,
            mode: .interactive,
            snapshotRevision: snapshot.revision,
            activeLayerIndex: activeLayerIndex
        ) {
            if preserveAlphaLockedPixels {
                return materializationGateway.preservingExistingAlpha(
                    source: gpuOutput,
                    existing: baseLayer.pixelData,
                    width: snapshot.width,
                    height: snapshot.height
                )
            }
            return gpuOutput
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
        } else if let composited = compositingGateway.compositedPreviewPixelData(
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
            return MetalLayerSnapshot(
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

        return MetalDocumentSnapshot(
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
        usesResponsiveOilPreview: Bool = false
    ) -> DocumentInteractiveStrokePreviewResult? {
        let usesApproximateOilPreview =
            usesResponsiveOilPreview &&
            brush.tipKind == .oil &&
            brush.smudgeEngineEnabled
        let previewBrush = usesApproximateOilPreview
            ? DocumentRenderingClient.responsiveOilPreviewBrush(from: brush)
            : brush

        if !preserveAlphaLockedPixels,
           Self.shouldUseIncrementalPreviewUpdate(for: previewBrush),
           let gpuResult = strokeGateway.executeStrokeMutation(
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
            if let incrementalUpdate = compositingGateway.compositedPreviewIncrementalUpdate(
                snapshot: snapshot,
                activeLayerIndex: activeLayerIndex,
                adjustedActiveLayerBufferHandle: bufferHandle,
                dirtyRect: gpuResult.dirtyRect
            ) {
                return DocumentInteractiveStrokePreviewResult(
                    pixelData: nil,
                    gpuBufferHandle: bufferHandle,
                    dirtyRect: gpuResult.dirtyRect,
                    rectPixelData: usesApproximateOilPreview ? gpuResult.rectPixelData : nil,
                    incrementalUpdate: incrementalUpdate,
                    isApproximatePreview: usesApproximateOilPreview
                )
            }
            strokeGateway.release(bufferHandle)
        }

        guard let gpuResult = strokeGateway.executeStroke(
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

        let adjustedPixels: Data
        if preserveAlphaLockedPixels {
            guard let preserved = materializationGateway.preservingExistingAlpha(
                source: gpuResult.pixelData,
                existing: basePixelData,
                width: snapshot.width,
                height: snapshot.height
            ) else {
                return nil
            }
            adjustedPixels = preserved
        } else {
            adjustedPixels = gpuResult.pixelData
        }

        let incrementalUpdate = Self.shouldUseIncrementalPreviewUpdate(for: previewBrush)
            ? compositingGateway.compositedPreviewIncrementalUpdate(
                snapshot: snapshot,
                activeLayerIndex: activeLayerIndex,
                adjustedActiveLayerPixels: adjustedPixels,
                dirtyRect: gpuResult.dirtyRect
            )
            : nil

        return DocumentInteractiveStrokePreviewResult(
            pixelData: adjustedPixels,
            gpuBufferHandle: preserveAlphaLockedPixels ? nil : gpuResult.gpuBufferHandle,
            dirtyRect: gpuResult.dirtyRect,
            rectPixelData: gpuResult.rectPixelData ?? Self.pixelData(
                in: gpuResult.dirtyRect,
                from: adjustedPixels,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height
            ),
            incrementalUpdate: incrementalUpdate,
            isApproximatePreview: usesApproximateOilPreview
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

    private static func shouldUseIncrementalPreviewUpdate(for brush: BrushRuntimeSettings) -> Bool {
        let scatterExtent = brush.scatterEnabled ? max(CGFloat(brush.scatterLateral), CGFloat(brush.scatterLinear)) : 0
        let effectiveDiameter = (CGFloat(brush.radius) * 2.0) * (1.0 + scatterExtent)
        let softness = 1.0 - CGFloat(brush.hardness)

        if brush.tipKind == .airbrush && effectiveDiameter >= 42 {
            return false
        }
        if softness >= 0.34 && effectiveDiameter >= 56 {
            return false
        }
        return true
    }
}
