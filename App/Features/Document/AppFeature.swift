import ComposableArchitecture
import CoreGraphics
import Foundation
import os
import Photos
import UIKit

struct ShareExport: Equatable, Identifiable {
    let id = UUID()
    let url: URL
}

enum StudioPanelKind: String, CaseIterable, Equatable {
    case brush
    case layers

    var title: String {
        switch self {
        case .brush:
            return "Brush"
        case .layers:
            return "Layers"
        }
    }
}

enum StudioPanelSide: String, Equatable {
    case leading
    case trailing
}

struct StudioPanelLayoutState: Equatable {
    var side: StudioPanelSide
    var isCollapsed: Bool = false
}

@Reducer
struct AppFeature {
    private static let startupLogger = Logger(subsystem: "com.atelierprime.app", category: "Startup")
    private enum CancelID {
        case deferredPresentationRefresh
    }

    @ObservableState
    struct State: Equatable {
        var isHydrating = true
        var brushPalette = BrushPaletteFeature.State()
        var layerSidebar = LayerSidebarFeature.State()
        var canvas = CanvasFeature.State()
        var newCanvasDraft: NewCanvasDraft?
        var brushPanel = StudioPanelLayoutState(side: .leading)
        var layerPanel = StudioPanelLayoutState(side: .trailing)
        var stackedPanelOrder: [StudioPanelKind] = [.brush, .layers]
        var exportSheet: ShareExport?
        var bannerMessage: String?

        mutating func applyPresentation(_ presentation: PaintDocumentPresentation) {
            canvas.canvasSize = presentation.canvasSize
            canvas.activeLayerIndex = presentation.activeLayerIndex
            let previousRevision = canvas.renderSnapshot?.revision ?? canvas.lastCommittedRenderRevision
            var nextBuffers: [LayerCanvasBuffer] = []
            let existingBuffers = Dictionary(uniqueKeysWithValues: canvas.layerBuffers.map { ($0.index, $0) })
            for row in presentation.layerRows.sorted(by: { $0.index < $1.index }) {
                var buffer = existingBuffers[row.index] ?? LayerCanvasBuffer(
                    index: row.index,
                    name: row.name,
                    visible: row.visible,
                    opacity: row.opacity
                )
                buffer.name = row.name
                buffer.visible = row.visible
                buffer.opacity = row.opacity
                if presentation.renderSnapshot != nil {
                    buffer.strokes.removeAll()
                }
                nextBuffers.append(buffer)
            }
            canvas.layerBuffers = nextBuffers
            if let renderSnapshot = presentation.renderSnapshot {
                canvas.renderSnapshot = renderSnapshot
                canvas.lastCommittedRenderRevision = renderSnapshot.revision
                isHydrating = false
                if !canvas.isStrokeActive &&
                    canvas.isAwaitingCommittedRender &&
                    renderSnapshot.revision > previousRevision {
                    canvas.isAwaitingCommittedRender = false
                    canvas.pendingCommittedStroke = nil
                    canvas.lastRenderedLocalBufferRevision = canvas.localBufferRevision
                }
            }
            layerSidebar.layers = presentation.layerRows
            layerSidebar.layerBuffers = canvas.layerBuffers
            layerSidebar.activeLayerIndex = presentation.activeLayerIndex
            layerSidebar.renderSnapshot = presentation.renderSnapshot
            canvas.previewStyle = previewStrokeStyle()
        }

        func resolvedBrushSettings() -> BrushRuntimeSettings {
            var settings = brushPalette.runtimeSettings
            if canvas.currentTool == .erase {
                settings.isEraser = true
            }
            return settings
        }

        func previewStrokeStyle() -> PreviewStrokeStyle {
            if canvas.currentTool == .erase {
                return PreviewStrokeStyle(
                    radius: CGFloat(brushPalette.runtimeSettings.radius),
                    opacity: 0.78,
                    color: CGColor(
                        red: 0.92,
                        green: 0.95,
                        blue: 0.98,
                        alpha: 1.0
                    )
                )
            }

            return PreviewStrokeStyle(
                radius: CGFloat(brushPalette.runtimeSettings.radius),
                opacity: CGFloat(brushPalette.runtimeSettings.opacity),
                color: CGColor(
                    red: CGFloat(brushPalette.runtimeSettings.red) / 255.0,
                    green: CGFloat(brushPalette.runtimeSettings.green) / 255.0,
                    blue: CGFloat(brushPalette.runtimeSettings.blue) / 255.0,
                    alpha: 1.0
                )
            )
        }

        func panelState(for panel: StudioPanelKind) -> StudioPanelLayoutState {
            switch panel {
            case .brush:
                return brushPanel
            case .layers:
                return layerPanel
            }
        }

        mutating func setPanelState(_ panelState: StudioPanelLayoutState, for panel: StudioPanelKind) {
            switch panel {
            case .brush:
                brushPanel = panelState
            case .layers:
                layerPanel = panelState
            }
        }

        mutating func toggleCollapse(for panel: StudioPanelKind) {
            var current = panelState(for: panel)
            current.isCollapsed.toggle()
            setPanelState(current, for: panel)
        }

        mutating func movePanel(_ panel: StudioPanelKind, to side: StudioPanelSide) {
            var current = panelState(for: panel)
            current.side = side
            current.isCollapsed = false
            setPanelState(current, for: panel)
        }

        mutating func movePanelIntoStack(_ panel: StudioPanelKind) {
            let companion = panel == .brush ? StudioPanelKind.layers : .brush
            movePanel(panel, to: panelState(for: companion).side)
        }

        mutating func unstackPanel(_ panel: StudioPanelKind) {
            let defaultSide: StudioPanelSide = panel == .brush ? .leading : .trailing
            movePanel(panel, to: defaultSide)
        }

        mutating func swapStackOrder() {
            guard stackedPanelOrder.count == 2 else { return }
            stackedPanelOrder.swapAt(0, 1)
        }

        func panels(on side: StudioPanelSide) -> [StudioPanelKind] {
            stackedPanelOrder.filter { panelState(for: $0).side == side }
        }
    }

    enum Action: Equatable {
        case task
        case bootstrapPresentationLoaded(PaintDocumentPresentation)
        case presentationLoaded(PaintDocumentPresentation)
        case loadPresentationAfterLaunch
        case deferredPresentationRefresh
        case refreshPresentationRequested
        case newCanvasRequested
        case newCanvasDismissed
        case newCanvasWidthChanged(String)
        case newCanvasHeightChanged(String)
        case newCanvasConfirmed
        case saveDocumentRequested
        case saveToPhotosRequested
        case exportDocumentRequested
        case exportSheetDismissed
        case bannerDismissed
        case photoLibrarySaveCompleted(PhotoLibrarySaveResult)
        case toolSelected(StudioToolKind)
        case clearActiveLayerButtonTapped
        case activeLayerVisibilityToggled
        case selectPreviousLayer
        case selectNextLayer
        case panelCollapseToggled(StudioPanelKind)
        case panelMoved(StudioPanelKind, StudioPanelSide)
        case panelStackToggled(StudioPanelKind)
        case panelStackOrderSwapRequested
        case brushPalette(BrushPaletteFeature.Action)
        case layerSidebar(LayerSidebarFeature.Action)
        case canvas(CanvasFeature.Action)
    }

    enum PhotoLibrarySaveError: Error, Equatable {
        case accessDenied
        case imageDecodeFailed
        case saveFailed

        var message: String {
            switch self {
            case .accessDenied:
                return "写真へのアクセスが許可されていません"
            case .imageDecodeFailed:
                return "PNGの読み込みに失敗しました"
            case .saveFailed:
                return "写真への保存に失敗しました"
            }
        }
    }

    enum PhotoLibrarySaveResult: Equatable {
        case success
        case failure(PhotoLibrarySaveError)
    }

    struct NewCanvasDraft: Equatable, Identifiable {
        let id = UUID()
        var widthText: String = "1152"
        var heightText: String = "1536"
    }

    @Dependency(\.paintDocumentClient) var paintDocumentClient

    var body: some ReducerOf<Self> {
        Scope(state: \.brushPalette, action: \.brushPalette) {
            BrushPaletteFeature()
        }
        Scope(state: \.layerSidebar, action: \.layerSidebar) {
            LayerSidebarFeature()
        }
        Scope(state: \.canvas, action: \.canvas) {
            CanvasFeature()
        }

        Reduce { state, action in
            switch action {
            case .task:
                state.isHydrating = true
                Self.startupLogger.debug("AppFeature.task started")
                return .run { [paintDocumentClient] send in
                    let startupClock = ContinuousClock()
                    let bootstrapStart = startupClock.now

                    Self.startupLogger.debug("Loading lightweight presentation")
                    let lightweightPresentation = paintDocumentClient.lightweightPresentation()
                    let bootstrapDuration = bootstrapStart.duration(to: startupClock.now)
                    Self.startupLogger.debug("Lightweight presentation loaded in \(String(describing: bootstrapDuration), privacy: .public)")
                    await send(.bootstrapPresentationLoaded(lightweightPresentation))
                    await send(.loadPresentationAfterLaunch)
                }

            case let .bootstrapPresentationLoaded(presentation):
                state.applyPresentation(presentation)
                state.isHydrating = false
                Self.startupLogger.debug("Bootstrap presentation applied; initial UI is ready")
                return .none

            case .loadPresentationAfterLaunch:
                return .run { [paintDocumentClient] send in
                    let clock = ContinuousClock()
                    try? await Task.sleep(for: .milliseconds(150))

                    let presentationStart = clock.now
                    Self.startupLogger.debug("Loading full presentation after initial launch")
                    let presentation = paintDocumentClient.presentation()
                    let presentationDuration = presentationStart.duration(to: clock.now)
                    Self.startupLogger.debug("Full presentation loaded in \(String(describing: presentationDuration), privacy: .public)")
                    await send(.presentationLoaded(presentation))
                }

            case let .presentationLoaded(presentation):
                state.applyPresentation(presentation)
                Self.startupLogger.debug("Full presentation applied")
                return .none

            case .deferredPresentationRefresh:
                return .run { [paintDocumentClient] send in
                    await send(.presentationLoaded(paintDocumentClient.presentation()))
                }
                .cancellable(id: CancelID.deferredPresentationRefresh, cancelInFlight: true)

            case .refreshPresentationRequested:
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case .newCanvasRequested:
                state.newCanvasDraft = NewCanvasDraft()
                return .none

            case .newCanvasDismissed:
                state.newCanvasDraft = nil
                return .none

            case let .newCanvasWidthChanged(width):
                state.newCanvasDraft?.widthText = width
                return .none

            case let .newCanvasHeightChanged(height):
                state.newCanvasDraft?.heightText = height
                return .none

            case .newCanvasConfirmed:
                guard let draft = state.newCanvasDraft else { return .none }
                guard
                    let width = Int(draft.widthText),
                    let height = Int(draft.heightText),
                    (64...8192).contains(width),
                    (64...8192).contains(height)
                else {
                    state.bannerMessage = "幅と高さは64〜8192pxで入力してください"
                    return .none
                }

                paintDocumentClient.createDocument(width, height)
                state.newCanvasDraft = nil
                state.exportSheet = nil
                state.bannerMessage = "新規キャンバスを作成しました"
                state.canvas = CanvasFeature.State()
                state.layerSidebar = LayerSidebarFeature.State()
                state.applyPresentation(paintDocumentClient.lightweightPresentation())
                return .send(.presentationLoaded(paintDocumentClient.presentation()))

            case .saveDocumentRequested:
                guard let pngData = paintDocumentClient.compositePNGData() else {
                    state.bannerMessage = "保存に失敗しました"
                    return .none
                }
                do {
                    let url = try Self.writePNGToDocuments(data: pngData)
                    state.bannerMessage = "保存しました: \(url.lastPathComponent)"
                } catch {
                    state.bannerMessage = "保存に失敗しました"
                }
                return .none

            case .saveToPhotosRequested:
                guard let pngData = paintDocumentClient.compositePNGData() else {
                    state.bannerMessage = "写真への保存に失敗しました"
                    return .none
                }
                return .run { send in
                    do {
                        try await Self.savePNGToPhotoLibrary(data: pngData)
                        await send(.photoLibrarySaveCompleted(.success))
                    } catch let error as PhotoLibrarySaveError {
                        await send(.photoLibrarySaveCompleted(.failure(error)))
                    } catch {
                        await send(.photoLibrarySaveCompleted(.failure(.saveFailed)))
                    }
                }

            case let .photoLibrarySaveCompleted(result):
                switch result {
                case .success:
                    state.bannerMessage = "写真に保存しました"
                case let .failure(error):
                    state.bannerMessage = error.message
                }
                return .none

            case .exportDocumentRequested:
                guard let pngData = paintDocumentClient.compositePNGData() else {
                    state.bannerMessage = "書き出しに失敗しました"
                    return .none
                }
                do {
                    let url = try Self.writePNGToTemporaryDirectory(data: pngData)
                    state.exportSheet = ShareExport(url: url)
                } catch {
                    state.bannerMessage = "書き出しに失敗しました"
                }
                return .none

            case .exportSheetDismissed:
                state.exportSheet = nil
                return .none

            case .bannerDismissed:
                state.bannerMessage = nil
                return .none

            case let .toolSelected(tool):
                state.canvas.currentTool = tool
                state.canvas.previewStyle = state.previewStrokeStyle()
                return .none

            case let .panelCollapseToggled(panel):
                state.toggleCollapse(for: panel)
                return .none

            case let .panelMoved(panel, side):
                state.movePanel(panel, to: side)
                return .none

            case let .panelStackToggled(panel):
                let companion = panel == .brush ? StudioPanelKind.layers : .brush
                if state.panelState(for: panel).side == state.panelState(for: companion).side {
                    state.unstackPanel(panel)
                } else {
                    state.movePanelIntoStack(panel)
                }
                return .none

            case .panelStackOrderSwapRequested:
                state.swapStackOrder()
                return .none

            case .clearActiveLayerButtonTapped, .brushPalette(.delegate(.clearActiveLayer)):
                let activeLayerIndex = state.layerSidebar.activeLayerIndex
                paintDocumentClient.clearLayer(activeLayerIndex)
                if let bufferIndex = state.canvas.layerBuffers.firstIndex(where: { $0.index == activeLayerIndex }) {
                    state.canvas.layerBuffers[bufferIndex].strokes.removeAll()
                    state.canvas.localBufferRevision += 1
                }
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case .activeLayerVisibilityToggled:
                let activeLayerIndex = state.layerSidebar.activeLayerIndex
                guard let layer = state.layerSidebar.layers.first(where: { $0.index == activeLayerIndex }) else {
                    return .none
                }
                paintDocumentClient.setLayerVisibility(activeLayerIndex, !layer.visible)
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case .selectPreviousLayer:
                guard
                    let currentPosition = state.layerSidebar.layers.firstIndex(where: { $0.index == state.layerSidebar.activeLayerIndex }),
                    currentPosition > 0
                else {
                    return .none
                }
                let targetIndex = state.layerSidebar.layers[currentPosition - 1].index
                paintDocumentClient.setActiveLayer(targetIndex)
                state.canvas.activeLayerIndex = targetIndex
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case .selectNextLayer:
                guard
                    let currentPosition = state.layerSidebar.layers.firstIndex(where: { $0.index == state.layerSidebar.activeLayerIndex }),
                    currentPosition < state.layerSidebar.layers.count - 1
                else {
                    return .none
                }
                let targetIndex = state.layerSidebar.layers[currentPosition + 1].index
                paintDocumentClient.setActiveLayer(targetIndex)
                state.canvas.activeLayerIndex = targetIndex
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case .brushPalette:
                state.canvas.previewStyle = state.previewStrokeStyle()
                return .none

            case .layerSidebar(.delegate(.addLayer)):
                paintDocumentClient.addLayer("Layer \(state.layerSidebar.layers.count + 1)")
                state.canvas.activeLayerIndex = state.layerSidebar.layers.count
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .layerSidebar(.delegate(.selectLayer(index))):
                paintDocumentClient.setActiveLayer(index)
                state.canvas.activeLayerIndex = index
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .layerSidebar(.delegate(.toggleVisibility(index))):
                guard let layer = state.layerSidebar.layers.first(where: { $0.index == index }) else {
                    return .none
                }
                paintDocumentClient.setLayerVisibility(index, !layer.visible)
                state.applyPresentation(paintDocumentClient.presentation())
                return .none

            case let .canvas(.delegate(.beginStroke(sample))):
                paintDocumentClient.beginStroke(sample, state.resolvedBrushSettings())
                return .run { send in
                    try? await Task.sleep(for: .milliseconds(24))
                    await send(.deferredPresentationRefresh)
                }
                .cancellable(id: CancelID.deferredPresentationRefresh, cancelInFlight: true)

            case let .canvas(.delegate(.appendSamples(samples))):
                for sample in samples {
                    paintDocumentClient.appendStroke(sample)
                }
                return .run { send in
                    try? await Task.sleep(for: .milliseconds(24))
                    await send(.deferredPresentationRefresh)
                }
                .cancellable(id: CancelID.deferredPresentationRefresh, cancelInFlight: true)

            case .canvas(.delegate(.endStroke)):
                paintDocumentClient.endStroke()
                return .concatenate(
                    .cancel(id: CancelID.deferredPresentationRefresh),
                    .send(.presentationLoaded(paintDocumentClient.presentation()))
                )

            case let .canvas(.delegate(.commitStroke(samples))):
                guard let first = samples.first else { return .none }
                paintDocumentClient.beginStroke(first, state.resolvedBrushSettings())
                for sample in samples.dropFirst() {
                    paintDocumentClient.appendStroke(sample)
                }
                paintDocumentClient.endStroke()
                return .concatenate(
                    .cancel(id: CancelID.deferredPresentationRefresh),
                    .send(.presentationLoaded(paintDocumentClient.presentation()))
                )

            case .layerSidebar, .canvas:
                return .none
            }
        }
    }
}

private extension AppFeature {
    static func writePNGToDocuments(data: Data) throws -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportsDirectory = documentsDirectory.appendingPathComponent("atelierprime", isDirectory: true)
        try FileManager.default.createDirectory(at: exportsDirectory, withIntermediateDirectories: true)
        let url = exportsDirectory.appendingPathComponent(exportFilename())
        try data.write(to: url, options: .atomic)
        return url
    }

    static func writePNGToTemporaryDirectory(data: Data) throws -> URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("atelierprime-export", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        let url = temporaryDirectory.appendingPathComponent(exportFilename())
        try data.write(to: url, options: .atomic)
        return url
    }

    static func exportFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "atelierprime-\(formatter.string(from: Date())).png"
    }

    static func savePNGToPhotoLibrary(data: Data) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoLibrarySaveError.accessDenied
        }

        guard let image = UIImage(data: data) else {
            throw PhotoLibrarySaveError.imageDecodeFailed
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }, completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotoLibrarySaveError.saveFailed)
                }
            })
        }
    }
}
