import ComposableArchitecture
import CoreGraphics
import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentStrokeApplication
import simd

@Reducer
struct CanvasFeature {
    static let defaultCanvasSize = CGSize(width: 1152, height: 1536)

    static func trimmingDuplicateLeadingSamples(
        _ samples: [StylusSample],
        after previousSample: StylusSample?
    ) -> [StylusSample] {
        StrokeSessionState.trimmingDuplicateLeadingSamples(samples, after: previousSample)
    }

    static func trimmingDuplicateTrailingSamples(_ samples: [StylusSample]) -> [StylusSample] {
        StrokeSessionState.trimmingDuplicateTrailingSamples(samples)
    }

    @ObservableState
    struct State: Equatable {
        private static let maxPendingPreviewIncrementalUpdateCount = 8

        var canvasSize: CGSize = CanvasFeature.defaultCanvasSize
        var renderSnapshot: MetalDocumentSnapshot?
        var adjustmentPreviewPixelData: Data?
        var lastCommittedRenderRevision: Int = -1
        var localBufferRevision: Int = 0
        var lastRenderedLocalBufferRevision: Int = -1
        var pendingCommittedSnapshot: MetalDocumentSnapshot?
        var pendingPreviewIncrementalUpdates: [IncrementalLayerUpdate] = []
        var activeLayerIndex = 0
        var strokeSession = StrokeSessionState()
        var layerBuffers: [LayerCanvasBuffer] = [
            LayerCanvasBuffer(index: 0, name: "Layer 1", visible: true, opacity: 1.0)
        ]
        var activeStroke: Stroke?
        var shapePreviewIsLive = false
        var isStrokeActive = false
        var isAwaitingCommittedRender = false
        var currentTool: StudioToolKind = .brush
        var selectionMode: SelectionToolMode = .lasso
        var shapeMode: ShapeToolMode = .line
        var eyedropperSamplingSource: EyedropperSamplingSource = .activeLayer
        var selection: CanvasSelection?
        var selectionPreviewPoints: [CGPoint] = []
        var selectionMoveStartPoint: CGPoint?
        var selectionMoveOffset: CGSize = .zero
        var selectionMoveSourceSelection: CanvasSelection?
        var selectionMoveBaseSnapshot: MetalDocumentSnapshot?
        var activeTextLayer: TextLayerData?
        var viewportOffset: CGSize = .zero
        var zoomScale: CGFloat = 1.0
        var paperStyle: CanvasPaperStyle = .default
        var previewStyle = PreviewStrokeStyle(
            tipKind: .pencil,
            isEraser: false,
            radius: 3.0,
            opacity: 0.9,
            flow: 0.9,
            hardness: 0.82,
            roundness: 0.9,
            angle: 0.0,
            followsStrokeAngle: true,
            pressureSensitivity: 0.4,
            stabilization: 0.5,
            customTip: nil,
            color: CGColor(red: 31.0 / 255.0, green: 31.0 / 255.0, blue: 34.0 / 255.0, alpha: 1.0)
        )
        var previewResetNonce: Int = 0

        mutating func setCanvasSize(_ size: CGSize) {
            canvasSize = size
        }

        mutating func activateLayer(_ index: Int) {
            activeLayerIndex = index
        }

        mutating func activateLayerForEditing(_ index: Int) {
            activeLayerIndex = index
            clearSelection()
        }

        mutating func activateLayerForNewContent(_ index: Int) {
            activeLayerIndex = index
            clearSelectionState()
        }

        mutating func replaceLayerBuffers(_ layerBuffers: [LayerCanvasBuffer]) {
            self.layerBuffers = layerBuffers
        }

        mutating func activateTool(_ tool: StudioToolKind) {
            currentTool = tool
        }

        mutating func selectTool(
            _ tool: StudioToolKind,
            selectionMode: SelectionToolMode,
            shapeMode: ShapeToolMode,
            eyedropperSamplingSource: EyedropperSamplingSource
        ) {
            activateTool(tool)
            updateInteractionModes(
                selectionMode: selectionMode,
                shapeMode: shapeMode,
                eyedropperSamplingSource: eyedropperSamplingSource
            )
            clearSelectionPreview()
            if tool != .select && tool != .move {
                clearSelection()
            }
        }

        mutating func setSelection(_ selection: CanvasSelection?) {
            self.selection = selection
        }

        mutating func clearSelection() {
            selection = nil
            cancelSelectionMove()
        }

        mutating func replaceSelection(_ selection: CanvasSelection?) {
            self.selection = selection
            clearSelectionPreview()
            cancelSelectionMove()
        }

        mutating func clearSelectionPreview() {
            selectionPreviewPoints = []
        }

        mutating func clearSelectionState() {
            selection = nil
            selectionPreviewPoints = []
            cancelSelectionMove()
        }

        mutating func beginSelectionMove(at point: CGPoint) {
            selectionMoveStartPoint = point
            selectionMoveOffset = .zero
            selectionMoveSourceSelection = selection
            selectionMoveBaseSnapshot = renderSnapshot
            clearSelectionPreview()
        }

        mutating func updateSelectionMove(offset: CGSize) {
            guard selectionMoveStartPoint != nil else { return }
            selectionMoveOffset = offset
        }

        mutating func cancelSelectionMove() {
            selectionMoveStartPoint = nil
            selectionMoveOffset = .zero
            selectionMoveSourceSelection = nil
            selectionMoveBaseSnapshot = nil
        }

        mutating func clearAdjustmentPreview() {
            adjustmentPreviewPixelData = nil
        }

        mutating func setAdjustmentPreviewPixelData(_ pixelData: Data?) {
            adjustmentPreviewPixelData = pixelData
        }

        mutating func resetTransientEditingState() {
            clearSelectionState()
            clearAdjustmentPreview()
            activeStroke = nil
            pendingCommittedSnapshot = nil
            pendingPreviewIncrementalUpdates = []
            strokeSession.resetCommittedPointCount()
            shapePreviewIsLive = false
            isStrokeActive = false
            isAwaitingCommittedRender = false
            resetStrokePreview()
        }

        mutating func captureStrokeBaseSnapshot(_ snapshot: MetalDocumentSnapshot) {
            strokeSession.captureBaseSnapshot(snapshot)
        }

        mutating func stagePendingCommittedSnapshot(_ snapshot: MetalDocumentSnapshot?) {
            pendingCommittedSnapshot = snapshot
        }

        mutating func stagePendingCommittedStrokeSnapshot(
            baseSnapshot: MetalDocumentSnapshot,
            surface: GpuLayerSurface
        ) {
            guard surface.width == baseSnapshot.width,
                  surface.height == baseSnapshot.height
            else {
                return
            }
            let surfaceCanRepresentComposite = surface.pixelData == nil &&
                singleVisibleNormalActiveLayer(baseSnapshot: baseSnapshot, layerIndex: surface.layerIndex) != nil
            guard let compositePixelData = committedStrokeCompositePixelData(
                baseSnapshot: baseSnapshot,
                surface: surface,
                committedLayerPixelData: surface.pixelData
            ) else {
                return
            }
            let layers = baseSnapshot.layers.map { layer in
                guard layer.index == surface.layerIndex else { return layer }
                return MetalLayerSnapshot(
                    validatingIndex: layer.index,
                    opacity: layer.opacity,
                    visible: layer.visible,
                    isClipped: layer.isClipped,
                    blendMode: layer.blendMode,
                    canvasWidth: baseSnapshot.width,
                    canvasHeight: baseSnapshot.height,
                    thumbnailSurface: layer.thumbnailSurface,
                    thumbnailData: layer.thumbnailData,
                    gpuBufferHandle: surface.pixelData == nil ? surface.handle.buffer : nil,
                    pixelData: surface.pixelData ?? layer.pixelData
                ) ?? layer
            }
            pendingCommittedSnapshot = MetalDocumentSnapshot(
                validatingWidth: baseSnapshot.width,
                height: baseSnapshot.height,
                revision: max(baseSnapshot.revision, lastCommittedRenderRevision) + 1,
                transferKind: .fullSnapshot,
                compositeBufferHandle: surfaceCanRepresentComposite ? surface.handle.buffer : nil,
                compositePixelData: surfaceCanRepresentComposite ? Data() : compositePixelData,
                layers: layers
            )
        }

        private func committedStrokeCompositePixelData(
            baseSnapshot: MetalDocumentSnapshot,
            surface: GpuLayerSurface,
            committedLayerPixelData: Data?
        ) -> Data? {
            let expectedByteCount = baseSnapshot.width * baseSnapshot.height * 4
            if let stagedComposite = stagedPreviewCompositePixelData(baseSnapshot: baseSnapshot),
               stagedComposite.count == expectedByteCount {
                return stagedComposite
            }
            if baseSnapshot.compositePixelData.count == expectedByteCount {
                return baseSnapshot.compositePixelData
            }
            guard let committedLayerPixelData else {
                return singleVisibleNormalActiveLayer(
                    baseSnapshot: baseSnapshot,
                    layerIndex: surface.layerIndex
                ) == nil ? nil : Data(count: expectedByteCount)
            }
            return singleLayerCommittedCompositePixelData(
                baseSnapshot: baseSnapshot,
                surface: surface,
                committedLayerPixelData: committedLayerPixelData,
                expectedByteCount: expectedByteCount
            )
        }

        private func singleLayerCommittedCompositePixelData(
            baseSnapshot: MetalDocumentSnapshot,
            surface: GpuLayerSurface,
            committedLayerPixelData: Data,
            expectedByteCount: Int
        ) -> Data? {
            guard committedLayerPixelData.count == expectedByteCount else { return nil }
            let visibleLayers = baseSnapshot.layers.filter(\.visible)
            guard visibleLayers.count == 1,
                  let activeLayer = visibleLayers.first,
                  activeLayer.index == surface.layerIndex,
                  activeLayer.blendMode == .normal,
                  activeLayer.opacity >= 0.999,
                  !activeLayer.isClipped
            else {
                return nil
            }
            return committedLayerPixelData
        }

        private func singleVisibleNormalActiveLayer(
            baseSnapshot: MetalDocumentSnapshot,
            layerIndex: Int
        ) -> MetalLayerSnapshot? {
            let visibleLayers = baseSnapshot.layers.filter(\.visible)
            guard visibleLayers.count == 1,
                  let activeLayer = visibleLayers.first,
                  activeLayer.index == layerIndex,
                  activeLayer.blendMode == .normal,
                  activeLayer.opacity >= 0.999,
                  !activeLayer.isClipped
            else {
                return nil
            }
            return activeLayer
        }

        mutating func setActiveStrokeRenderState(_ renderState: StrokeSessionRenderState?) {
            strokeSession.replaceRenderState(renderState)
        }

        mutating func setPendingIncrementalUpdate(_ update: IncrementalLayerUpdate?) {
            strokeSession.replacePendingIncrementalUpdate(update)
            pendingPreviewIncrementalUpdates = update.map { [$0] } ?? []
        }

        mutating func clearPendingIncrementalUpdate() {
            strokeSession.replacePendingIncrementalUpdate(nil)
            pendingPreviewIncrementalUpdates = []
        }

        mutating func applyIncrementalRenderUpdate(_ update: IncrementalLayerUpdate) {
            setPendingIncrementalUpdate(update)
        }

        mutating func recordPreviewIncrementalUpdate(
            _ update: IncrementalLayerUpdate?,
            previousRenderState: StrokeSessionRenderState?,
            baseSnapshot: MetalDocumentSnapshot,
            surface: GpuLayerSurface,
            previewBrush: BrushRuntimeSettings?,
            sampleCount: Int
        ) {
            guard let update else {
                pendingPreviewIncrementalUpdates = []
                return
            }
            if canAccumulatePreviewIncrementalUpdate(
                previousRenderState: previousRenderState,
                baseSnapshot: baseSnapshot,
                surface: surface,
                previewBrush: previewBrush,
                sampleCount: sampleCount
            ) {
                appendPendingPreviewIncrementalUpdate(update, baseSnapshot: baseSnapshot)
            } else {
                pendingPreviewIncrementalUpdates = [update]
            }
        }

        func stagedPreviewCompositePixelData(baseSnapshot: MetalDocumentSnapshot) -> Data? {
            guard !pendingPreviewIncrementalUpdates.isEmpty else { return nil }
            var compositePixelData = baseSnapshot.compositePixelData
            for update in pendingPreviewIncrementalUpdates {
                guard let nextCompositePixelData = Self.replacingCompositeRegion(
                    in: compositePixelData,
                    canvasWidth: baseSnapshot.width,
                    canvasHeight: baseSnapshot.height,
                    update: update
                ) else {
                    return nil
                }
                compositePixelData = nextCompositePixelData
            }
            return compositePixelData
        }

        mutating func applyCommittedRenderSnapshot(
            _ renderSnapshot: MetalDocumentSnapshot,
            previousRevision: Int
        ) {
            self.renderSnapshot = renderSnapshot
            pendingCommittedSnapshot = nil
            lastCommittedRenderRevision = renderSnapshot.revision
            if !isStrokeActive {
                resetStrokePreview()
            }
            if !isStrokeActive &&
                isAwaitingCommittedRender &&
                renderSnapshot.revision > previousRevision {
                isAwaitingCommittedRender = false
                lastRenderedLocalBufferRevision = localBufferRevision
            }
        }

        mutating func applyPreviewRenderSnapshot(_ renderSnapshot: MetalDocumentSnapshot) {
            guard let update = IncrementalLayerUpdate(
                validatingID: UUID(),
                layerIndex: -1,
                originX: 0,
                originY: 0,
                width: renderSnapshot.width,
                height: renderSnapshot.height,
                pixelData: renderSnapshot.compositePixelData
            ) else { return }
            applyIncrementalRenderUpdate(update)
        }

        mutating func resetStrokePreview() {
            if !isAwaitingCommittedRender {
                previewResetNonce += 1
            }
            strokeSession.resetPreview()
            clearPendingIncrementalUpdate()
        }
        mutating func setActiveTextLayer(_ textLayer: TextLayerData?) {
            activeTextLayer = textLayer
        }

        mutating func updateInteractionModes(
            selectionMode: SelectionToolMode,
            shapeMode: ShapeToolMode,
            eyedropperSamplingSource: EyedropperSamplingSource
        ) {
            self.selectionMode = selectionMode
            self.shapeMode = shapeMode
            self.eyedropperSamplingSource = eyedropperSamplingSource
        }

        mutating func updateInteractionStyle(
            previewStyle: PreviewStrokeStyle,
            paperStyle: CanvasPaperStyle
        ) {
            self.previewStyle = previewStyle
            self.paperStyle = paperStyle
        }

        mutating func updatePreviewStyle(_ previewStyle: PreviewStrokeStyle) {
            self.previewStyle = previewStyle
        }

        mutating func updatePaperStyle(_ paperStyle: CanvasPaperStyle) {
            self.paperStyle = paperStyle
        }

        mutating func discardBufferedStrokes(
            for layerIndex: Int,
            incrementsRevision: Bool = false
        ) {
            guard let bufferIndex = layerBuffers.firstIndex(where: { $0.index == layerIndex }) else {
                return
            }
            layerBuffers[bufferIndex].strokes.removeAll()
            if incrementsRevision {
                localBufferRevision += 1
            }
        }

        mutating func finalizeLayerMutation(
            at layerIndex: Int,
            incrementsRevision: Bool = false,
            clearsSelection: Bool = true
        ) {
            discardBufferedStrokes(for: layerIndex, incrementsRevision: incrementsRevision)
            if clearsSelection {
                clearSelection()
            }
        }

        private static func replacingCompositeRegion(
            in compositePixelData: Data,
            canvasWidth: Int,
            canvasHeight: Int,
            update: IncrementalLayerUpdate
        ) -> Data? {
            guard compositePixelData.count == canvasWidth * canvasHeight * 4 else { return nil }
            guard !update.isEmpty else { return compositePixelData }
            guard
                update.originX >= 0,
                update.originY >= 0,
                update.originX + update.width <= canvasWidth,
                update.originY + update.height <= canvasHeight,
                update.pixelData.count == update.width * update.height * 4
            else {
                return nil
            }

            var nextComposite = compositePixelData
            nextComposite.withUnsafeMutableBytes { destinationBytes in
                update.pixelData.withUnsafeBytes { sourceBytes in
                    guard
                        let destinationBase = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        let sourceBase = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                    else {
                        return
                    }

                    for row in 0..<update.height {
                        let sourceOffset = row * update.width * 4
                        let destinationOffset = ((update.originY + row) * canvasWidth + update.originX) * 4
                        memcpy(destinationBase + destinationOffset, sourceBase + sourceOffset, update.width * 4)
                    }
                }
            }
            return nextComposite
        }

        private mutating func appendPendingPreviewIncrementalUpdate(
            _ update: IncrementalLayerUpdate,
            baseSnapshot: MetalDocumentSnapshot
        ) {
            pendingPreviewIncrementalUpdates.append(update)
            guard pendingPreviewIncrementalUpdates.count > Self.maxPendingPreviewIncrementalUpdateCount else {
                return
            }
            if let compacted = compactedPreviewIncrementalUpdate(baseSnapshot: baseSnapshot) {
                pendingPreviewIncrementalUpdates = [compacted]
            } else {
                pendingPreviewIncrementalUpdates = Array(
                    pendingPreviewIncrementalUpdates.suffix(Self.maxPendingPreviewIncrementalUpdateCount)
                )
            }
        }

        private func compactedPreviewIncrementalUpdate(baseSnapshot: MetalDocumentSnapshot) -> IncrementalLayerUpdate? {
            guard let compositePixelData = stagedPreviewCompositePixelData(baseSnapshot: baseSnapshot),
                  let unionRect = pendingPreviewIncrementalUpdates.reduce(nil, { partial, update in
                      Self.union(partial, update)
                  }),
                  let croppedPixelData = Self.croppedCompositeRegion(
                      in: compositePixelData,
                      canvasWidth: baseSnapshot.width,
                      canvasHeight: baseSnapshot.height,
                      rect: unionRect
                  )
            else {
                return nil
            }
            return IncrementalLayerUpdate(
                validatingID: UUID(),
                layerIndex: -1,
                originX: unionRect.originX,
                originY: unionRect.originY,
                width: unionRect.width,
                height: unionRect.height,
                pixelData: croppedPixelData
            )
        }

        private static func croppedCompositeRegion(
            in compositePixelData: Data,
            canvasWidth: Int,
            canvasHeight: Int,
            rect: LayerPixelRect
        ) -> Data? {
            guard compositePixelData.count == canvasWidth * canvasHeight * 4 else { return nil }
            guard !rect.isEmpty,
                  rect.originX >= 0,
                  rect.originY >= 0,
                  rect.originX + rect.width <= canvasWidth,
                  rect.originY + rect.height <= canvasHeight
            else {
                return nil
            }
            var output = Data(count: rect.width * rect.height * 4)
            output.withUnsafeMutableBytes { destinationBytes in
                compositePixelData.withUnsafeBytes { sourceBytes in
                    guard
                        let destinationBase = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        let sourceBase = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                    else {
                        return
                    }
                    for row in 0..<rect.height {
                        let sourceOffset = ((rect.originY + row) * canvasWidth + rect.originX) * 4
                        let destinationOffset = row * rect.width * 4
                        memcpy(destinationBase + destinationOffset, sourceBase + sourceOffset, rect.width * 4)
                    }
                }
            }
            return output
        }

        private static func union(_ lhs: LayerPixelRect?, _ rhs: IncrementalLayerUpdate) -> LayerPixelRect? {
            guard !rhs.isEmpty else { return lhs }
            guard let rhsRect = LayerPixelRect(
                validatingOriginX: rhs.originX,
                originY: rhs.originY,
                width: rhs.width,
                height: rhs.height
            ) else { return lhs }
            guard let lhs else { return rhsRect }
            let minX = min(lhs.originX, rhsRect.originX)
            let minY = min(lhs.originY, rhsRect.originY)
            let maxX = max(lhs.originX + lhs.width, rhsRect.originX + rhsRect.width)
            let maxY = max(lhs.originY + lhs.height, rhsRect.originY + rhsRect.height)
            return LayerPixelRect(
                validatingOriginX: minX,
                originY: minY,
                width: Swift.max(0, maxX - minX),
                height: Swift.max(0, maxY - minY)
            )
        }

        private func canAccumulatePreviewIncrementalUpdate(
            previousRenderState: StrokeSessionRenderState?,
            baseSnapshot: MetalDocumentSnapshot,
            surface: GpuLayerSurface,
            previewBrush: BrushRuntimeSettings?,
            sampleCount: Int
        ) -> Bool {
            guard let previousRenderState else { return false }
            return previousRenderState.baseRevision == baseSnapshot.revision &&
                previousRenderState.layerIndex == surface.layerIndex &&
                previousRenderState.previewBrush == previewBrush &&
                previousRenderState.sampleCount <= sampleCount
        }
    }

    enum Action: Equatable {
        case strokeUpdated(Stroke)
        case strokeEnded(Stroke)
        case strokeCancelled
        case pencilInteractionToggleRequested
        case fillRequested(StylusSample)
        case colorSampled(SampledColor)
        case selectionPreviewUpdated([CGPoint])
        case selectionPathEnded([CGPoint])
        case selectionMoveBegan(CGPoint)
        case selectionMoveUpdated(CGSize)
        case selectionMoveEnded(CGSize)
        case selectionMoveCancelled
        case autoSelectionRequested(StylusSample)
        case textPlacementRequested(CGPoint)
        case selectionUpdated(CanvasSelection?)
        case requestLocalUndo
        case requestLocalRedo
        case viewportOffsetChanged(CGSize)
        case zoomScaleChanged(CGFloat)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case beginStroke(StylusSample)
        case appendSamples([StylusSample])
        case previewShapeStroke([StylusSample])
        case endStroke([StylusSample])
        case cancelStroke
        case commitStroke([StylusSample])
        case blurSamples([StylusSample])
        case endBlurStroke
        case cancelBlurStroke
        case fill(StylusSample)
        case lassoSelect([CGPoint])
        case previewSelectionMove(CGSize)
        case applySelectionMove(CGSize)
        case cancelSelectionMove
        case autoSelect(StylusSample)
        case placeText(CGPoint)
        case toggleBrushAndEraser
        case requestUndo
        case requestRedo
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .fillRequested(sample):
                return .send(.delegate(.fill(sample)))

            case .pencilInteractionToggleRequested:
                return .send(.delegate(.toggleBrushAndEraser))

            case .colorSampled:
                return .none

            case let .selectionPreviewUpdated(points):
                state.selectionPreviewPoints = points
                return .none

            case let .selectionPathEnded(points):
                state.clearSelectionPreview()
                return .send(.delegate(.lassoSelect(points)))

            case let .selectionMoveBegan(point):
                state.beginSelectionMove(at: point)
                return .none

            case let .selectionMoveUpdated(offset):
                state.updateSelectionMove(offset: offset)
                return .send(.delegate(.previewSelectionMove(offset)))

            case let .selectionMoveEnded(offset):
                state.updateSelectionMove(offset: offset)
                return .send(.delegate(.applySelectionMove(offset)))

            case .selectionMoveCancelled:
                state.cancelSelectionMove()
                return .send(.delegate(.cancelSelectionMove))

            case let .autoSelectionRequested(sample):
                state.clearSelectionPreview()
                return .send(.delegate(.autoSelect(sample)))

            case let .textPlacementRequested(point):
                return .send(.delegate(.placeText(point)))

            case let .selectionUpdated(selection):
                state.replaceSelection(selection)
                return .none

            case .requestLocalUndo:
                state.cancelSelectionMove()
                return .send(.delegate(.requestUndo))

            case .requestLocalRedo:
                state.cancelSelectionMove()
                return .send(.delegate(.requestRedo))

            case let .viewportOffsetChanged(offset):
                state.viewportOffset = offset
                return .none

            case let .zoomScaleChanged(scale):
                state.zoomScale = min(max(scale, 0.6), 4.0)
                return .none

            case let .strokeUpdated(stroke):
                state.isStrokeActive = true
                state.isAwaitingCommittedRender = false
                if state.currentTool == .shape {
                    state.activeStroke = nil
                    guard stroke.points.count >= 2 else { return .none }
                    state.shapePreviewIsLive = true
                    return .send(.delegate(.previewShapeStroke(stroke.points.map(\.stylusSample))))
                }

                let previousStroke = state.activeStroke
                let previousPointCount = previousStroke?.points.count ?? 0
                state.activeStroke = stroke
                let previousLastSample = previousStroke?.points.last?.stylusSample
                let appendedSamples = Self.trimmingDuplicateLeadingSamples(
                    Array(stroke.points.dropFirst(previousPointCount)).map(\.stylusSample),
                    after: previousLastSample
                )
                if state.currentTool == .blur {
                    guard !appendedSamples.isEmpty else { return .none }
                    return .send(.delegate(.blurSamples(appendedSamples)))
                }
                if state.strokeSession.committedPointCount == 0 {
                    guard let firstPoint = stroke.points.first else { return .none }
                    state.strokeSession.markCommittedPointCount(stroke.points.count)
                    var effects: [Effect<Action>] = [
                        .send(.delegate(.beginStroke(firstPoint.stylusSample)))
                    ]
                    let remainder = Array(stroke.points.dropFirst()).map(\.stylusSample)
                    if !remainder.isEmpty {
                        effects.append(.send(.delegate(.appendSamples(remainder))))
                    }
                    return .concatenate(effects)
                }

                state.strokeSession.markCommittedPointCount(stroke.points.count)
                guard !appendedSamples.isEmpty else { return .none }
                return .send(.delegate(.appendSamples(appendedSamples)))

            case let .strokeEnded(stroke):
                state.isStrokeActive = false
                state.isAwaitingCommittedRender = true
                if state.currentTool == .shape {
                    let samples = stroke.points.map(\.stylusSample)
                    state.activeStroke = nil
                    state.strokeSession.resetCommittedPointCount()
                    state.shapePreviewIsLive = false
                    guard samples.count >= 2 else {
                        state.isAwaitingCommittedRender = false
                        return .none
                    }
                    return .send(.delegate(.commitStroke(samples)))
                }
                if state.currentTool == .blur {
                    state.activeStroke = nil
                    state.strokeSession.resetCommittedPointCount()
                    return .send(.delegate(.endBlurStroke))
                }
                let previousStroke = state.activeStroke
                let previousPointCount = previousStroke?.points.count ?? 0
                let previousLastSample = previousStroke?.points.last?.stylusSample
                let appendedSamples = Self.trimmingDuplicateLeadingSamples(
                    Array(stroke.points.dropFirst(previousPointCount)).map(\.stylusSample),
                    after: previousLastSample
                )
                let finalSamples = Self.trimmingDuplicateTrailingSamples(
                    stroke.points.map(\.stylusSample)
                )
                state.activeStroke = stroke
                let didCommitStroke = state.strokeSession.hasCommittedPoints
                state.strokeSession.resetCommittedPointCount()
                if didCommitStroke {
                    var effects: [Effect<Action>] = []
                    if !appendedSamples.isEmpty {
                        effects.append(.send(.delegate(.appendSamples(appendedSamples))))
                    }
                    effects.append(.send(.delegate(.endStroke(finalSamples))))
                    return .concatenate(effects)
                }
                if !finalSamples.isEmpty {
                    return .send(.delegate(.commitStroke(finalSamples)))
                }
                state.activeStroke = nil
                return .none

            case .strokeCancelled:
                let cancelledStroke = state.activeStroke
                state.isStrokeActive = false
                state.isAwaitingCommittedRender = false
                state.activeStroke = nil
                let didCommitStroke = state.strokeSession.hasCommittedPoints
                state.strokeSession.resetCommittedPointCount()
                state.shapePreviewIsLive = false
                if state.currentTool == .blur {
                    return .send(.delegate(.cancelBlurStroke))
                }
                if state.currentTool == .brush || state.currentTool == .erase,
                   didCommitStroke,
                   let cancelledStroke,
                   !cancelledStroke.points.isEmpty {
                    return .send(.delegate(.commitStroke(cancelledStroke.points.map(\.stylusSample))))
                }
                return .send(.delegate(.cancelStroke))

            case .delegate:
                return .none
            }
        }
    }

}
