import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentMetalRuntimeInfrastructure
import PrimoDocumentStrokeInfrastructure

public typealias MetalStrokeExecutionMode = PrimoMetalStrokeExecutionMode
public typealias MetalStrokeExecutionRequest = PrimoMetalStrokeExecutionRequest
public typealias MetalStrokeExecutionResult = PrimoMetalStrokeExecutionResult

public struct DocumentInteractiveStrokePreviewResult: Sendable {
    public let pixelData: Data
    public let dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)?
    public let rectPixelData: Data?
    public let incrementalUpdate: IncrementalLayerUpdate?

    public init(
        pixelData: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)?,
        rectPixelData: Data?,
        incrementalUpdate: IncrementalLayerUpdate?
    ) {
        self.pixelData = pixelData
        self.dirtyRect = dirtyRect
        self.rectPixelData = rectPixelData
        self.incrementalUpdate = incrementalUpdate
    }
}

public struct DocumentRenderingClient: Sendable {
    private let backend: PrimoMetalDocumentProcessingClient

    public init(
        backend: PrimoMetalDocumentProcessingClient = .shared
    ) {
        self.backend = backend
    }

    public static let live = DocumentRenderingClient()

    public var isAvailable: Bool {
        backend.isAvailable
    }

    public func resetStrokeExecutionSession() {
        backend.resetStrokeExecutionSession()
    }

    public func resetInteractiveStrokeState() {
        resetStrokeExecutionSession()
    }

    public func selectionOverlayRGBA(
        maskData: Data,
        width: Int,
        height: Int,
        red: UInt8 = 91,
        green: UInt8 = 181,
        blue: UInt8 = 255,
        maximumAlpha: Float = 96.0 / 255.0
    ) -> Data? {
        backend.selectionOverlayRGBA(
            maskData: maskData,
            width: width,
            height: height,
            red: red,
            green: green,
            blue: blue,
            maximumAlpha: maximumAlpha
        )
    }

    public func eyedropperLoupeRGBA(
        sourcePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        centerX: Int,
        centerY: Int,
        gridSize: Int,
        paperStyle: CanvasPaperStyle,
        blendWithPaper: Bool
    ) -> Data? {
        backend.eyedropperLoupeRGBA(
            sourcePixelData: sourcePixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            centerX: centerX,
            centerY: centerY,
            gridSize: gridSize,
            paperStyle: paperStyle,
            blendWithPaper: blendWithPaper
        )
    }

    public func compositedPaperPreviewRGBA(
        pixelData: Data,
        width: Int,
        height: Int,
        paperStyle: CanvasPaperStyle
    ) -> Data? {
        backend.compositedPaperPreviewRGBA(
            pixelData: pixelData,
            width: width,
            height: height,
            paperStyle: paperStyle
        )
    }

    public func executeStroke(_ request: MetalStrokeExecutionRequest) -> MetalStrokeExecutionResult? {
        backend.executeStroke(request)
    }

    public func rasterizedStrokePixelData(
        basePixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        mode: MetalStrokeExecutionMode = .commit,
        snapshotRevision: Int? = nil,
        activeLayerIndex: Int? = nil
    ) -> Data? {
        backend.rasterizedStrokePixelData(
            basePixelData: basePixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            samples: samples,
            brush: brush,
            mode: mode,
            snapshotRevision: snapshotRevision,
            activeLayerIndex: activeLayerIndex
        )
    }

    public func compositedPreviewPixelData(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data
    ) -> Data? {
        backend.compositedPreviewPixelData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels
        ) ?? DocumentPreviewComposite.compositedPreviewPixelData(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels
        )
    }

    public func strokePreviewDirtyRect(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> (originX: Int, originY: Int, width: Int, height: Int)? {
        DocumentPreviewComposite.strokePreviewDirtyRect(
            samples: samples,
            brush: brush,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )
    }

    public func shouldUseIncrementalPreviewUpdate(for brush: BrushRuntimeSettings) -> Bool {
        DocumentPreviewComposite.shouldUseIncrementalPreviewUpdate(for: brush)
    }

    public func compositedPreviewIncrementalUpdate(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        adjustedActiveLayerPixels: Data,
        dirtyRect: (originX: Int, originY: Int, width: Int, height: Int)
    ) -> IncrementalLayerUpdate? {
        backend.compositedPreviewIncrementalUpdate(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            dirtyRect: dirtyRect
        ) ?? DocumentPreviewComposite.compositedPreviewIncrementalUpdate(
            snapshot: snapshot,
            activeLayerIndex: activeLayerIndex,
            adjustedActiveLayerPixels: adjustedActiveLayerPixels,
            dirtyRect: dirtyRect
        )
    }

    public func renderedCompositePNGData(
        snapshot: MetalDocumentSnapshot,
        paperStyle: CanvasPaperStyle
    ) -> Data? {
        let pixelData = compositedPaperPreviewRGBA(
            pixelData: snapshot.compositePixelData,
            width: snapshot.width,
            height: snapshot.height,
            paperStyle: paperStyle
        ) ?? snapshot.compositePixelData

        return DocumentRasterImageService.pngData(
            fromLayerPixelData: pixelData,
            width: snapshot.width,
            height: snapshot.height
        )
    }

    public func makeInteractiveStrokePreview(
        snapshot: MetalDocumentSnapshot,
        activeLayerIndex: Int,
        basePixelData: Data,
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        preserveAlphaLockedPixels: Bool
    ) -> DocumentInteractiveStrokePreviewResult? {
        let adjustedPixels: Data
        let rasterDirtyRect: (originX: Int, originY: Int, width: Int, height: Int)?
        let rasterRectPixelData: Data?

        if let gpuResult = executeStroke(
            MetalStrokeExecutionRequest(
                basePixelData: basePixelData,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height,
                samples: samples,
                brush: brush,
                mode: .interactive,
                snapshotRevision: snapshot.revision,
                activeLayerIndex: activeLayerIndex
            )
        ) {
            adjustedPixels = preserveAlphaLockedPixels
                ? DocumentStrokeRasterizer.pixelDataByPreservingExistingAlpha(source: gpuResult.pixelData, existing: basePixelData)
                : gpuResult.pixelData
            rasterDirtyRect = gpuResult.dirtyRect
            rasterRectPixelData = gpuResult.rectPixelData
        } else if let fallbackPixels = DocumentStrokeRasterizer.layerPixelDataByApplyingCommittedStroke(
            basePixelData: basePixelData,
            canvasWidth: snapshot.width,
            canvasHeight: snapshot.height,
            samples: samples,
            brush: brush,
            preserveAlphaLockedPixels: preserveAlphaLockedPixels
        ) {
            adjustedPixels = fallbackPixels
            rasterDirtyRect = nil
            rasterRectPixelData = nil
        } else {
            return nil
        }

        let previewDirtyRect = rasterDirtyRect ?? strokePreviewDirtyRect(
            samples: samples,
            brush: brush,
            canvasWidth: snapshot.width,
            canvasHeight: snapshot.height
        )

        let incrementalUpdate: IncrementalLayerUpdate?
        if shouldUseIncrementalPreviewUpdate(for: brush),
           let dirtyRect = previewDirtyRect {
            incrementalUpdate = compositedPreviewIncrementalUpdate(
                snapshot: snapshot,
                activeLayerIndex: activeLayerIndex,
                adjustedActiveLayerPixels: adjustedPixels,
                dirtyRect: dirtyRect
            )
        } else {
            incrementalUpdate = nil
        }

        return DocumentInteractiveStrokePreviewResult(
            pixelData: adjustedPixels,
            dirtyRect: previewDirtyRect,
            rectPixelData: rasterRectPixelData ?? previewDirtyRect.flatMap {
                Self.pixelData(
                    in: $0,
                    from: adjustedPixels,
                    canvasWidth: snapshot.width,
                    canvasHeight: snapshot.height
                )
            },
            incrementalUpdate: incrementalUpdate
        )
    }

    public func invertMask(_ source: [UInt8]) -> [UInt8]? {
        backend.invertMask(source)
    }

    public func expandedMask(_ source: [UInt8], width: Int, height: Int, expansion: Int) -> [UInt8]? {
        backend.expandedMask(source, width: width, height: height, expansion: expansion)
    }

    public func contractedMask(_ source: [UInt8], width: Int, height: Int, contraction: Int) -> [UInt8]? {
        backend.contractedMask(source, width: width, height: height, contraction: contraction)
    }

    public func featheredMask(_ source: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8]? {
        backend.featheredMask(source, width: width, height: height, radius: radius)
    }

    public func colorRangeSelection(
        pixelData: Data,
        width: Int,
        height: Int,
        request: ColorRangeSelectionRequest
    ) -> [UInt8]? {
        backend.colorRangeSelection(
            pixelData: pixelData,
            width: width,
            height: height,
            request: request
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
