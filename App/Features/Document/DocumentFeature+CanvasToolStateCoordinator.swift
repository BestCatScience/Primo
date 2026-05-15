import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentRuntime
import PrimoDocumentStrokeApplication
import UIKit

extension DocumentFeature {
    static let canvasToolStateCoordinator = CanvasToolStateCoordinator()

    enum StrokeCommitResolution {
        case committed(DocumentMutationContract, transferredPreviewLease: StrokePreviewLease)
        case failed(DocumentMutationFailure)
    }

    struct CanvasStrokeSessionCoordinator {
        let layerVisibility: any LayerVisibilityPort
        let strokeInteraction: any StrokePreviewPort

        init(
            layerVisibility: any LayerVisibilityPort,
            strokeInteraction: any StrokePreviewPort
        ) {
            self.layerVisibility = layerVisibility
            self.strokeInteraction = strokeInteraction
        }

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
            if keepsSelectionCleared {
                switch layerVisibility.ensureLayerVisible(context.activeLayerIndex) {
                case .success:
                    break
                case let .failure(failure):
                    return .failed(failure)
                }
            }

            let outcome = strokeInteraction.finish(
                renderState: state.canvas.strokeSession.renderState,
                baseSnapshot: state.canvas.strokeSession.baseSnapshot,
                renderSnapshot: state.canvas.renderSnapshot,
                samples: samples,
                context: documentContext,
                allowsApproximatePreviewCommit: usesResponsivePreview(state: state, brush: context.previewBrush),
                refreshViaDirtyPresentation: refreshViaDirtyPresentation
            )

            switch outcome {
            case let .commit(mutation):
                guard let payload = GpuLayerMutationPayload(
                    validatingCanvasWidth: mutation.surface.width,
                    canvasHeight: mutation.surface.height,
                    dirtyRect: mutation.dirtyRegion.layerPixelRect,
                    gpuBufferHandle: mutation.surface.handle.buffer,
                    fallbackPixelData: mutation.surface.pixelData
                ) else {
                    return .failed(.bridgeMutationFailed("GPU stroke commit invalid payload"))
                }
                switch layerVisibility.applyLayerSurfaceMutation(mutation.surface.layerIndex, payload) {
                case .success:
                    break
                case let .failure(failure):
                    return .failed(failure)
                }
                if keepsSelectionCleared {
                    state.canvas.clearSelection()
                }
                let commitBaseSnapshot = state.canvas.strokeSession.baseSnapshot ?? state.canvas.renderSnapshot
                if let commitBaseSnapshot {
                    state.canvas.stagePendingCommittedStrokeSnapshot(
                        baseSnapshot: commitBaseSnapshot,
                        surface: mutation.surface
                    )
                }
                return .committed(
                    DocumentMutationWorkflowOutcome<CanvasSelection, ApplicationFeature.Feedback>(
                        canvasMutation: keepsSelectionCleared ? .clearSelection : .none,
                        refresh: mutation.refreshViaDirtyPresentation ? .dirty : .current,
                        updatesWorkspaceArtifacts: false
                    ),
                    transferredPreviewLease: strokeInteraction.previewLease(for: mutation)
                )
            case let .failure(failure):
                return .failed(failure)
            case .preview, .reset:
                return .failed(.bridgeMutationFailed("GPU stroke commit failed: unexpected session outcome"))
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
        let layerVisibility: any LayerVisibilityPort
        let strokeCommit: any StrokeCommitPort

        init(
            layerVisibility: any LayerVisibilityPort,
            strokeCommit: any StrokeCommitPort
        ) {
            self.layerVisibility = layerVisibility
            self.strokeCommit = strokeCommit
        }

        init(
            layerCommands: DocumentLayerCommandService,
            strokeCommands: DocumentStrokeCommandService
        ) {
            self.init(
                layerVisibility: DocumentLayerCommandMutationSubmitter(service: layerCommands),
                strokeCommit: DocumentStrokeCommandMutationSubmitter(service: strokeCommands)
            )
        }

        func resetPreview(state: inout DocumentEditingState) {
            state.canvas.resetStrokePreview()
        }

        func resetPreviewState(
            state: inout DocumentEditingState,
            preserving transferredPreviewLease: StrokePreviewLease = .none,
            discardPreviewLease: (StrokePreviewLease) -> Void
        ) {
            let previewLease = state.canvas.strokeSession.renderState?.previewLease ?? .none
            state.canvas.activeStroke = nil
            resetPreview(state: &state)
            if previewLease != transferredPreviewLease {
                discardPreviewLease(previewLease)
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
            switch layerVisibility.ensureLayerVisible(state.canvas.activeLayerIndex) {
            case .success:
                break
            case let .failure(failure):
                return .failure(failure)
            }
            clearSelectionWithoutRefresh(&state)
            strokeCommit.cancelStroke()
            return .success(())
        }

        func applyPreviewMutation(
            _ mutation: GpuPreviewMutation,
            state: inout DocumentEditingState,
            discardPreviewLease: (StrokePreviewLease) -> Void
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
                discardPreviewLease(previousPreviewLease)
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
                validatingRed: Float(red),
                green: Float(green),
                blue: Float(blue),
                alpha: Float(alpha),
                isTransparent: state.brushPalette.paper.isTransparent
            ) ?? .default
        }
    }
}
