enum PaintDocumentThumbnailInvalidation {
    case none
    case layer(Int)
    case all
}

struct PaintDocumentLifecycleMutation {
    let thumbnailInvalidation: PaintDocumentThumbnailInvalidation
    let timelapseEvents: [TimelapseOperation]
    let shouldCaptureTimelapseFrame: Bool

    static let none = PaintDocumentLifecycleMutation(
        thumbnailInvalidation: .none,
        timelapseEvents: [],
        shouldCaptureTimelapseFrame: false
    )
}
