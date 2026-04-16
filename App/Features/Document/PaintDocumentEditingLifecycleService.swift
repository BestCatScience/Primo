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
}
