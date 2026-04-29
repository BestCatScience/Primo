import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentStrokeApplication
import UIKit

extension DocumentFeature {
    static let canvasToolStateCoordinator = CanvasToolStateCoordinator()

    enum StrokeCommitResolution {
        case committed(DocumentMutationContract, transferredSurfaceHandle: MetalBufferHandle?)
        case failed(DocumentMutationFailure)
    }

    struct CanvasStrokeSessionCoordinator {
        let layerCommands: DocumentLayerCommandService
        let strokeInteraction: CanvasStrokeInteractionService

        func resolveAppendedStrokePreview(
            state: DocumentFeature.State,
            samples: [StylusSample],
            context: CanvasStrokeContext
        ) -> GpuStrokeSessionOutcome {
            strokeInteraction.appendPreview(
                baseSnapshot: state.canvas.strokeSession.baseSnapshot,
                renderSnapshot: state.canvas.renderSnapshot,
                renderState: state.canvas.strokeSession.renderState,
                samples: samples,
                fullSamples: state.canvas.activeStroke?.points.map(\.stylusSample) ?? samples,
                context: DocumentStrokeContext(
                    activeLayer: context.activeLayer,
                    activeLayerIndex: context.activeLayerIndex,
                    brush: context.brush,
                    previewBrush: context.previewBrush
                ),
                usesResponsiveOilPreview: usesResponsiveOilPreview(state: state, brush: context.previewBrush)
            )
        }

        func resolveShapeStrokePreview(
            state: DocumentFeature.State,
            samples: [StylusSample],
            context: CanvasStrokeContext
        ) -> GpuStrokeSessionOutcome {
            strokeInteraction.appendPreview(
                baseSnapshot: state.canvas.strokeSession.baseSnapshot,
                renderSnapshot: state.canvas.renderSnapshot,
                renderState: state.canvas.strokeSession.renderState,
                samples: samples,
                fullSamples: samples,
                context: DocumentStrokeContext(
                    activeLayer: context.activeLayer,
                    activeLayerIndex: context.activeLayerIndex,
                    brush: context.brush,
                    previewBrush: context.previewBrush
                ),
                usesResponsiveOilPreview: usesResponsiveOilPreview(state: state, brush: context.previewBrush)
            )
        }

        func resolveStrokeCommit(
            state: inout DocumentFeature.State,
            samples: [StylusSample],
            context: CanvasStrokeContext,
            keepsSelectionCleared: Bool,
            refreshViaDirtyPresentation: Bool
        ) -> StrokeCommitResolution {
            if keepsSelectionCleared {
                switch layerCommands.ensureLayerVisible(context.activeLayerIndex) {
                case .success:
                    state.canvas.clearSelection()
                case let .failure(failure):
                    return .failed(failure)
                }
            }

            let outcome = strokeInteraction.finish(
                renderState: state.canvas.strokeSession.renderState,
                baseSnapshot: state.canvas.strokeSession.baseSnapshot,
                renderSnapshot: state.canvas.renderSnapshot,
                samples: samples,
                context: DocumentStrokeContext(
                    activeLayer: context.activeLayer,
                    activeLayerIndex: context.activeLayerIndex,
                    brush: context.brush,
                    previewBrush: context.previewBrush
                ),
                allowsApproximatePreviewCommit: usesResponsiveOilPreview(state: state, brush: context.previewBrush),
                refreshViaDirtyPresentation: refreshViaDirtyPresentation
            )

            switch outcome {
            case let .commit(mutation):
                let result = layerCommands.applyLayerSurfaceMutation(
                    mutation.surface.layerIndex,
                    GpuLayerMutationPayload(
                        canvasWidth: mutation.surface.width,
                        canvasHeight: mutation.surface.height,
                        dirtyRect: mutation.dirtyRegion.layerPixelRect,
                        gpuBufferHandle: mutation.surface.handle.buffer
                    )
                )
                switch result {
                case .success:
                    return .committed(
                        DocumentMutationContract(
                            canvasMutation: keepsSelectionCleared ? .clearSelection : .none,
                            refresh: mutation.refreshViaDirtyPresentation ? .dirty : .current,
                            updatesWorkspaceArtifacts: false
                        ),
                        transferredSurfaceHandle: mutation.surface.handle.buffer
                    )
                case let .failure(failure):
                    return .failed(failure)
                }
            case let .failure(failure):
                return .failed(failure)
            case .preview, .reset:
                return .failed(.bridgeMutationFailed("GPU stroke commit failed: unexpected session outcome"))
            }
        }

        private func usesResponsiveOilPreview(
            state: DocumentFeature.State,
            brush: BrushRuntimeSettings
        ) -> Bool {
            state.brushPalette.ui.oilLivePreviewQuality == .responsive &&
            brush.tipKind == .oil
        }
    }

    struct CanvasStrokeStateCoordinator {
        let layerCommands: DocumentLayerCommandService
        let strokeCommands: DocumentStrokeCommandService

        func resetPreview(state: inout DocumentFeature.State) {
            state.canvas.resetStrokePreview()
        }

        func resetPreviewState(
            state: inout DocumentFeature.State,
            preserving transferredSurfaceHandle: MetalBufferHandle? = nil,
            releaseSurfaceHandle: (MetalBufferHandle?) -> Void
        ) {
            let previewSurfaceHandle = state.canvas.strokeSession.renderState?.surfaceHandle
            resetPreview(state: &state)
            if previewSurfaceHandle != transferredSurfaceHandle {
                releaseSurfaceHandle(previewSurfaceHandle)
            }
        }

        func clearSelectionWithoutRefresh(
            state: inout DocumentFeature.State,
            performDocumentMutation: (inout DocumentFeature.State, DocumentMutationContract) -> Void
        ) {
            performDocumentMutation(
                &state,
                DocumentMutationContract(
                    canvasMutation: .clearSelection,
                    refresh: .none
                )
            )
        }

        func ensureCurrentPresentationLoaded(
            state: inout DocumentFeature.State,
            performDocumentMutation: (inout DocumentFeature.State, DocumentMutationContract) -> Void
        ) {
            guard state.canvas.renderSnapshot == nil else { return }
            performDocumentMutation(&state, .currentPresentation)
        }

        func captureBaseSnapshotIfNeeded(
            state: inout DocumentFeature.State,
            ensureCurrentPresentationLoaded: (inout DocumentFeature.State) -> Void
        ) {
            guard state.canvas.strokeSession.baseSnapshot == nil else { return }
            if let pendingCommittedSnapshot = state.canvas.pendingCommittedSnapshot {
                state.canvas.captureStrokeBaseSnapshot(pendingCommittedSnapshot)
                return
            }
            ensureCurrentPresentationLoaded(&state)
            if let renderSnapshot = state.canvas.renderSnapshot {
                state.canvas.captureStrokeBaseSnapshot(renderSnapshot)
            }
        }

        func prepareEditing(
            state: inout DocumentFeature.State,
            clearSelectionWithoutRefresh: (inout DocumentFeature.State) -> Void
        ) -> DocumentMutationResult {
            switch layerCommands.ensureLayerVisible(state.canvas.activeLayerIndex) {
            case .success:
                break
            case let .failure(failure):
                return .failure(failure)
            }
            clearSelectionWithoutRefresh(&state)
            strokeCommands.cancelStroke()
            return .success(())
        }

        func applyPreviewMutation(
            _ mutation: GpuPreviewMutation,
            state: inout DocumentFeature.State,
            releaseSurfaceHandle: (MetalBufferHandle?) -> Void
        ) {
            let previousSurfaceHandle = state.canvas.strokeSession.renderState?.surfaceHandle
            if let baseSnapshotToCapture = mutation.baseSnapshotToCapture {
                state.canvas.captureStrokeBaseSnapshot(baseSnapshotToCapture)
            }
            state.canvas.strokeSession.applyPreview(
                baseSnapshot: mutation.baseSnapshot,
                surface: mutation.surface,
                dirtyRegion: mutation.dirtyRegion,
                isApproximatePreview: mutation.isApproximatePreview,
                incrementalUpdate: mutation.incrementalUpdate,
                previewBrush: mutation.previewBrush,
                sampleCount: mutation.sampleCount,
                supportsIncrementalContinuation: mutation.supportsIncrementalContinuation
            )
            let nextSurfaceHandle = state.canvas.strokeSession.renderState?.surfaceHandle
            if previousSurfaceHandle != nextSurfaceHandle {
                releaseSurfaceHandle(previousSurfaceHandle)
            }
        }
    }

    struct CanvasToolStateCoordinator {
        func resolvedBrushSettings(for state: DocumentFeature.State) -> BrushRuntimeSettings {
            var settings = state.brushPalette.runtimeSettings
            if settings.tipKind == .oil {
                settings.stabilization = max(settings.stabilization, 0.34)
            }
            if state.canvas.currentTool == .erase || (state.canvas.currentTool == .brush && state.brushPalette.brush.usesTransparentColor) {
                settings.isEraser = true
            }
            return settings
        }

        func previewStrokeStyle(for state: DocumentFeature.State) -> PreviewStrokeStyle {
            let resolvedRuntimeSettings: BrushRuntimeSettings = {
                var settings = state.brushPalette.runtimeSettings
                if settings.tipKind == .oil {
                    settings.stabilization = max(settings.stabilization, 0.34)
                }
                return settings
            }()

            if state.canvas.currentTool == .erase || (state.canvas.currentTool == .brush && state.brushPalette.brush.usesTransparentColor) {
                return PreviewStrokeStyle(
                    tipKind: .ink,
                    isEraser: true,
                    radius: CGFloat(resolvedRuntimeSettings.radius),
                    opacity: 0.78,
                    flow: CGFloat(resolvedRuntimeSettings.flow),
                    hardness: 0.95,
                    roundness: CGFloat(resolvedRuntimeSettings.roundness),
                    angle: CGFloat(resolvedRuntimeSettings.angle),
                    followsStrokeAngle: resolvedRuntimeSettings.angleMode == .strokeDirection,
                    pressureSensitivity: CGFloat(resolvedRuntimeSettings.pressureSensitivity),
                    stabilization: CGFloat(resolvedRuntimeSettings.stabilization),
                    customTip: resolvedRuntimeSettings.customTip,
                    color: CGColor(
                        red: 0.92,
                        green: 0.95,
                        blue: 0.98,
                        alpha: 1.0
                    )
                )
            }

            return PreviewStrokeStyle(
                tipKind: resolvedRuntimeSettings.tipKind,
                isEraser: false,
                radius: CGFloat(resolvedRuntimeSettings.radius),
                opacity: CGFloat(resolvedRuntimeSettings.opacity),
                flow: CGFloat(resolvedRuntimeSettings.flow),
                hardness: CGFloat(resolvedRuntimeSettings.hardness),
                roundness: CGFloat(resolvedRuntimeSettings.roundness),
                angle: CGFloat(resolvedRuntimeSettings.angle),
                followsStrokeAngle: resolvedRuntimeSettings.angleMode == .strokeDirection,
                pressureSensitivity: CGFloat(resolvedRuntimeSettings.pressureSensitivity),
                stabilization: CGFloat(resolvedRuntimeSettings.stabilization),
                customTip: resolvedRuntimeSettings.customTip,
                color: CGColor(
                    red: CGFloat(resolvedRuntimeSettings.red) / 255.0,
                    green: CGFloat(resolvedRuntimeSettings.green) / 255.0,
                    blue: CGFloat(resolvedRuntimeSettings.blue) / 255.0,
                    alpha: 1.0
                )
            )
        }

        func resolvedPaperStyle(for state: DocumentFeature.State) -> CanvasPaperStyle {
            let resolved = UIColor(state.brushPalette.paper.color)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return CanvasPaperStyle(
                red: Float(red),
                green: Float(green),
                blue: Float(blue),
                alpha: Float(alpha),
                isTransparent: state.brushPalette.paper.isTransparent
            )
        }
    }
}
