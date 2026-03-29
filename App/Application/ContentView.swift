import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                panelRail(for: .leading)

                centerStage

                panelRail(for: .trailing)
            }

            bottomBar
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
        .ignoresSafeArea()
        .task {
            store.send(.task)
        }
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
                HStack(alignment: .top, spacing: 18) {
                    toolDock

                    ZStack {
                        stageChrome

                        CanvasView(
                            store: store.scope(
                                state: \.canvas,
                                action: \.canvas
                            )
                        )
                        .padding(18)

                        if store.isHydrating {
                            ProgressView()
                                .controlSize(.large)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
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
            VStack(spacing: 14) {
                ForEach(panels, id: \.self) { panel in
                    studioPanel(for: panel)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 18)
            .frame(width: railWidth(for: panels))
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func railWidth(for panels: [StudioPanelKind]) -> CGFloat {
        panels.contains { !panelState(for: $0).isCollapsed } ? 336 : 86
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
            onMoveLeading: { store.send(.panelMoved(panel, .leading)) },
            onMoveTrailing: { store.send(.panelMoved(panel, .trailing)) },
            onToggleStack: { store.send(.panelStackToggled(panel)) },
            onSwapStackOrder: { store.send(.panelStackOrderSwapRequested) }
        ) {
            switch panel {
            case .brush:
                BrushPaletteView(
                    store: store.scope(
                        state: \.brushPalette,
                        action: \.brushPalette
                    ),
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
        .frame(maxHeight: panelState.isCollapsed ? 74 : (isStacked ? 360 : .infinity), alignment: .top)
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

    private var stageChrome: some View {
        RoundedRectangle(cornerRadius: 38, style: .continuous)
            .fill(StudioTheme.Gradients.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 38, style: .continuous)
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
                RoundedRectangle(cornerRadius: 38, style: .continuous)
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
                        RoundedRectangle(cornerRadius: 38, style: .continuous)
                    )
            }
            .shadow(color: .black.opacity(0.42), radius: 34, y: 22)
    }

    private var toolDock: some View {
        VStack(spacing: 14) {
            ForEach(studioTools) { tool in
                Button(action: {}) {
                    VStack(spacing: 6) {
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 18, weight: .bold))
                        Text(tool.title)
                            .font(StudioTheme.Typography.label(10))
                    }
                    .foregroundStyle(tool.isPrimary ? Color.white : StudioTheme.Palette.textSecondary)
                    .frame(width: 64, height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(tool.isPrimary ? StudioTheme.Palette.accent : StudioTheme.Palette.cardFillStrong)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(tool.isPrimary ? 0.12 : 0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(12)
        .frame(width: 96)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(StudioTheme.Palette.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(StudioTheme.Palette.hairline, lineWidth: 1)
        )
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Text("Layer Count \(store.layerSidebar.layers.count)")
                .font(StudioTheme.Typography.mono(11))
                .foregroundStyle(StudioTheme.Palette.textMuted)

            Text("Opacity \(Int(store.brushPalette.brushOpacity * 100))%")
                .font(StudioTheme.Typography.mono(11))
                .foregroundStyle(StudioTheme.Palette.textMuted)

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(StudioTheme.Palette.overlayBlack)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(StudioTheme.Palette.cardBorder)
                .frame(height: 1)
        }
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

private struct StudioTool: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let isPrimary: Bool
}

private let studioTools: [StudioTool] = [
    StudioTool(id: "brush", title: "Brush", systemImage: "paintbrush.pointed", isPrimary: true),
    StudioTool(id: "erase", title: "Erase", systemImage: "eraser", isPrimary: false),
    StudioTool(id: "lasso", title: "Select", systemImage: "lasso", isPrimary: false),
    StudioTool(id: "move", title: "Move", systemImage: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left", isPrimary: false),
    StudioTool(id: "shape", title: "Shape", systemImage: "square.on.circle", isPrimary: false)
]

private struct StudioPanelShell<Content: View>: View {
    let title: String
    let side: StudioPanelSide
    let isCollapsed: Bool
    let isStacked: Bool
    let onToggleCollapse: () -> Void
    let onMoveLeading: () -> Void
    let onMoveTrailing: () -> Void
    let onToggleStack: () -> Void
    let onSwapStackOrder: () -> Void
    let content: Content

    init(
        title: String,
        side: StudioPanelSide,
        isCollapsed: Bool,
        isStacked: Bool,
        onToggleCollapse: @escaping () -> Void,
        onMoveLeading: @escaping () -> Void,
        onMoveTrailing: @escaping () -> Void,
        onToggleStack: @escaping () -> Void,
        onSwapStackOrder: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.side = side
        self.isCollapsed = isCollapsed
        self.isStacked = isStacked
        self.onToggleCollapse = onToggleCollapse
        self.onMoveLeading = onMoveLeading
        self.onMoveTrailing = onMoveTrailing
        self.onToggleStack = onToggleStack
        self.onSwapStackOrder = onSwapStackOrder
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if !isCollapsed {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(panelBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .top) {
            Capsule(style: .continuous)
                .fill(StudioTheme.Gradients.accentBar)
                .frame(width: isCollapsed ? 26 : 92, height: 5)
                .padding(.top, 10)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(StudioTheme.Palette.hairline, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 24, y: 14)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(StudioTheme.Typography.title(22))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)

            if !isCollapsed {
                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    panelButton(systemName: "rectangle.leadinghalf.inset.filled", isActive: side == .leading, action: onMoveLeading)
                    panelButton(systemName: "rectangle.trailinghalf.inset.filled", isActive: side == .trailing, action: onMoveTrailing)
                    panelButton(systemName: isStacked ? "square.split.2x1" : "square.split.1x2", isActive: isStacked, action: onToggleStack)
                    if isStacked {
                        panelButton(systemName: "arrow.up.arrow.down", isActive: false, action: onSwapStackOrder)
                    }
                }
            }

            panelButton(systemName: isCollapsed ? "chevron.right" : "chevron.left", isActive: false, action: onToggleCollapse)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(StudioTheme.Palette.cardFill)
    }

    private var panelBackground: LinearGradient {
        StudioTheme.Gradients.panel
    }

    private func panelButton(systemName: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isActive ? .white : .white.opacity(0.68))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
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
