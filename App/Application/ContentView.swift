import ComposableArchitecture
import SwiftUI
import UIKit

struct ContentView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                panelRail(for: .leading)

                centerStage

                panelRail(for: .trailing)
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
    }

    private var menuBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(StudioTheme.Palette.accent)
                    .frame(width: 6, height: 6)

                Text("atelierprime")
                    .font(StudioTheme.Typography.label(9))
                    .foregroundStyle(StudioTheme.Palette.textPrimary)
            }

            menuBarMenu("設定") {
                Button(store.brushPanel.isCollapsed ? "ブラシパネルを表示" : "ブラシパネルを隠す") {
                    store.send(.panelCollapseToggled(.brush))
                }

                Button(store.layerPanel.isCollapsed ? "レイヤーパネルを表示" : "レイヤーパネルを隠す") {
                    store.send(.panelCollapseToggled(.layers))
                }

                Divider()

                Button(isStacked(.brush) || isStacked(.layers) ? "パネルの重なりを解除" : "パネルを重ねる") {
                    store.send(.panelStackToggled(.brush))
                }

                Button("スタック順を入れ替え") {
                    store.send(.panelStackOrderSwapRequested)
                }
                .disabled(!isStacked(.brush) && !isStacked(.layers))
            }

            menuBarMenu("ファイル") {
                Button("新規キャンバス") {}
                    .disabled(true)
                Button("開く") {}
                    .disabled(true)
                Button("保存") {
                    store.send(.saveDocumentRequested)
                }
                Button("書き出し") {
                    store.send(.exportDocumentRequested)
                }
                Button("タイムラプスを書き出し") {
                    store.send(.exportTimelapseRequested)
                }
            }

            menuBarMenu("編集") {
                Button("アクティブレイヤーをクリア") {
                    store.send(.clearActiveLayerButtonTapped)
                }

                Button("表示を更新") {
                    store.send(.refreshPresentationRequested)
                }
            }

            menuBarMenu("ページ管理") {
                Button("ページを追加") {}
                    .disabled(true)
                Button("ページを複製") {}
                    .disabled(true)
                Button("ページを削除") {}
                    .disabled(true)
            }

            menuBarMenu("レイヤー") {
                Button("新規レイヤー") {
                    store.send(.layerSidebar(.addLayerButtonTapped))
                }

                Button(activeLayerIsVisible ? "アクティブレイヤーを非表示" : "アクティブレイヤーを表示") {
                    store.send(.activeLayerVisibilityToggled)
                }
                .disabled(activeLayer == nil)

                Divider()

                Button("ひとつ上のレイヤーを選択") {
                    store.send(.selectPreviousLayer)
                }
                .disabled(!canSelectPreviousLayer)

                Button("ひとつ下のレイヤーを選択") {
                    store.send(.selectNextLayer)
                }
                .disabled(!canSelectNextLayer)

                Divider()

                Button("アクティブレイヤーをクリア") {
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
                StudioTheme.Palette.overlayBlack.opacity(0.98)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.05),
                        StudioTheme.Palette.cardFill.opacity(0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StudioTheme.Palette.cardBorder.opacity(0.95))
                .frame(height: 1)
        }
        .contentShape(Rectangle())
        .compositingGroup()
        .shadow(color: .black.opacity(0.32), radius: 14, y: 6)
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
                    .fill(StudioTheme.Palette.cardFillStrong.opacity(0.94))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.cardBorder.opacity(0.9), lineWidth: 1)
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
                    .fill(StudioTheme.Palette.cardFillStrong.opacity(0.94))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.cardBorder.opacity(0.9), lineWidth: 1)
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
                    .fill(StudioTheme.Palette.cardFillStrong.opacity(0.94))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(StudioTheme.Palette.cardBorder.opacity(0.9), lineWidth: 1)
            }
            .disabled(activeLayer == nil)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            ZStack {
                StudioTheme.Palette.overlayBlack.opacity(0.95)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.04),
                        StudioTheme.Palette.cardFill.opacity(0.14)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StudioTheme.Palette.cardBorder.opacity(0.95))
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
                        .fill(StudioTheme.Palette.cardFillStrong.opacity(0.92))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(StudioTheme.Palette.cardBorder.opacity(0.8), lineWidth: 1)
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
                HStack(alignment: .top, spacing: 14) {
                    toolDock

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
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
            }
        }
    }

    @ViewBuilder
    private func panelRail(for side: StudioPanelSide) -> some View {
        let panels = panels(on: side)

        if panels.isEmpty {
            Color.clear
                .frame(width: 0)
        } else {
            VStack(spacing: 12) {
                ForEach(panels, id: \.self) { panel in
                    studioPanel(for: panel)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
            .frame(width: railWidth(for: panels))
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func railWidth(for panels: [StudioPanelKind]) -> CGFloat {
        panels.contains { !panelState(for: $0).isCollapsed } ? 304 : 74
    }

    @ViewBuilder
    private func studioPanel(for panel: StudioPanelKind) -> some View {
        let panelState = panelState(for: panel)
        let isStacked = isStacked(panel)

        StudioPanelShell(
            title: panel.title,
            side: panelState.side,
            isCollapsed: panelState.isCollapsed,
            isStacked: isStacked,
            onToggleCollapse: { store.send(.panelCollapseToggled(panel)) },
            onToggleStack: { store.send(.panelStackToggled(panel)) },
            onSwapStackOrder: { store.send(.panelStackOrderSwapRequested) },
            onDragEnded: { translation in
                handlePanelDragEnded(panel, translation: translation)
            }
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
                    showsTitle: false
                )
            case .layers:
                LayerSidebarView(
                    store: store.scope(
                        state: \.layerSidebar,
                        action: \.layerSidebar
                    ),
                    showsTitle: false
                )
            }
        }
        .frame(maxHeight: panelState.isCollapsed ? 68 : (isStacked ? 332 : .infinity), alignment: .top)
    }

    private func isStacked(_ panel: StudioPanelKind) -> Bool {
        let companion = panel == .brush ? StudioPanelKind.layers : .brush
        return panelState(for: panel).side == panelState(for: companion).side
    }

    private func panelState(for panel: StudioPanelKind) -> StudioPanelLayoutState {
        switch panel {
        case .brush:
            return store.brushPanel
        case .layers:
            return store.layerPanel
        }
    }

    private func panels(on side: StudioPanelSide) -> [StudioPanelKind] {
        store.stackedPanelOrder.filter { panelState(for: $0).side == side }
    }

    private func handlePanelDragEnded(_ panel: StudioPanelKind, translation: CGSize) {
        let horizontalThreshold: CGFloat = 70
        let verticalThreshold: CGFloat = 42

        if translation.width > horizontalThreshold {
            store.send(.panelMoved(panel, .trailing))
            return
        }

        if translation.width < -horizontalThreshold {
            store.send(.panelMoved(panel, .leading))
            return
        }

        if isStacked(panel), abs(translation.height) > verticalThreshold {
            store.send(.panelStackOrderSwapRequested)
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
        VStack(spacing: 10) {
            ForEach(studioTools) { tool in
                let isActive = store.canvas.currentTool == tool

                Button {
                    store.send(.toolSelected(tool))
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 16, weight: .bold))
                        Text(tool.title)
                            .font(StudioTheme.Typography.label(9))
                    }
                    .foregroundStyle(isActive ? Color.white : StudioTheme.Palette.textSecondary)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isActive ? StudioTheme.Palette.accent : StudioTheme.Palette.cardFillStrong)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(isActive ? 0.12 : 0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .minimumHitTarget()
            }

            Spacer()
        }
        .padding(10)
        .frame(width: 82)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(StudioTheme.Palette.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(StudioTheme.Palette.hairline, lineWidth: 1)
        )
    }

}

struct MinimumHitTargetModifier: ViewModifier {
    let minSize: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(minWidth: minSize, minHeight: minSize)
            .contentShape(Rectangle())
    }
}

extension View {
    func minimumHitTarget(_ minSize: CGFloat = 44) -> some View {
        modifier(MinimumHitTargetModifier(minSize: minSize))
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct BannerToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(StudioTheme.Typography.label(13))
            .foregroundStyle(.white.opacity(0.94))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(StudioTheme.Palette.overlayBlack.opacity(0.96))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
    }
}

private struct CanvasHUD: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(StudioTheme.Typography.mono(10))
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(StudioTheme.Typography.title(12))
                .foregroundStyle(StudioTheme.Palette.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(StudioTheme.Palette.overlayBlack)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
        )
    }
}

private struct DiagonalStageLines: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                stride(from: -height, through: width + height, by: 36).forEach { offset in
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset - height, y: height))
                }
            }
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private let studioTools: [StudioToolKind] = [.brush, .erase, .fill, .select, .move, .shape]

private struct StudioPanelShell<Content: View>: View {
    let title: String
    let side: StudioPanelSide
    let isCollapsed: Bool
    let isStacked: Bool
    let onToggleCollapse: () -> Void
    let onToggleStack: () -> Void
    let onSwapStackOrder: () -> Void
    let onDragEnded: (CGSize) -> Void
    let content: Content

    @State private var dragOffset: CGSize = .zero
    @GestureState private var isDragging = false

    init(
        title: String,
        side: StudioPanelSide,
        isCollapsed: Bool,
        isStacked: Bool,
        onToggleCollapse: @escaping () -> Void,
        onToggleStack: @escaping () -> Void,
        onSwapStackOrder: @escaping () -> Void,
        onDragEnded: @escaping (CGSize) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.side = side
        self.isCollapsed = isCollapsed
        self.isStacked = isStacked
        self.onToggleCollapse = onToggleCollapse
        self.onToggleStack = onToggleStack
        self.onSwapStackOrder = onSwapStackOrder
        self.onDragEnded = onDragEnded
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if !isCollapsed {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(panelBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if isDragging {
                dragBadge
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            Capsule(style: .continuous)
                .fill(StudioTheme.Gradients.accentBar)
                .frame(width: isCollapsed ? 26 : 92, height: 5)
                .padding(.top, 8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(StudioTheme.Palette.hairline, lineWidth: 1)
        )
        .offset(dragOffset)
        .scaleEffect(isDragging ? 1.015 : 1.0)
        .rotationEffect(.degrees(Double(dragOffset.width / 42)))
        .shadow(color: Color.black.opacity(0.22), radius: 18, y: 10)
        .shadow(color: StudioTheme.Palette.accent.opacity(isDragging ? 0.18 : 0.0), radius: 20, y: 10)
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: dragOffset)
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: isDragging)
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(StudioTheme.Palette.accent.opacity(0.9))
                    .frame(width: 4, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(StudioTheme.Typography.title(19))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)

                    Text(isStacked ? "Drag sideways to move, up/down to reorder" : "Drag sideways to move")
                        .font(StudioTheme.Typography.mono(10))
                        .foregroundStyle(StudioTheme.Palette.textMuted)
                        .lineLimit(1)
                }
            }

            if !isCollapsed {
                Spacer(minLength: 6)

                HStack(spacing: 6) {
                    panelButton(systemName: isStacked ? "square.split.2x1" : "square.split.1x2", isActive: isStacked, action: onToggleStack)
                    if isStacked {
                        panelButton(systemName: "arrow.up.arrow.down", isActive: false, action: onSwapStackOrder)
                    }
                }
            }

            panelButton(systemName: isCollapsed ? "chevron.right" : "chevron.left", isActive: false, action: onToggleCollapse)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .gesture(panelDragGesture)
    }

    private var panelBackground: LinearGradient {
        StudioTheme.Gradients.panel
    }

    private var dragBadge: some View {
        Text(side == .leading ? "Drop to right rail" : "Drop to left rail")
            .font(StudioTheme.Typography.mono(10))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
    }

    private var panelDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                dragOffset = .zero
                onDragEnded(value.translation)
            }
    }

    private func panelButton(systemName: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isActive ? .white : .white.opacity(0.68))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isActive ? StudioTheme.Palette.accent : StudioTheme.Palette.cardFillStrong)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
