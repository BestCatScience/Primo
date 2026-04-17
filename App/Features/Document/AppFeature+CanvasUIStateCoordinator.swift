import Foundation
import SwiftUI

extension AppFeature {
    struct AppFeatureCanvasPresentationStateCoordinator {
        func applyPresentation(
            _ presentation: PaintDocumentPresentation,
            to state: inout AppFeature.State
        ) {
            state.canvas.setCanvasSize(presentation.canvasSize)
            state.canvas.activateLayer(presentation.activeLayerIndex)
            let previousRevision = state.canvas.renderSnapshot?.revision ?? state.canvas.lastCommittedRenderRevision
            var nextBuffers: [LayerCanvasBuffer] = []
            let existingBuffers = Dictionary(uniqueKeysWithValues: state.canvas.layerBuffers.map { ($0.index, $0) })
            for row in presentation.layerRows.sorted(by: { $0.index < $1.index }) {
                var buffer = existingBuffers[row.index] ?? LayerCanvasBuffer(
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
                nextBuffers.append(buffer)
            }
            state.canvas.replaceLayerBuffers(nextBuffers)
            if let renderSnapshot = presentation.renderSnapshot {
                state.canvas.applyCommittedRenderSnapshot(
                    renderSnapshot,
                    previousRevision: previousRevision
                )
                state.application.finishHydration()
            }
            state.layerSidebar.applyPresentation(
                layers: presentation.layerRows,
                rows: presentation.layerSidebarRows,
                layerBuffers: state.canvas.layerBuffers,
                activeLayerIndex: presentation.activeLayerIndex,
                paperColor: state.brushPalette.paper.color,
                transparentPaper: state.brushPalette.paper.isTransparent
            )
            state.canvas.updateInteractionStyle(
                previewStyle: AppFeature.canvasToolStateCoordinator.previewStrokeStyle(for: state),
                paperStyle: AppFeature.canvasToolStateCoordinator.resolvedPaperStyle(for: state)
            )
            state.canvas.updateInteractionModes(
                selectionMode: state.brushPalette.selection.toolMode,
                shapeMode: state.brushPalette.shape.mode,
                eyedropperSamplingSource: state.brushPalette.sampling.eyedropperSource
            )
            state.canvas.setActiveTextLayer(
                presentation.layerRows.first(where: { $0.index == presentation.activeLayerIndex })?.textLayer
            )
            syncTextEditorWithActiveLayer(state: &state)
        }

        func applyLoadedProject(
            _ loaded: LoadedPaintProject,
            to state: inout AppFeature.State
        ) {
            state.brushPalette.applyLoadedPaperStyle(loaded.paperStyle)
            state.canvas.resetTransientEditingState()
            applyPresentation(loaded.presentation, to: &state)
            state.application.finishHydration()
        }

        func syncTextEditorWithActiveLayer(state: inout AppFeature.State) {
            state.brushPalette.syncTextEditor(
                with: state.layerSidebar.layer(withIndex: state.layerSidebar.activeLayerIndex)
            )
        }
    }
}
