import ComposableArchitecture
import CoreGraphics
import Foundation
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts
import PrimoDocumentRuntime

extension CanvasEditingWorkflowReducer {
    func handleInvertSelection(state: inout State) {
        state.canvas.replaceSelection(
            selectionWorkflowService.invertedSelection(
                state.canvas.selection,
                canvasSize: state.canvas.canvasSize,
                mode: state.canvas.selectionMode
            )
        )
    }

    func handleAdjustSelection(
        state: inout State,
        expansion: Int
    ) {
        guard state.canvas.selection != nil else { return }
        state.canvas.replaceSelection(
            selectionWorkflowService.adjustedSelection(
                state.canvas.selection,
                canvasSize: state.canvas.canvasSize,
                expansion: expansion,
                isInverted: false
            )
        )
    }

    func handleFeatherSelection(
        state: inout State,
        radius: Int
    ) {
        guard state.canvas.selection != nil else { return }
        state.canvas.replaceSelection(
            selectionWorkflowService.featheredSelection(
                state.canvas.selection,
                canvasSize: state.canvas.canvasSize,
                radius: radius
            )
        )
    }

    func handleColorRangeSelectionRequest(
        state: inout State,
        request: ColorRangeSelectionRequest
    ) -> Effect<Action> {
        guard
            case let .success(activeLayerIndex) = documentWorkflowCommandValidator.existingLayerIndex(
                state.canvas.activeLayerIndex,
                in: state
            )
        else {
            return .none
        }
        let incomingSelection = selectionWorkflowService.makeColorRangeSelection(
            request: request,
            snapshot: state.canvas.renderSnapshot,
            activeLayerIndex: activeLayerIndex,
            mode: state.canvas.selectionMode
        )
        let selection = selectionWorkflowService.combinedSelection(
            existing: state.canvas.selection,
            incoming: incomingSelection,
            mode: state.brushPalette.selection.combineMode,
            canvasSize: state.canvas.canvasSize
        )
        state.canvas.replaceSelection(selection)
        return .none
    }

    func handleLassoSelection(
        state: inout State,
        points: [CGPoint]
    ) -> Effect<Action> {
        let incomingSelection: CanvasSelection?
        switch state.canvas.selectionMode {
        case .rectangle:
            guard let startPoint = points.first, let endPoint = points.last else { return .none }
            incomingSelection = selectionWorkflowService.makeRectangleSelection(
                from: startPoint,
                to: endPoint,
                canvasSize: state.canvas.canvasSize
            )
        case .lasso:
            incomingSelection = selectionWorkflowService.makeLassoSelection(
                from: points,
                canvasSize: state.canvas.canvasSize
            )
        case .auto:
            incomingSelection = nil
        }
        let selection = selectionWorkflowService.combinedSelection(
            existing: state.canvas.selection,
            incoming: incomingSelection,
            mode: state.brushPalette.selection.combineMode,
            canvasSize: state.canvas.canvasSize
        )
        state.canvas.replaceSelection(selection)
        return .none
    }

    func handleAutoSelection(
        state: inout State,
        sample: StylusSample
    ) -> Effect<Action> {
        guard
            case let .success(activeLayerIndex) = documentWorkflowCommandValidator.existingLayerIndex(
                state.canvas.activeLayerIndex,
                in: state
            )
        else {
            return .none
        }
        let incomingSelection = selectionWorkflowService.makeAutoSelection(
            at: sample.point,
            snapshot: state.canvas.renderSnapshot,
            layerIndex: activeLayerIndex,
            thresholdMode: state.brushPalette.selection.thresholdMode,
            opacityTolerance: state.brushPalette.selection.opacityTolerance,
            colorTolerance: state.brushPalette.selection.colorTolerance,
            expansion: Int(state.brushPalette.selection.expansion.rounded())
        )
        let selection = selectionWorkflowService.combinedSelection(
            existing: state.canvas.selection,
            incoming: incomingSelection,
            mode: state.brushPalette.selection.combineMode,
            canvasSize: state.canvas.canvasSize
        )
        state.canvas.replaceSelection(selection)
        return .none
    }

    func handlePreviewSelectionMove(
        state: inout State,
        offset: CGSize
    ) -> Effect<Action> {
        guard canMoveActiveSelection(in: state) else {
            state.canvas.cancelSelectionMove()
            state.canvas.resetStrokePreview()
            return .none
        }
        let roundedOffset = CGSize(width: offset.width.rounded(), height: offset.height.rounded())
        guard abs(roundedOffset.width) >= 0.5 || abs(roundedOffset.height) >= 0.5 else {
            state.canvas.resetStrokePreview()
            return .none
        }
        let selection = state.canvas.selectionMoveSourceSelection ?? state.canvas.selection
        guard selection != nil else {
            return handlePreviewLayerMoveWithTransform(state: &state, offset: roundedOffset)
        }
        guard
            let session = selectionMoveSession(in: &state),
            let movedLayerPixels = compositedSelectionMovePixels(session: session, offset: roundedOffset),
            let baseSnapshot = state.canvas.selectionMoveBaseSnapshot ?? state.canvas.renderSnapshot,
            let composite = documentRenderingWorkflow.compositedPreviewPixelData(
                baseSnapshot,
                session.layerIndex,
                movedLayerPixels
            ).value,
            let update = IncrementalLayerUpdate(
                validatingID: UUID(),
                layerIndex: -1,
                originX: 0,
                originY: 0,
                width: baseSnapshot.width,
                height: baseSnapshot.height,
                transferKind: .fullSnapshot,
                pixelData: composite
            )
        else {
            state.canvas.resetStrokePreview()
            return .none
        }

        state.canvas.selectionMoveOffset = roundedOffset
        state.canvas.applyIncrementalRenderUpdate(update)
        return .none
    }

    func handleApplySelectionMove(
        state: inout State,
        offset: CGSize
    ) -> Effect<Action> {
        guard canMoveActiveSelection(in: state) else {
            state.canvas.cancelSelectionMove()
            state.canvas.resetStrokePreview()
            return .none
        }
        let roundedOffset = CGSize(width: offset.width.rounded(), height: offset.height.rounded())
        guard roundedOffset != .zero else {
            state.canvas.cancelSelectionMove()
            state.canvas.resetStrokePreview()
            return .none
        }
        let selection = state.canvas.selectionMoveSourceSelection ?? state.canvas.selection
        guard let selection else {
            return handleApplyLayerMoveWithTransform(state: &state, offset: roundedOffset)
        }
        guard let session = selectionMoveSession(in: &state) else {
            state.canvas.cancelSelectionMove()
            state.canvas.resetStrokePreview()
            return .none
        }

        let translatedSelection = translatedSelection(
            selection,
            by: roundedOffset,
            canvasWidth: session.canvasWidth,
            canvasHeight: session.canvasHeight
        )
        let committedOffset = CGSize(
            width: translatedSelection.bounds.minX - selection.bounds.minX,
            height: translatedSelection.bounds.minY - selection.bounds.minY
        )
        guard
            let movedLayerPixels = compositedSelectionMovePixels(session: session, offset: committedOffset),
            movedLayerPixels.containsOpaquePixel
        else {
            state.canvas.cancelSelectionMove()
            state.canvas.resetStrokePreview()
            return .none
        }

        let command: ValidatedLayerContentReplacementCommand
        switch documentWorkflowCommandValidator.editableLayerCommand(
            index: session.layerIndex,
            in: state
        ) {
        case let .success(layer):
            guard let pixelData = LayerPixelData(
                width: session.canvasWidth,
                height: session.canvasHeight,
                rgba: movedLayerPixels
            ) else {
                state.canvas.cancelSelectionMove()
                state.canvas.resetStrokePreview()
                return documentMutationFeedbackEffect(
                    for: DocumentMutationFeedbackMapper().feedback(
                        for: .gpu(
                            .invalidPayloadSize(
                                operation: "selectionMoveCommit",
                                expected: session.canvasWidth * session.canvasHeight * 4,
                                actual: movedLayerPixels.count
                            )
                        )
                    )
                )
            }
            command = ValidatedLayerContentReplacementCommand(
                layer: layer,
                pixelData: pixelData
            )

        case let .failure(failure):
            state.canvas.cancelSelectionMove()
            state.canvas.resetStrokePreview()
            return documentMutationFeedbackEffect(
                for: DocumentMutationFeedbackMapper().feedback(for: failure)
            )
        }

        switch documentContentService.replaceLayerPixels(command) {
        case .success:
            let retainedSession = session.committed(by: committedOffset)
            state.canvas.replaceSelection(translatedSelection)
            state.canvas.retainedSelectionMoveSession = retainedSession
            return completeDocumentMutation(
                state: &state,
                contract: DocumentMutationContract(
                    canvasMutation: .finalizeLayer(
                        LayerMutationFinalization(
                            index: session.layerIndex,
                            incrementsRevision: true,
                            clearsSelection: false
                        )
                    )
                )
            )

        case let .failure(failure):
            state.canvas.cancelSelectionMove()
            state.canvas.resetStrokePreview()
            return documentMutationFeedbackEffect(
                for: DocumentMutationFeedbackMapper().feedback(for: failure)
            )
        }
    }

    func handleCancelSelectionMove(state: inout State) -> Effect<Action> {
        state.canvas.cancelSelectionMove()
        state.canvas.resetStrokePreview()
        return .none
    }

    private func handlePreviewLayerMoveWithTransform(
        state: inout State,
        offset: CGSize
    ) -> Effect<Action> {
        let baseSnapshot = state.canvas.selectionMoveBaseSnapshot ?? state.canvas.renderSnapshot
        guard
            let baseSnapshot,
            let layer = baseSnapshot.layers.first(where: { $0.index == state.canvas.activeLayerIndex }),
            let sourceSurface = RgbaSurface(width: baseSnapshot.width, height: baseSnapshot.height, data: layer.pixelData),
            let transformedPixels = layerTransformProcessor.transformedLayerPixels(
                source: sourceSurface,
                selection: state.canvas.selectionMoveSourceSelection ?? state.canvas.selection,
                translation: offset,
                scaleX: 1,
                scaleY: 1,
                rotationDegrees: 0,
                pivot: nil,
                mode: .standard,
                quadOffsets: .zero
            )
        else {
            state.canvas.resetStrokePreview()
            return .none
        }

        DocumentFeature.canvasPreviewStateCoordinator.applyLiveStrokePreview(
            baseSnapshot: baseSnapshot,
            activeLayerIndex: state.canvas.activeLayerIndex,
            adjustedActiveLayerPixels: transformedPixels,
            gpuOperations: documentRenderingWorkflow,
            to: &state
        )
        return .none
    }

    private func handleApplyLayerMoveWithTransform(
        state: inout State,
        offset: CGSize
    ) -> Effect<Action> {
        defer {
            state.canvas.cancelSelectionMove()
        }
        guard canMoveActiveSelection(in: state) else {
            state.canvas.resetStrokePreview()
            return .none
        }
        let roundedOffset = CGSize(width: offset.width.rounded(), height: offset.height.rounded())
        guard roundedOffset != .zero else {
            state.canvas.resetStrokePreview()
            return .none
        }
        let selection = state.canvas.selectionMoveSourceSelection ?? state.canvas.selection

        let outcome = canvasEditingWorkflowService.execute(
            .applyTransform,
            state: CanvasEditingContext(
                transformHasPreview: true,
                transformPreviewOffset: roundedOffset,
                transformPreviewScaleX: 1,
                transformPreviewScaleY: 1,
                transformPreviewRotationDegrees: 0,
                transformMode: .standard,
                transformPivot: nil,
                transformQuadOffsets: .zero,
                activeLayerIndex: state.canvas.activeLayerIndex,
                activeTextLayer: state.canvas.activeTextLayer,
                selection: selection,
                canvasSize: state.canvas.canvasSize
            )
        )

        switch outcome {
        case let .appliedPixelTransform(layerIndex, transformedSelection):
            state.canvas.replaceSelection(transformedSelection)
            return completeDocumentMutation(
                state: &state,
                contract: DocumentMutationContract(
                    canvasMutation: .finalizeLayer(
                        LayerMutationFinalization(
                            index: layerIndex,
                            incrementsRevision: true,
                            clearsSelection: false
                        )
                    )
                )
            )
        case .appliedTextTransform:
            return completeDocumentMutation(state: &state)
        case .noPreview, .resetTransformPreview:
            state.canvas.resetStrokePreview()
            return .none
        case let .failure(failure):
            state.canvas.resetStrokePreview()
            return documentMutationFeedbackEffect(
                for: DocumentMutationFeedbackMapper().feedback(for: failure)
            )
        }
    }

    private func canMoveActiveSelection(in state: State) -> Bool {
        guard state.canvas.selection != nil || state.canvas.selectionMoveStartPoint != nil else { return false }
        guard let layer = state.canvas.layerBuffers.first(where: { $0.index == state.canvas.activeLayerIndex }) else {
            return false
        }
        let layerRow = state.layerSidebar.layer(withIndex: state.canvas.activeLayerIndex)
        return layer.visible && !(layerRow?.isLocked ?? false)
    }

    private func selectionMoveSession(in state: inout State) -> CanvasSelectionMoveSession? {
        if let session = state.canvas.selectionMoveSession {
            return session
        }
        guard
            let selection = state.canvas.selectionMoveSourceSelection ?? state.canvas.selection,
            let snapshot = state.canvas.selectionMoveBaseSnapshot ?? state.canvas.renderSnapshot
        else {
            return nil
        }
        if let retained = state.canvas.retainedSelectionMoveSession,
           retained.layerIndex == state.canvas.activeLayerIndex,
           retained.canvasWidth == snapshot.width,
           retained.canvasHeight == snapshot.height {
            state.canvas.selectionMoveSession = retained
            return retained
        }

        let sourcePixels: Data
        let activeLayerIndex: ExistingLayerIndex
        switch DocumentWorkflowCommandValidator().existingLayerIndex(state.canvas.activeLayerIndex, in: state) {
        case let .success(index):
            activeLayerIndex = index
        case .failure:
            return nil
        }
        switch documentContentService.pixelDataForLayer(activeLayerIndex) {
        case let .success(pixelData):
            sourcePixels = pixelData.rgba
        case .failure:
            return nil
        }
        guard let session = makeSelectionMoveSession(
            source: sourcePixels,
            canvasWidth: snapshot.width,
            canvasHeight: snapshot.height,
            layerIndex: state.canvas.activeLayerIndex,
            selection: selection
        ) else {
            return nil
        }
        state.canvas.selectionMoveSession = session
        return session
    }

    private func makeSelectionMoveSession(
        source: Data,
        canvasWidth: Int,
        canvasHeight: Int,
        layerIndex: Int,
        selection: CanvasSelection
    ) -> CanvasSelectionMoveSession? {
        let expectedCount = canvasWidth * canvasHeight * 4
        guard source.count == expectedCount else { return nil }
        guard
            let canvasGeometry = PixelGeometry(width: canvasWidth, height: canvasHeight),
            let selectedMask = selectionWorkflowService.expandedMask(
                from: selection,
                canvasGeometry: canvasGeometry
            )
        else {
            return nil
        }
        let selectedMaskData = [UInt8](selectedMask.data)

        var basePixels = source
        var payloadPixels = Data(repeating: 0, count: expectedCount)
        var hasPayload = false

        source.withUnsafeBytes { sourceBytes in
            basePixels.withUnsafeMutableBytes { baseBytes in
                payloadPixels.withUnsafeMutableBytes { payloadBytes in
                    guard
                        let sourceBase = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        let base = baseBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        let payload = payloadBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                    else {
                        return
                    }

                    for pixelIndex in selectedMaskData.indices where selectedMaskData[pixelIndex] > 0 {
                        let byteOffset = pixelIndex * 4
                        guard sourceBase[byteOffset + 3] > 0 else { continue }
                        payload[byteOffset] = sourceBase[byteOffset]
                        payload[byteOffset + 1] = sourceBase[byteOffset + 1]
                        payload[byteOffset + 2] = sourceBase[byteOffset + 2]
                        payload[byteOffset + 3] = sourceBase[byteOffset + 3]
                        base[byteOffset] = 0
                        base[byteOffset + 1] = 0
                        base[byteOffset + 2] = 0
                        base[byteOffset + 3] = 0
                        hasPayload = true
                    }
                }
            }
        }

        guard hasPayload else { return nil }
        return CanvasSelectionMoveSession(
            layerIndex: layerIndex,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            basePixels: basePixels,
            payloadPixels: payloadPixels,
            committedOffset: .zero
        )
    }

    private func compositedSelectionMovePixels(
        session: CanvasSelectionMoveSession,
        offset: CGSize
    ) -> Data? {
        let expectedCount = session.canvasWidth * session.canvasHeight * 4
        guard session.basePixels.count == expectedCount,
              session.payloadPixels.count == expectedCount
        else {
            return nil
        }

        let totalOffset = CGSize(
            width: session.committedOffset.width + offset.width,
            height: session.committedOffset.height + offset.height
        )
        let offsetX = Int(totalOffset.width.rounded())
        let offsetY = Int(totalOffset.height.rounded())
        var output = session.basePixels

        session.payloadPixels.withUnsafeBytes { payloadBytes in
            output.withUnsafeMutableBytes { outputBytes in
                guard
                    let payloadBase = payloadBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    let outputBase = outputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else {
                    return
                }
                for y in 0..<session.canvasHeight {
                    for x in 0..<session.canvasWidth {
                        let sourcePixelIndex = (y * session.canvasWidth) + x
                        let sourceByteOffset = sourcePixelIndex * 4
                        guard payloadBase[sourceByteOffset + 3] > 0 else { continue }
                        let destinationX = x + offsetX
                        let destinationY = y + offsetY
                        guard (0..<session.canvasWidth).contains(destinationX),
                              (0..<session.canvasHeight).contains(destinationY)
                        else {
                            continue
                        }
                        let destinationByteOffset = ((destinationY * session.canvasWidth) + destinationX) * 4
                        outputBase[destinationByteOffset] = payloadBase[sourceByteOffset]
                        outputBase[destinationByteOffset + 1] = payloadBase[sourceByteOffset + 1]
                        outputBase[destinationByteOffset + 2] = payloadBase[sourceByteOffset + 2]
                        outputBase[destinationByteOffset + 3] = payloadBase[sourceByteOffset + 3]
                    }
                }
            }
        }

        return output
    }

    private func translatedSelection(
        _ selection: CanvasSelection,
        by offset: CGSize,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> CanvasSelection {
        let proposedBounds = selection.bounds.offsetBy(dx: offset.width, dy: offset.height)
        let maxX = max(CGFloat(canvasWidth) - proposedBounds.width, 0)
        let maxY = max(CGFloat(canvasHeight) - proposedBounds.height, 0)
        let clampedBounds = CGRect(
            x: min(max(proposedBounds.minX, 0), maxX),
            y: min(max(proposedBounds.minY, 0), maxY),
            width: proposedBounds.width,
            height: proposedBounds.height
        )
        return CanvasSelection(
            validatingBounds: clampedBounds,
            maskWidth: selection.maskWidth,
            maskHeight: selection.maskHeight,
            maskData: selection.maskData,
            mode: selection.mode
        ) ?? selection
    }
}

private extension Data {
    var containsOpaquePixel: Bool {
        guard count >= 4 else { return false }
        return withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return false }
            var index = 3
            while index < count {
                if base[index] > 0 { return true }
                index += 4
            }
            return false
        }
    }
}
