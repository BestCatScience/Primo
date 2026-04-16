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
            state.layerSidebar.layers = presentation.layerRows
            state.layerSidebar.rows = presentation.layerSidebarRows
            state.layerSidebar.layerBuffers = state.canvas.layerBuffers
            state.layerSidebar.activeLayerIndex = presentation.activeLayerIndex
            state.layerSidebar.paperColor = state.brushPalette.paper.color
            state.layerSidebar.transparentPaper = state.brushPalette.paper.isTransparent
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
            state.brushPalette.paper.color = Color(
                red: Double(loaded.paperStyle.red),
                green: Double(loaded.paperStyle.green),
                blue: Double(loaded.paperStyle.blue),
                opacity: Double(loaded.paperStyle.alpha)
            )
            state.brushPalette.paper.isTransparent = loaded.paperStyle.isTransparent
            state.canvas.resetTransientEditingState()
            applyPresentation(loaded.presentation, to: &state)
            state.application.finishHydration()
        }

        func syncTextEditorWithActiveLayer(state: inout AppFeature.State) {
            guard let activeLayer = state.layerSidebar.layers.first(where: { $0.index == state.layerSidebar.activeLayerIndex }) else {
                state.brushPalette.text.targetLayerIndex = nil
                state.brushPalette.text.scale = 1.0
                state.brushPalette.text.rotationDegrees = 0
                return
            }
            if let textLayer = activeLayer.textLayer {
                state.brushPalette.text.content = textLayer.text
                state.brushPalette.text.fontSize = textLayer.fontSize
                state.brushPalette.text.position = textLayer.position
                state.brushPalette.text.scale = textLayer.scale
                state.brushPalette.text.rotationDegrees = textLayer.rotationDegrees
                state.brushPalette.text.targetLayerIndex = activeLayer.index
                state.brushPalette.text.selectedFontPostScriptName = textLayer.fontPostScriptName
                state.brushPalette.text.selectedFontDisplayName = textLayer.fontDisplayName
            } else {
                state.brushPalette.text.targetLayerIndex = nil
                state.brushPalette.text.scale = 1.0
                state.brushPalette.text.rotationDegrees = 0
            }
        }
    }
}
