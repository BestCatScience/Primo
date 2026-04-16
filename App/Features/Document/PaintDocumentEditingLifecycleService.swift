struct PaintDocumentEditingLifecycleService {
    func mutation(
        recording events: [TimelapseOperation] = [],
        invalidating thumbnails: PaintDocumentThumbnailInvalidation = .none,
        captureFrame: Bool = true
    ) -> PaintDocumentLifecycleMutation {
        PaintDocumentLifecycleMutation(
            thumbnailInvalidation: thumbnails,
            timelapseEvents: events,
            shouldCaptureTimelapseFrame: captureFrame
        )
    }

    func mutation(
        recording event: TimelapseOperation,
        invalidating thumbnails: PaintDocumentThumbnailInvalidation = .none,
        captureFrame: Bool = true
    ) -> PaintDocumentLifecycleMutation {
        mutation(recording: [event], invalidating: thumbnails, captureFrame: captureFrame)
    }

    func resetStrokeState(
        activeLayerIndex: inout Int?,
        activeBrush: inout BrushRuntimeSettings?,
        activeSamples: inout [StylusSample]
    ) {
        activeLayerIndex = nil
        activeBrush = nil
        activeSamples.removeAll(keepingCapacity: true)
    }

    func resetBlurStrokeState(
        activeLayerIndex: inout Int?,
        activeBrush: inout BrushRuntimeSettings?,
        activeSamples: inout [StylusSample],
        blurStrokeHasCapturedHistory: inout Bool
    ) {
        activeLayerIndex = nil
        activeBrush = nil
        activeSamples.removeAll(keepingCapacity: true)
        blurStrokeHasCapturedHistory = false
    }

    func resetActiveEditingState(
        activeStrokeLayerIndex: inout Int?,
        activeStrokeBrush: inout BrushRuntimeSettings?,
        activeStrokeSamples: inout [StylusSample],
        activeBlurStrokeLayerIndex: inout Int?,
        activeBlurStrokeBrush: inout BrushRuntimeSettings?,
        activeBlurStrokeSamples: inout [StylusSample],
        blurStrokeHasCapturedHistory: inout Bool
    ) {
        resetStrokeState(
            activeLayerIndex: &activeStrokeLayerIndex,
            activeBrush: &activeStrokeBrush,
            activeSamples: &activeStrokeSamples
        )
        resetBlurStrokeState(
            activeLayerIndex: &activeBlurStrokeLayerIndex,
            activeBrush: &activeBlurStrokeBrush,
            activeSamples: &activeBlurStrokeSamples,
            blurStrokeHasCapturedHistory: &blurStrokeHasCapturedHistory
        )
    }
}
