import ComposableArchitecture
import SwiftUI
import UIKit

struct ContentView: View {
    let store: StoreOf<AppFeature>
    @State private var showsNewCanvasSheet = false
    @State private var newCanvasWidthText = ""
    @State private var newCanvasHeightText = ""
    private var language: AppLanguage { store.appLanguage }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                toolDockColumn
                    .zIndex(30)

                panelRail(for: .brush)
                    .zIndex(20)

                centerStage
                    .zIndex(1)

                panelRail(for: .layers)
                    .zIndex(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                StudioTheme.Gradients.appBackground

                RadialGradient(
                    colors: [
                        StudioTheme.Palette.accentGlow.opacity(0.22),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 30,
                    endRadius: 520
                )

                RadialGradient(
                    colors: [
                        StudioTheme.Palette.coolGlow.opacity(0.20),
                        .clear
                    ],
                    center: .bottomLeading,
                    startRadius: 40,
                    endRadius: 520
                )
            }
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                menuBar
                undoRedoBar
            }
                .zIndex(1000)
        }
        .ignoresSafeArea(edges: [.horizontal, .bottom])
        .task {
            store.send(.task)
        }
        .sheet(item: Binding(
            get: { store.exportSheet },
            set: { _ in store.send(.exportSheetDismissed) }
        )) { export in
            ShareSheet(items: [export.url])
        }
        .sheet(isPresented: $showsNewCanvasSheet) {
            newCanvasSheet
        }
        .overlay(alignment: .bottom) {
            if let bannerMessage = store.bannerMessage {
                BannerToast(message: bannerMessage)
                    .padding(.bottom, 18)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            store.send(.bannerDismissed)
                        }
                    }
            }
        }
        .overlay {
            if let preview = store.timelapseExportPreview {
                TimelapseExportHUD(
                    previewImageData: preview.previewImageData,
                    progress: preview.progress,
                    language: language
                )
            }
        }
    }

    private var canvasSizePresets: [(label: String, width: Int, height: Int)] {
        [
            (
                "現在のサイズ (\(max(Int(store.canvas.canvasSize.width.rounded()), 1)) × \(max(Int(store.canvas.canvasSize.height.rounded()), 1)))",
                max(Int(store.canvas.canvasSize.width.rounded()), 1),
                max(Int(store.canvas.canvasSize.height.rounded()), 1)
            ),
            ("768 × 1024", 768, 1024),
            ("1024 × 1024", 1024, 1024),
            ("1152 × 1536", 1152, 1536),
            ("1536 × 2048", 1536, 2048),
            ("2048 × 2048", 2048, 2048)
        ]
    }

    private var newCanvasSheet: some View {
        NavigationStack {
            Form {
                Section("サイズ") {
                    TextField(StudioStrings.width(language), text: $newCanvasWidthText)
                        .keyboardType(.numberPad)

                    TextField(StudioStrings.height(language), text: $newCanvasHeightText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(StudioStrings.newCanvas(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StudioStrings.cancel(language)) {
                        showsNewCanvasSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(StudioStrings.create(language)) {
                        guard
                            let width = parsedCanvasDimension(from: newCanvasWidthText),
                            let height = parsedCanvasDimension(from: newCanvasHeightText)
                        else { return }
                        store.send(.newCanvasRequested(width: width, height: height))
                        showsNewCanvasSheet = false
                    }
                    .disabled(
                        parsedCanvasDimension(from: newCanvasWidthText) == nil ||
                        parsedCanvasDimension(from: newCanvasHeightText) == nil
                    )
                }
            }
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }

    private func parsedCanvasDimension(from text: String) -> Int? {
        let digits = text.filter(\.isNumber)
        guard let value = Int(digits), (64...8192).contains(value) else { return nil }
        return value
    }

    private var menuBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(StudioTheme.Palette.accent)
                    .frame(width: 6, height: 6)

                Text(StudioStrings.appName(language))
                    .font(StudioTheme.Typography.label(9))
                    .foregroundStyle(StudioTheme.Palette.textPrimary)
            }

            menuBarMenu(StudioStrings.settingsMenu(language)) {
                Menu(StudioStrings.languageMenu(language)) {
                    ForEach(AppLanguage.allCases) { option in
                        Button {
                            store.send(.languageChanged(option))
                        } label: {
                            if option == language {
                                Label(option.title, systemImage: "checkmark")
                            } else {
                                Text(option.title)
                            }
                        }
                    }
                }

                Divider()

                Button(store.brushPanel.isCollapsed ? StudioStrings.showBrushPanel(language) : StudioStrings.hideBrushPanel(language)) {
                    store.send(.panelCollapseToggled(.brush))
                }

                Button(store.layerPanel.isCollapsed ? StudioStrings.showLayerPanel(language) : StudioStrings.hideLayerPanel(language)) {
                    store.send(.panelCollapseToggled(.layers))
                }
            }

            menuBarMenu(StudioStrings.fileMenu(language)) {
                Menu(StudioStrings.newCanvas(language)) {
                    ForEach(canvasSizePresets, id: \.label) { preset in
                        Button(preset.label) {
                            store.send(.newCanvasRequested(width: preset.width, height: preset.height))
                        }
                    }

                    Divider()

                    Button(StudioStrings.customSize(language)) {
                        newCanvasWidthText = "\(max(Int(store.canvas.canvasSize.width.rounded()), 1))"
                        newCanvasHeightText = "\(max(Int(store.canvas.canvasSize.height.rounded()), 1))"
                        showsNewCanvasSheet = true
                    }
                }
                Button(StudioStrings.open(language)) {}
                    .disabled(true)
                Button(StudioStrings.save(language)) {
                    store.send(.saveDocumentRequested)
                }
                Button(StudioStrings.export(language)) {
                    store.send(.exportDocumentRequested)
                }
                Button(StudioStrings.exportTimelapse(language)) {
                    store.send(.exportTimelapseRequested)
                }
            }

            menuBarMenu(StudioStrings.editMenu(language)) {
                Button(StudioStrings.clearActiveLayer(language)) {
                    store.send(.clearActiveLayerButtonTapped)
                }

                Button(StudioStrings.refreshView(language)) {
                    store.send(.refreshPresentationRequested)
                }
            }

            menuBarMenu(StudioStrings.pageMenu(language)) {
                Button(StudioStrings.pagesAdd(language)) {}
                    .disabled(true)
                Button(StudioStrings.pagesDuplicate(language)) {}
                    .disabled(true)
                Button(StudioStrings.pagesDelete(language)) {}
                    .disabled(true)
            }

            menuBarMenu(StudioStrings.layerMenu(language)) {
                Button(StudioStrings.addLayer(language)) {
                    store.send(.layerSidebar(.addLayerButtonTapped))
                }

                Button(activeLayerIsVisible ? StudioStrings.hideActiveLayer(language) : StudioStrings.showActiveLayer(language)) {
                    store.send(.activeLayerVisibilityToggled)
                }
                .disabled(activeLayer == nil)

                Divider()

                Button(StudioStrings.selectUpperLayer(language)) {
                    store.send(.selectPreviousLayer)
                }
                .disabled(!canSelectPreviousLayer)

                Button(StudioStrings.selectLowerLayer(language)) {
                    store.send(.selectNextLayer)
                }
                .disabled(!canSelectNextLayer)

                Divider()

                Button(StudioStrings.clearActiveLayer(language)) {
                    store.send(.clearActiveLayerButtonTapped)
                }
                .disabled(activeLayer == nil)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            ZStack {
                StudioTheme.Gradients.surface

                LinearGradient(
                    colors: [
                        StudioTheme.Palette.accentBright.opacity(0.18),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.05),
                        StudioTheme.Palette.toolbarHighlight
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StudioTheme.Palette.accentSoft.opacity(0.28))
                .frame(height: 1)
        }
        .contentShape(Rectangle())
        .compositingGroup()
        .shadow(color: StudioTheme.Palette.accentGlow.opacity(0.14), radius: 18, y: 8)
    }

    private var undoRedoBar: some View {
        HStack(spacing: 4) {
            Button {
                store.send(.undoRequested)
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioTheme.Palette.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .minimumHitTarget(30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(StudioTheme.Palette.accent.opacity(0.18))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.accentSoft.opacity(0.42), lineWidth: 1)
            }

            Button {
                store.send(.redoRequested)
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioTheme.Palette.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .minimumHitTarget(30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(StudioTheme.Palette.accent.opacity(0.18))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.accentSoft.opacity(0.42), lineWidth: 1)
            }
            
            Button {
                store.send(.clearActiveLayerButtonTapped)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioTheme.Palette.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .minimumHitTarget(30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(StudioTheme.Palette.accent.opacity(0.14))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.accentSoft.opacity(0.34), lineWidth: 1)
            }
            .disabled(activeLayer == nil)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            ZStack {
                StudioTheme.Gradients.surface

                StudioTheme.Gradients.accentBar
                    .opacity(0.12)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.04),
                        StudioTheme.Palette.toolbarHighlight
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StudioTheme.Palette.accentSoft.opacity(0.24))
                .frame(height: 1)
        }
    }

    private func menuBarMenu<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            Text(title)
                .font(StudioTheme.Typography.label(9))
                .foregroundStyle(StudioTheme.Palette.textPrimary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .minimumHitTarget(28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(StudioTheme.Palette.toolbarFill)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(StudioTheme.Palette.accentSoft.opacity(0.22), lineWidth: 1)
                }
        }
    }

    private var activeLayer: LayerRowModel? {
        store.layerSidebar.layers.first { $0.index == store.layerSidebar.activeLayerIndex }
    }

    private var activeLayerIsVisible: Bool {
        activeLayer?.visible ?? false
    }

    private var activeLayerPosition: Int? {
        store.layerSidebar.layers.firstIndex { $0.index == store.layerSidebar.activeLayerIndex }
    }

    private var canSelectPreviousLayer: Bool {
        guard let activeLayerPosition else { return false }
        return activeLayerPosition > 0
    }

    private var canSelectNextLayer: Bool {
        guard let activeLayerPosition else { return false }
        return activeLayerPosition < store.layerSidebar.layers.count - 1
    }

    private var centerStage: some View {
        ZStack {
            ZStack {
                StudioTheme.Gradients.stage

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                StudioTheme.Palette.cardFillStrong,
                                .clear,
                                StudioTheme.Palette.accentBright.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .mask(
                        Rectangle()
                            .rotationEffect(.degrees(-18))
                            .scaleEffect(1.6)
                    )
            }
            .overlay {
                ZStack {
                    Circle()
                        .fill(StudioTheme.Palette.cardFillStrong)
                        .frame(width: 360, height: 360)
                        .blur(radius: 100)
                        .offset(x: -320, y: -180)

                    Circle()
                        .fill(StudioTheme.Palette.accent.opacity(0.24))
                        .frame(width: 320, height: 320)
                        .blur(radius: 90)
                        .offset(x: 380, y: 220)

                    Circle()
                        .fill(StudioTheme.Palette.coolGlow.opacity(0.18))
                        .frame(width: 280, height: 280)
                        .blur(radius: 90)
                        .offset(x: -220, y: 260)
                }
            }
            .overlay {
                DiagonalStageLines()
                    .opacity(0.16)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }

            VStack {
                ZStack {
                    stageChrome

                    CanvasView(
                        store: store.scope(
                            state: \.canvas,
                            action: \.canvas
                        )
                    )
                    .padding(14)

                    if store.isHydrating {
                        ProgressView()
                            .controlSize(.large)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                .padding(.horizontal, 14)
                .padding(.top, 6)
            }
        }
    }

    private var toolDockColumn: some View {
        VStack {
            toolDock
                .padding(.leading, 10)
                .padding(.top, 20)
            Spacer(minLength: 0)
        }
        .frame(width: 74)
    }

    private func panelRail(for panel: StudioPanelKind) -> some View {
        let panelState = panelState(for: panel)

        return VStack(spacing: 12) {
            studioPanel(for: panel)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .frame(width: panelState.isCollapsed ? 74 : 304)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func studioPanel(for panel: StudioPanelKind) -> some View {
        let panelState = panelState(for: panel)

        StudioPanelShell(
            title: panel.title(language),
            isCollapsed: panelState.isCollapsed,
            onToggleCollapse: { store.send(.panelCollapseToggled(panel)) }
        ) {
            switch panel {
            case .brush:
                BrushPaletteView(
                    store: store.scope(
                        state: \.brushPalette,
                        action: \.brushPalette
                    ),
                    currentTool: store.canvas.currentTool,
                    hasSelection: store.canvas.selection != nil,
                    transformPreviewOffset: store.canvas.transformPreviewOffset,
                    transformPreviewScale: store.canvas.transformPreviewScale,
                    language: language,
                    showsTitle: false
                )
            case .layers:
                LayerSidebarView(
                    store: store.scope(
                        state: \.layerSidebar,
                        action: \.layerSidebar
                    ),
                    layerSnapshots: store.canvas.renderSnapshot?.layers ?? [],
                    language: language,
                    showsTitle: false
                )
            }
        }
        .frame(maxHeight: panelState.isCollapsed ? 68 : .infinity, alignment: .top)
    }

    private func panelState(for panel: StudioPanelKind) -> StudioPanelLayoutState {
        switch panel {
        case .brush:
            return store.brushPanel
        case .layers:
            return store.layerPanel
        }
    }

    private var stageChrome: some View {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(StudioTheme.Gradients.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.03),
                                StudioTheme.Palette.accentBright.opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .mask(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                    )
            }
            .shadow(color: .black.opacity(0.42), radius: 28, y: 18)
    }

    private var toolDock: some View {
        VStack(spacing: 8) {
            ForEach(studioTools) { tool in
                let isActive = store.canvas.currentTool == tool

                Button {
                    store.send(.toolSelected(tool))
                } label: {
                    Image(systemName: tool.systemImage)
                        .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isActive ? Color.white : StudioTheme.Palette.textSecondary)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isActive ? StudioTheme.Palette.accent : StudioTheme.Palette.cardFillStrong)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(isActive ? 0.12 : 0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .minimumHitTarget()
                .accessibilityLabel(tool.localizedTitle(language))
            }

            Spacer()
        }
        .padding(8)
        .frame(width: 60)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(StudioTheme.Palette.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(StudioTheme.Palette.hairline, lineWidth: 1)
        )
    }

}
