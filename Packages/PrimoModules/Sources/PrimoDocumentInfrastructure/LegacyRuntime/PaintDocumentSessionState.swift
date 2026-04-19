import Foundation

final class PaintDocumentSessionState {
    final class PresentationState {
        private(set) var revision: Int = 0
        private(set) var paperStyle: CanvasPaperStyle = .default
        private var layerThumbnailCache: [Int: Data] = [:]

        func advanceRevision() -> Int {
            revision += 1
            return revision
        }

        func setPaperStyle(_ paperStyle: CanvasPaperStyle) {
            self.paperStyle = paperStyle
        }

        func cachedThumbnailData(for index: Int) -> Data? {
            layerThumbnailCache[index]
        }

        func storeThumbnailData(_ data: Data?, for index: Int) {
            layerThumbnailCache[index] = data
        }

        func invalidateThumbnailCache(for index: Int? = nil) {
            if let index {
                layerThumbnailCache.removeValue(forKey: index)
            } else {
                layerThumbnailCache.removeAll(keepingCapacity: true)
            }
        }
    }

    final class TimelapseState {
        let directoryURL: URL
        private(set) var frames: [TimelapseFrame] = []
        private(set) var events: [TimelapseOperation] = []
        private(set) var nextFrameID: Int = 0
        var usesOperationPersistence = true

        init(directoryURL: URL) {
            self.directoryURL = directoryURL
        }

        func record(events newEvents: [TimelapseOperation]) {
            guard !newEvents.isEmpty else { return }
            events.append(contentsOf: newEvents)
        }

        func reserveNextFrameURL(using service: PaintDocumentTimelapseService) -> URL {
            let frameURL = service.makeFrameURL(in: directoryURL, frameID: nextFrameID)
            nextFrameID += 1
            return frameURL
        }

        func appendFrame(_ frame: TimelapseFrame, maxFrameCount: Int) -> TimelapseFrame? {
            frames.append(frame)
            guard frames.count > maxFrameCount else { return nil }
            return frames.remove(at: 1)
        }

        @discardableResult
        func resetHistory(keepingCapacity: Bool = false) -> [TimelapseFrame] {
            let removedFrames = frames
            frames.removeAll(keepingCapacity: keepingCapacity)
            events.removeAll(keepingCapacity: keepingCapacity)
            nextFrameID = 0
            return removedFrames
        }

        func restoreOperations(_ restoredEvents: [TimelapseOperation]) {
            usesOperationPersistence = true
            events = restoredEvents
            frames.removeAll(keepingCapacity: true)
            nextFrameID = 0
        }

        func restoreFrames(_ restoredFrames: [TimelapseFrame]) {
            usesOperationPersistence = false
            frames = restoredFrames
            events.removeAll(keepingCapacity: true)
            nextFrameID = restoredFrames.count
        }
    }

    final class StrokeCaptureState {
        private(set) var layerIndex: Int?
        private(set) var brush: BrushRuntimeSettings?
        private(set) var samples: [StylusSample] = []

        func begin(on layerIndex: Int, brush: BrushRuntimeSettings, sample: StylusSample) {
            self.layerIndex = layerIndex
            self.brush = brush
            samples = [sample]
        }

        func append(_ sample: StylusSample) {
            samples.append(sample)
        }

        func takeRecordedOperation() -> TimelapseOperation? {
            defer { reset() }
            guard let layerIndex, let brush, !samples.isEmpty else { return nil }
            return .stroke(
                layerIndex: .unchecked(layerIndex),
                brush: brush,
                samples: samples
            )
        }

        func reset() {
            layerIndex = nil
            brush = nil
            samples.removeAll(keepingCapacity: true)
        }
    }

    final class BlurStrokeCaptureState {
        private(set) var layerIndex: Int?
        private(set) var brush: BrushRuntimeSettings?
        private(set) var samples: [StylusSample] = []
        private(set) var hasCapturedHistory = false

        func beginOrContinue(on layerIndex: Int, brush: BrushRuntimeSettings) {
            guard self.layerIndex != layerIndex || self.brush != brush else { return }
            self.layerIndex = layerIndex
            self.brush = brush
            samples.removeAll(keepingCapacity: true)
            hasCapturedHistory = false
        }

        func append(contentsOf newSamples: [StylusSample]) {
            samples.append(contentsOf: newSamples)
        }

        var shouldApplyTransiently: Bool {
            hasCapturedHistory
        }

        func markHistoryCaptured() {
            hasCapturedHistory = true
        }

        func takeRecordedOperation() -> TimelapseOperation? {
            defer { reset() }
            guard let layerIndex, let brush, !samples.isEmpty else { return nil }
            return .blurStroke(
                layerIndex: .unchecked(layerIndex),
                brush: brush,
                samples: samples
            )
        }

        func reset() {
            layerIndex = nil
            brush = nil
            samples.removeAll(keepingCapacity: true)
            hasCapturedHistory = false
        }
    }

    final class EditingState {
        let stroke = StrokeCaptureState()
        let blurStroke = BlurStrokeCaptureState()

        func resetAll() {
            stroke.reset()
            blurStroke.reset()
        }
    }

    final class TextLayerState {
        private(set) var values: [Int: TextLayerData] = [:]

        func data(at index: Int) -> TextLayerData? {
            values[index]
        }

        func contains(_ index: Int) -> Bool {
            values[index] != nil
        }

        func set(_ textLayer: TextLayerData, at index: Int) {
            values[index] = textLayer
        }

        func remove(at index: Int) {
            values.removeValue(forKey: index)
        }

        func snapshot() -> [Int: TextLayerData] {
            values
        }

        func replaceAll(with newValues: [Int: TextLayerData]) {
            values = newValues
        }

        func remapForInsertion(at insertedIndex: Int) {
            values = Dictionary(uniqueKeysWithValues: values.map { index, value in
                (index >= insertedIndex ? index + 1 : index, value)
            })
        }

        func remapForDuplication(of sourceIndex: Int, duplicatedIndex: Int, duplicate: TextLayerData) {
            remapForInsertion(at: duplicatedIndex)
            values[duplicatedIndex] = duplicate
        }

        func remapForDeletion(of deletedIndex: Int) {
            values = Dictionary(uniqueKeysWithValues: values.compactMap { index, value in
                guard index != deletedIndex else { return nil }
                return (index > deletedIndex ? index - 1 : index, value)
            })
        }

        func remapForMove(from sourceIndex: Int, to destinationIndex: Int) {
            var remapped: [Int: TextLayerData] = [:]
            for (index, value) in values {
                if index == sourceIndex {
                    remapped[destinationIndex] = value
                } else if sourceIndex < destinationIndex, index > sourceIndex, index <= destinationIndex {
                    remapped[index - 1] = value
                } else if sourceIndex > destinationIndex, index >= destinationIndex, index < sourceIndex {
                    remapped[index + 1] = value
                } else {
                    remapped[index] = value
                }
            }
            values = remapped
        }
    }

    let presentation = PresentationState()
    let timelapse: TimelapseState
    let editing = EditingState()
    let textLayers = TextLayerState()

    init(timelapseDirectoryURL: URL) {
        timelapse = TimelapseState(directoryURL: timelapseDirectoryURL)
    }
}
