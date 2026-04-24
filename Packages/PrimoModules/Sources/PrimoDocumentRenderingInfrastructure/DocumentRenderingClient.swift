import CoreGraphics
import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentMetalRuntimeInfrastructure

public typealias MetalStrokeExecutionMode = PrimoMetalStrokeExecutionMode
public typealias MetalStrokeExecutionRequest = PrimoMetalStrokeExecutionRequest
public typealias MetalStrokeExecutionResult = PrimoMetalStrokeExecutionResult
public typealias MetalSelectionCombineMode = PrimoMetalSelectionCombineMode

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
        )
    }

    public func strokePreviewDirtyRect(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> (originX: Int, originY: Int, width: Int, height: Int)? {
        Self.strokePreviewDirtyRect(
            samples: samples,
            brush: brush,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )
    }

    public func shouldUseIncrementalPreviewUpdate(for brush: BrushRuntimeSettings) -> Bool {
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
        guard let gpuResult = executeStroke(
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
        ) else {
            return nil
        }
        let adjustedPixels: Data
        if preserveAlphaLockedPixels {
            guard let preserved = preservingExistingAlpha(
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
        let rasterDirtyRect = gpuResult.dirtyRect
        let rasterRectPixelData = gpuResult.rectPixelData

        let previewDirtyRect = rasterDirtyRect

        let incrementalUpdate: IncrementalLayerUpdate?
        if shouldUseIncrementalPreviewUpdate(for: brush) {
            incrementalUpdate = compositedPreviewIncrementalUpdate(
                snapshot: snapshot,
                activeLayerIndex: activeLayerIndex,
                adjustedActiveLayerPixels: adjustedPixels,
                dirtyRect: previewDirtyRect
            )
        } else {
            incrementalUpdate = nil
        }

        return DocumentInteractiveStrokePreviewResult(
            pixelData: adjustedPixels,
            dirtyRect: previewDirtyRect,
            rectPixelData: rasterRectPixelData ?? Self.pixelData(
                in: previewDirtyRect,
                from: adjustedPixels,
                canvasWidth: snapshot.width,
                canvasHeight: snapshot.height
            ),
            incrementalUpdate: incrementalUpdate
        )
    }

    public func preservingExistingAlpha(
        source: Data,
        existing: Data,
        width: Int,
        height: Int
    ) -> Data? {
        backend.preservingExistingAlpha(
            source: source,
            existing: existing,
            width: width,
            height: height
        )
    }

    private static func strokePreviewDirtyRect(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> (originX: Int, originY: Int, width: Int, height: Int)? {
        guard !samples.isEmpty, canvasWidth > 0, canvasHeight > 0 else { return nil }

        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        let scatterExtent = brush.scatterEnabled ? max(CGFloat(brush.scatterLateral), CGFloat(brush.scatterLinear)) : 0
        let softness = max(0, 1.0 - CGFloat(brush.hardness))
        let featherPadding = max(
            brush.tipKind == .airbrush ? CGFloat(brush.radius) * (0.9 + softness * 0.6) : CGFloat(brush.radius) * (0.35 + softness * 0.75),
            brush.tipKind == .airbrush ? 18.0 : 10.0
        )

        for sample in samples {
            let pressureFactor = max(0.1, 1.0 + ((sample.pressure - 1.0) * CGFloat(brush.pressureSensitivity)))
            let radiusPadding = max(CGFloat(brush.radius) * pressureFactor, 1.5)
                + (scatterExtent * CGFloat(brush.radius))
                + featherPadding
                + 6.0
            minX = min(minX, sample.point.x - radiusPadding)
            minY = min(minY, sample.point.y - radiusPadding)
            maxX = max(maxX, sample.point.x + radiusPadding)
            maxY = max(maxY, sample.point.y + radiusPadding)
        }

        guard minX.isFinite, minY.isFinite, maxX.isFinite, maxY.isFinite else { return nil }
        let originX = max(0, Int(floor(minX)))
        let originY = max(0, Int(floor(minY)))
        let maxRectX = min(canvasWidth - 1, Int(ceil(maxX)))
        let maxRectY = min(canvasHeight - 1, Int(ceil(maxY)))
        guard maxRectX >= originX, maxRectY >= originY else { return nil }
        return (
            originX: originX,
            originY: originY,
            width: maxRectX - originX + 1,
            height: maxRectY - originY + 1
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

    public func autoSelection(
        pixelData: Data,
        width: Int,
        height: Int,
        seedX: Int,
        seedY: Int,
        thresholdMode: FillThresholdMode,
        opacityTolerance: Double,
        colorTolerance: Double,
        expansion: Int
    ) -> [UInt8]? {
        backend.autoSelection(
            pixelData: pixelData,
            canvasWidth: width,
            canvasHeight: height,
            seedX: seedX,
            seedY: seedY,
            thresholdMode: thresholdMode,
            opacityTolerance: opacityTolerance,
            colorTolerance: colorTolerance,
            expansion: expansion
        )
    }

    public func lassoSelection(
        points: [CGPoint],
        canvasWidth: Int,
        canvasHeight: Int
    ) -> [UInt8]? {
        backend.lassoSelection(
            points: points,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )
    }

    public func expandedSelectionMask(
        maskData: Data,
        maskWidth: Int,
        maskHeight: Int,
        originX: Int,
        originY: Int,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> [UInt8]? {
        backend.expandedSelectionMask(
            maskData: maskData,
            maskWidth: maskWidth,
            maskHeight: maskHeight,
            originX: originX,
            originY: originY,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )
    }

    public func combinedSelectionMask(
        base: [UInt8],
        incoming: [UInt8],
        mode: MetalSelectionCombineMode,
        width: Int,
        height: Int
    ) -> [UInt8]? {
        backend.combinedSelectionMask(
            base: base,
            incoming: incoming,
            mode: mode,
            width: width,
            height: height
        )
    }

    public func inpaintCrop(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        selectionBounds: CGRect,
        expandedMask: [UInt8],
        padding: Int = 64
    ) -> InpaintCrop? {
        guard let payload = backend.inpaintCropPayload(
            source: source,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            selectionBounds: selectionBounds,
            expandedMask: expandedMask,
            padding: padding
        ) else {
            return nil
        }

        return InpaintCrop(
            pixelData: payload.pixelData,
            width: payload.width,
            height: payload.height,
            originX: payload.originX,
            originY: payload.originY,
            selectionMask: payload.selectionMask
        )
    }

    public func applyInpaintCrop(
        editedCropPixelData: Data,
        to baseLayerPixelData: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        crop: InpaintCrop,
        featherRadius: Int = 10
    ) -> Data? {
        backend.applyInpaintCrop(
            editedCropPixelData: editedCropPixelData,
            to: baseLayerPixelData,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            cropWidth: crop.width,
            cropHeight: crop.height,
            originX: crop.originX,
            originY: crop.originY,
            selectionMask: crop.selectionMask,
            featherRadius: featherRadius
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
