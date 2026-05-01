import Foundation
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts
import SwiftUI

extension DocumentFeature {
    struct CanvasRenderStateCoordinator {
        func rebuiltLayerBuffers(
            from presentation: PaintDocumentPresentation,
            existingBuffers: [LayerCanvasBuffer]
        ) -> [LayerCanvasBuffer] {
            let indexedBuffers = Dictionary(uniqueKeysWithValues: existingBuffers.map { ($0.index, $0) })
            return presentation.layerRows.sorted(by: { $0.index < $1.index }).map { row in
                var buffer = indexedBuffers[row.index] ?? LayerCanvasBuffer(
                    index: row.index,
                    name: row.name,
                    visible: row.visible,
                    opacity: row.opacity,
                    blendMode: row.blendMode
                )
                buffer.name = row.name
                buffer.visible = row.visible
                buffer.opacity = row.opacity
                buffer.blendMode = row.blendMode
                return buffer
            }
        }

        @discardableResult
        func applyCanvasPresentation(
            _ presentation: PaintDocumentPresentation,
            to state: inout DocumentEditingState
        ) -> Bool {
            state.canvas.setCanvasSize(presentation.canvasSize)
            state.canvas.activateLayer(presentation.activeLayerIndex)
            let previousRevision = state.canvas.renderSnapshot?.revision ?? state.canvas.lastCommittedRenderRevision
            state.canvas.replaceLayerBuffers(
                rebuiltLayerBuffers(
                    from: presentation,
                    existingBuffers: state.canvas.layerBuffers
                )
            )
            return applyRenderSnapshotIfAvailable(
                from: presentation,
                previousRevision: previousRevision,
                to: &state
            )
        }

        @discardableResult
        func applyRenderSnapshotIfAvailable(
            from presentation: PaintDocumentPresentation,
            previousRevision: Int,
            to state: inout DocumentEditingState
        ) -> Bool {
            guard let renderSnapshot = presentation.renderSnapshot else { return false }
            state.canvas.applyCommittedRenderSnapshot(
                renderSnapshot,
                previousRevision: previousRevision
            )
            return true
        }
    }

    struct LayerSidebarPresentationCoordinator {
        func applyPresentation(
            _ presentation: PaintDocumentPresentation,
            to state: inout DocumentEditingState
        ) {
            state.layerSidebar.applyPresentation(
                layers: presentation.layerRows,
                rows: presentation.layerSidebarRows,
                layerBuffers: state.canvas.layerBuffers,
                activeLayerIndex: presentation.activeLayerIndex,
                paperColor: state.brushPalette.paper.color,
                transparentPaper: state.brushPalette.paper.isTransparent
            )
        }
    }

    struct CanvasInteractionStateCoordinator {
        func syncPresentation(
            _ presentation: PaintDocumentPresentation,
            state: inout DocumentEditingState
        ) {
            syncCanvasInteractionState(state: &state)
            syncActiveTextLayer(from: presentation, state: &state)
        }

        func syncCanvasInteractionState(state: inout DocumentEditingState) {
            state.canvas.updateInteractionStyle(
                previewStyle: DocumentFeature.canvasToolStateCoordinator.previewStrokeStyle(for: state),
                paperStyle: DocumentFeature.canvasToolStateCoordinator.resolvedPaperStyle(for: state)
            )
            state.canvas.updateInteractionModes(
                selectionMode: state.brushPalette.selection.toolMode,
                shapeMode: state.brushPalette.shape.mode,
                eyedropperSamplingSource: state.brushPalette.sampling.eyedropperSource
            )
        }

        func syncActiveTextLayer(
            from presentation: PaintDocumentPresentation,
            state: inout DocumentEditingState
        ) {
            state.canvas.setActiveTextLayer(
                presentation.layerRows.first(where: { $0.index == presentation.activeLayerIndex })?.textLayer
            )
            syncTextEditorWithActiveLayer(state: &state)
        }

        func syncTextEditorWithActiveLayer(state: inout DocumentEditingState) {
            state.brushPalette.syncTextEditor(
                with: state.layerSidebar.layer(withIndex: state.layerSidebar.activeLayerIndex)
            )
        }
    }

    struct CanvasPresentationStateCoordinator {
        let renderCoordinator = CanvasRenderStateCoordinator()
        let layerSidebarCoordinator = LayerSidebarPresentationCoordinator()
        let interactionCoordinator = CanvasInteractionStateCoordinator()

        @discardableResult
        func applyPresentation(
            _ presentation: PaintDocumentPresentation,
            to state: inout DocumentEditingState
        ) -> Bool {
            let finishedHydration = renderCoordinator.applyCanvasPresentation(presentation, to: &state)
            layerSidebarCoordinator.applyPresentation(presentation, to: &state)
            interactionCoordinator.syncPresentation(presentation, state: &state)
            return finishedHydration
        }

        @discardableResult
        func applyLoadedProject(
            _ loaded: LoadedPaintProject,
            to state: inout DocumentEditingState
        ) -> Bool {
            state.brushPalette.applyLoadedPaperStyle(loaded.paperStyle)
            state.canvas.resetTransientEditingState()
            return applyPresentation(loaded.presentation, to: &state)
        }

        func syncTextEditorWithActiveLayer(state: inout DocumentEditingState) {
            interactionCoordinator.syncTextEditorWithActiveLayer(state: &state)
        }
    }
}
