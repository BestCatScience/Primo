import Foundation
import SwiftUI
import UIKit

extension AppFeature {
    struct AppFeatureCanvasUIStateCoordinator {
        func applyPresentation(
            _ presentation: PaintDocumentPresentation,
            to state: inout AppFeature.State
        ) {
            state.canvas.canvasSize = presentation.canvasSize
            state.canvas.activeLayerIndex = presentation.activeLayerIndex
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
            state.canvas.layerBuffers = nextBuffers
            if let renderSnapshot = presentation.renderSnapshot {
                state.canvas.renderSnapshot = renderSnapshot
                state.canvas.lastCommittedRenderRevision = renderSnapshot.revision
                state.canvas.pendingIncrementalUpdate = nil
                state.canvas.activeStrokeBaseSnapshot = nil
                state.canvas.activeStrokePreviewLayerPixelData = nil
                state.isHydrating = false
                if !state.canvas.isStrokeActive &&
                    state.canvas.isAwaitingCommittedRender &&
                    renderSnapshot.revision > previousRevision {
                    state.canvas.isAwaitingCommittedRender = false
                    state.canvas.lastRenderedLocalBufferRevision = state.canvas.localBufferRevision
                }
            }
            state.layerSidebar.layers = presentation.layerRows
            state.layerSidebar.rows = presentation.layerSidebarRows
            state.layerSidebar.layerBuffers = state.canvas.layerBuffers
            state.layerSidebar.activeLayerIndex = presentation.activeLayerIndex
            state.layerSidebar.paperColor = state.brushPalette.paper.color
            state.layerSidebar.transparentPaper = state.brushPalette.paper.isTransparent
            state.canvas.previewStyle = previewStrokeStyle(for: state)
            state.canvas.selectionMode = state.brushPalette.selection.toolMode
            state.canvas.shapeMode = state.brushPalette.shape.mode
            state.canvas.eyedropperSamplingSource = state.brushPalette.sampling.eyedropperSource
            state.canvas.paperStyle = resolvedPaperStyle(for: state)
            state.canvas.activeTextLayer = presentation.layerRows.first(where: { $0.index == presentation.activeLayerIndex })?.textLayer
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
            state.canvas.selection = nil
            state.canvas.selectionPreviewPoints = []
            state.canvas.resetTransformPreview()
            state.canvas.adjustmentPreviewPixelData = nil
            applyPresentation(loaded.presentation, to: &state)
            state.isHydrating = false
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

        func applyLiveCompositePixelData(
            _ compositePixelData: Data,
            to state: inout AppFeature.State
        ) {
            let width = state.canvas.renderSnapshot?.width ?? max(Int(state.canvas.canvasSize.width.rounded()), 1)
            let height = state.canvas.renderSnapshot?.height ?? max(Int(state.canvas.canvasSize.height.rounded()), 1)
            guard compositePixelData.count == width * height * 4 else {
                return
            }

            let layerSnapshots: [MetalLayerSnapshot]
            if let existingLayers = state.canvas.renderSnapshot?.layers, !existingLayers.isEmpty {
                layerSnapshots = existingLayers
            } else {
                layerSnapshots = state.canvas.layerBuffers.map { buffer in
                    MetalLayerSnapshot(
                        index: buffer.index,
                        opacity: Float(buffer.opacity),
                        visible: buffer.visible,
                        isClipped: false,
                        blendMode: buffer.blendMode,
                        thumbnailData: nil,
                        pixelData: Data()
                    )
                }
            }

            let nextRevision = max(state.canvas.renderSnapshot?.revision ?? 0, state.canvas.lastCommittedRenderRevision) + 1
            state.canvas.renderSnapshot = MetalDocumentSnapshot(
                width: width,
                height: height,
                revision: nextRevision,
                compositePixelData: compositePixelData,
                layers: layerSnapshots
            )
            state.canvas.pendingIncrementalUpdate = nil
            state.isHydrating = false
        }

        func applyLiveStrokePreview(
            baseSnapshot: MetalDocumentSnapshot,
            activeLayerIndex: Int,
            adjustedActiveLayerPixels: Data,
            to state: inout AppFeature.State
        ) {
            guard let composite = AppFeature.compositedPreviewPixelData(
                snapshot: baseSnapshot,
                activeLayerIndex: activeLayerIndex,
                adjustedActiveLayerPixels: adjustedActiveLayerPixels
            ) else {
                return
            }

            let nextLayers = baseSnapshot.layers.map { layer in
                guard layer.index == activeLayerIndex else { return layer }
                return MetalLayerSnapshot(
                    index: layer.index,
                    opacity: layer.opacity,
                    visible: layer.visible,
                    isClipped: layer.isClipped,
                    blendMode: layer.blendMode,
                    thumbnailData: layer.thumbnailData,
                    pixelData: adjustedActiveLayerPixels
                )
            }

            let nextRevision = max(state.canvas.renderSnapshot?.revision ?? 0, state.canvas.lastCommittedRenderRevision) + 1
            state.canvas.renderSnapshot = MetalDocumentSnapshot(
                width: baseSnapshot.width,
                height: baseSnapshot.height,
                revision: nextRevision,
                compositePixelData: composite,
                layers: nextLayers
            )
            state.canvas.activeStrokePreviewLayerPixelData = adjustedActiveLayerPixels
            state.canvas.pendingIncrementalUpdate = nil
            state.isHydrating = false
        }

        func resolvedBrushSettings(for state: AppFeature.State) -> BrushRuntimeSettings {
            var settings = state.brushPalette.runtimeSettings
            if settings.tipKind == .oil {
                settings.stabilization = max(settings.stabilization, 0.34)
            }
            if state.canvas.currentTool == .erase || (state.canvas.currentTool == .brush && state.brushPalette.brush.usesTransparentColor) {
                settings.isEraser = true
            }
            return settings
        }

        func previewStrokeStyle(for state: AppFeature.State) -> PreviewStrokeStyle {
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

        func resolvedPaperStyle(for state: AppFeature.State) -> CanvasPaperStyle {
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
