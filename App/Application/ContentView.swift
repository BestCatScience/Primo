import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        HStack(spacing: 0) {
            panelRail(for: .leading)

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.84, green: 0.86, blue: 0.82),
                        Color(red: 0.76, green: 0.77, blue: 0.73)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                CanvasView(
                    store: store.scope(
                        state: \.canvas,
                        action: \.canvas
                    )
                )
                .padding(28)

                if store.isHydrating {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Preparing studio...")
                            .font(.headline)
                            .foregroundStyle(Color.black.opacity(0.7))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }

            panelRail(for: .trailing)
        }
        .task {
            store.send(.task)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 18)
            .frame(width: railWidth(for: panels))
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func railWidth(for panels: [StudioPanelKind]) -> CGFloat {
        panels.contains { !panelState(for: $0).isCollapsed } ? 312 : 78
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
}

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
        .background(panelBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, y: 10)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
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
    }

    private var panelBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.93, blue: 0.89),
                Color(red: 0.90, green: 0.88, blue: 0.84)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func panelButton(systemName: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isActive ? .white : .black.opacity(0.72))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? Color.black : Color.white.opacity(0.75))
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
