import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentStrokeApplication
import UIKit

extension DocumentFeature {
    static let canvasToolStateCoordinator = CanvasToolStateCoordinator()

    enum StrokeCommitResolution {
        case committed(DocumentMutationContract, transferredPreviewLease: StrokePreviewLease)
        case failed(DocumentMutationFailure)
    }

    struct CanvasStrokeSessionCoordinator {
        let layerCommands: DocumentLayerCommandService
        let strokeInteraction: CanvasStrokeInteractionService
        let commitWorkflow: DocumentStrokeCommitWorkflowService

        func resolveAppendedStrokePreview(
            state: DocumentEditingState,
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
                usesResponsivePreview: usesResponsivePreview(state: state, brush: context.previewBrush)
            )
        }

        func resolveShapeStrokePreview(
            state: DocumentEditingState,
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
                usesResponsivePreview: usesResponsivePreview(state: state, brush: context.previewBrush)
            )
        }

        func resolveStrokeCommit(
            state: inout DocumentEditingState,
            samples: [StylusSample],
            context: CanvasStrokeContext,
            keepsSelectionCleared: Bool,
            refreshViaDirtyPresentation: Bool
        ) -> StrokeCommitResolution {
            let documentContext = DocumentStrokeContext(
                activeLayer: context.activeLayer,
                activeLayerIndex: context.activeLayerIndex,
                brush: context.brush,
                previewBrush: context.previewBrush
            )
            let result: Result<StrokeCommitWorkflowResult<CanvasSelection, ApplicationFeature.Feedback>, DocumentMutationFailure> = commitWorkflow.resolveCommit(
                StrokeCommitWorkflowRequest(
                    baseSnapshot: state.canvas.strokeSession.baseSnapshot,
                    renderSnapshot: state.canvas.renderSnapshot,
                    renderState: state.canvas.strokeSession.renderState,
                    samples: samples,
                    context: documentContext,
                    selectionClearPolicy: keepsSelectionCleared ? .clearSelection : .none,
                    refreshViaDirtyPresentation: refreshViaDirtyPresentation
                ),
                usesResponsivePreviewCommit: usesResponsivePreview(state: state, brush: context.previewBrush)
            )

            switch result {
            case let .success(commit):
                if keepsSelectionCleared {
                    state.canvas.clearSelection()
                }
                if let pending = commit.pendingCommittedSnapshot {
                    state.canvas.stagePendingCommittedStrokeSnapshot(
                        baseSnapshot: pending.baseSnapshot,
                        surface: pending.surface
                    )
                }
                return .committed(
                    commit.contract,
                    transferredPreviewLease: commit.transferredPreviewLease
                )
            case let .failure(failure):
                return .failed(failure)
            }
        }

        private func usesResponsivePreview(
            state: DocumentEditingState,
            brush: BrushRuntimeSettings
        ) -> Bool {
            true
        }
    }

    struct CanvasStrokeStateCoordinator {
        let layerCommands: DocumentLayerCommandService
        let strokeCommands: DocumentStrokeCommandService

        func resetPreview(state: inout DocumentEditingState) {
            state.canvas.resetStrokePreview()
        }

        func resetPreviewState(
            state: inout DocumentEditingState,
            preserving transferredPreviewLease: StrokePreviewLease = .none,
            releaseSurfaceLease: (StrokePreviewLease) -> Void
        ) {
            let previewLease = state.canvas.strokeSession.renderState?.previewLease ?? .none
            state.canvas.activeStroke = nil
            resetPreview(state: &state)
            if previewLease != transferredPreviewLease {
                releaseSurfaceLease(previewLease)
            }
        }

        func clearSelectionWithoutRefresh(
            state: inout DocumentEditingState,
            performDocumentMutation: (inout DocumentEditingState, DocumentMutationContract) -> Void
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
            state: inout DocumentEditingState,
            performDocumentMutation: (inout DocumentEditingState, DocumentMutationContract) -> Void
        ) {
            guard state.canvas.renderSnapshot == nil else { return }
            performDocumentMutation(&state, .currentPresentation)
        }

        func captureBaseSnapshotIfNeeded(
            state: inout DocumentEditingState,
            ensureCurrentPresentationLoaded: (inout DocumentEditingState) -> Void
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
            state: inout DocumentEditingState,
            clearSelectionWithoutRefresh: (inout DocumentEditingState) -> Void
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
            state: inout DocumentEditingState,
            releaseSurfaceLease: (StrokePreviewLease) -> Void
        ) {
            let previousPreviewLease = state.canvas.strokeSession.renderState?.previewLease ?? .none
            let previousRenderState = state.canvas.strokeSession.renderState
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
            state.canvas.recordPreviewIncrementalUpdate(
                mutation.incrementalUpdate,
                previousRenderState: previousRenderState,
                baseSnapshot: mutation.baseSnapshot,
                surface: mutation.surface,
                previewBrush: mutation.previewBrush,
                sampleCount: mutation.sampleCount
            )
            let nextPreviewLease = state.canvas.strokeSession.renderState?.previewLease ?? .none
            if previousPreviewLease != nextPreviewLease {
                releaseSurfaceLease(previousPreviewLease)
            }
        }
    }

    struct CanvasToolStateCoordinator {
        func resolvedBrushSettings(for state: DocumentEditingState) -> BrushRuntimeSettings {
            var settings = state.brushPalette.runtimeSettings
            if settings.tipKind == .oil {
                settings.stabilization = max(settings.stabilization, 0.34)
            }
            if state.canvas.currentTool == .erase {
                settings = eraserRuntimeSettings(from: settings)
            } else if state.canvas.currentTool == .brush && state.brushPalette.brush.usesTransparentColor {
                settings = transparentBrushRuntimeSettings(from: settings)
            }
            return settings
        }

        func previewStrokeStyle(for state: DocumentEditingState) -> PreviewStrokeStyle {
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

        private func eraserRuntimeSettings(from settings: BrushRuntimeSettings) -> BrushRuntimeSettings {
            var eraser = settings
            eraser.tipKind = .ink
            eraser.opacity = 1.0
            eraser.flow = 1.0
            eraser.opacityPressureSensitivity = max(eraser.opacityPressureSensitivity, 0.72)
            eraser.colorMixingMode = .off
            eraser.wetness = 0.0
            eraser.colorMixStrength = 0.0
            eraser.smudgeBlurEnabled = false
            eraser.smudgeBleed = 0.0
            eraser.smudgeRadius = 0.0
            eraser.paintLoad = 1.0
            eraser.smudgeEngineEnabled = false
            eraser.smudgeLength = 0.0
            eraser.colorRate = 1.0
            eraser.dualBrushEnabled = false
            eraser.red = 255
            eraser.green = 255
            eraser.blue = 255
            eraser.isEraser = true
            return eraser
        }

        private func transparentBrushRuntimeSettings(from settings: BrushRuntimeSettings) -> BrushRuntimeSettings {
            var eraser = settings
            eraser.colorMixingMode = .off
            eraser.wetness = 0.0
            eraser.colorMixStrength = 0.0
            eraser.smudgeBlurEnabled = false
            eraser.smudgeBleed = 0.0
            eraser.smudgeRadius = 0.0
            eraser.smudgeEngineEnabled = false
            eraser.smudgeLength = 0.0
            eraser.isEraser = true
            return eraser
        }

        func resolvedPaperStyle(for state: DocumentEditingState) -> CanvasPaperStyle {
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
