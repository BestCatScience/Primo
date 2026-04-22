import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain
import SwiftUI

extension AppFeature {
    struct AppFeatureCanvasRenderStateCoordinator {
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

        func applyCanvasPresentation(
            _ presentation: PaintDocumentPresentation,
            to state: inout AppFeature.State
        ) {
            state.canvas.setCanvasSize(presentation.canvasSize)
            state.canvas.activateLayer(presentation.activeLayerIndex)
            let previousRevision = state.canvas.renderSnapshot?.revision ?? state.canvas.lastCommittedRenderRevision
            state.canvas.replaceLayerBuffers(
                rebuiltLayerBuffers(
                    from: presentation,
                    existingBuffers: state.canvas.layerBuffers
                )
            )
            applyRenderSnapshotIfAvailable(
                from: presentation,
                previousRevision: previousRevision,
                to: &state
            )
        }

        func applyRenderSnapshotIfAvailable(
            from presentation: PaintDocumentPresentation,
            previousRevision: Int,
            to state: inout AppFeature.State
        ) {
            guard let renderSnapshot = presentation.renderSnapshot else { return }
            state.canvas.applyCommittedRenderSnapshot(
                renderSnapshot,
                previousRevision: previousRevision
            )
            state.application.finishHydration()
        }
    }

    struct AppFeatureLayerSidebarPresentationCoordinator {
        func applyPresentation(
            _ presentation: PaintDocumentPresentation,
            to state: inout AppFeature.State
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

    struct AppFeatureCanvasInteractionStateCoordinator {
        func syncPresentation(
            _ presentation: PaintDocumentPresentation,
            state: inout AppFeature.State
        ) {
            syncCanvasInteractionState(state: &state)
            syncActiveTextLayer(from: presentation, state: &state)
        }

        func syncCanvasInteractionState(state: inout AppFeature.State) {
            state.canvas.updateInteractionStyle(
                previewStyle: AppFeature.canvasToolStateCoordinator.previewStrokeStyle(for: state),
                paperStyle: AppFeature.canvasToolStateCoordinator.resolvedPaperStyle(for: state)
            )
            state.canvas.updateInteractionModes(
                selectionMode: state.brushPalette.selection.toolMode,
                shapeMode: state.brushPalette.shape.mode,
                eyedropperSamplingSource: state.brushPalette.sampling.eyedropperSource
            )
        }

        func syncActiveTextLayer(
            from presentation: PaintDocumentPresentation,
            state: inout AppFeature.State
        ) {
            state.canvas.setActiveTextLayer(
                presentation.layerRows.first(where: { $0.index == presentation.activeLayerIndex })?.textLayer
            )
            syncTextEditorWithActiveLayer(state: &state)
        }

        func syncTextEditorWithActiveLayer(state: inout AppFeature.State) {
            state.brushPalette.syncTextEditor(
                with: state.layerSidebar.layer(withIndex: state.layerSidebar.activeLayerIndex)
            )
        }
    }

    struct AppFeatureFreshDocumentStateCoordinator {
        func prepare(
            canvasSize: CGSize,
            to state: inout AppFeature.State
        ) {
            state.application.showWorkspace()
            state.canvas = CanvasFeature.State()
            state.canvas.setCanvasSize(canvasSize)
            state.layerSidebar = LayerSidebarFeature.State()
            state.brushPalette = BrushPaletteFeature.State()
            AppFeature.toolPanelStateCoordinator.resetPanels(in: &state)
            state.export.clearOutputs()
            state.application.clearBanner()
            state.application.finishHydration()
        }
    }

    struct AppFeatureCanvasPresentationStateCoordinator {
        let renderCoordinator = AppFeatureCanvasRenderStateCoordinator()
        let layerSidebarCoordinator = AppFeatureLayerSidebarPresentationCoordinator()
        let interactionCoordinator = AppFeatureCanvasInteractionStateCoordinator()
        let freshDocumentCoordinator = AppFeatureFreshDocumentStateCoordinator()

        func prepareFreshDocument(
            canvasSize: CGSize,
            to state: inout AppFeature.State
        ) {
            freshDocumentCoordinator.prepare(canvasSize: canvasSize, to: &state)
        }

        func applyPresentation(
            _ presentation: PaintDocumentPresentation,
            to state: inout AppFeature.State
        ) {
            renderCoordinator.applyCanvasPresentation(presentation, to: &state)
            layerSidebarCoordinator.applyPresentation(presentation, to: &state)
            interactionCoordinator.syncPresentation(presentation, state: &state)
        }

        func applyLoadedProject(
            _ loaded: LoadedPaintProject,
            to state: inout AppFeature.State
        ) {
            state.brushPalette.applyLoadedPaperStyle(loaded.paperStyle)
            state.canvas.resetTransientEditingState()
            applyPresentation(loaded.presentation, to: &state)
        }

        func syncTextEditorWithActiveLayer(state: inout AppFeature.State) {
            interactionCoordinator.syncTextEditorWithActiveLayer(state: &state)
        }
    }
}
