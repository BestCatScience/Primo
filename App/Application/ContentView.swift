import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        VStack(spacing: 0) {
            topBar

            HStack(spacing: 0) {
                panelRail(for: .leading)

                centerStage

                panelRail(for: .trailing)
            }

            bottomBar
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.12, blue: 0.15),
                    Color(red: 0.08, green: 0.09, blue: 0.11)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .task {
            store.send(.task)
        }
    }

    private var topBar: some View {
        HStack(spacing: 18) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.61, blue: 0.31),
                                Color(red: 0.79, green: 0.35, blue: 0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "scribble.variable")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("atelierprime")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .tracking(0.8)
                    Text("Studio Workspace / Illustration")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.52))
                }
            }

            HStack(spacing: 10) {
                chromePill(title: activeLayerName, systemImage: "square.3.layers.3d.down.right")
                chromePill(title: "\(Int(store.brushPalette.brushRadius)) px", systemImage: "pencil.line")
                chromePill(title: "\(Int(store.brushPalette.brushOpacity * 100))%", systemImage: "circle.lefthalf.filled")
            }

            Spacer()

            HStack(spacing: 10) {
                toolbarAction(title: "Navigator", systemImage: "square.on.square.dashed")
                toolbarAction(title: "History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")

                Button {
                    store.send(.clearActiveLayerButtonTapped)
                } label: {
                    Label("Clear Layer", systemImage: "trash")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.9))

                Button {
                    store.send(.task)
                } label: {
                    Label("Sync", systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.94, green: 0.63, blue: 0.36),
                                            Color(red: 0.85, green: 0.41, blue: 0.24)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.17, blue: 0.21),
                    Color(red: 0.10, green: 0.11, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var centerStage: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.17, green: 0.19, blue: 0.22),
                    Color(red: 0.10, green: 0.11, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 320, height: 320)
                        .blur(radius: 90)
                        .offset(x: -260, y: -140)

                    Circle()
                        .fill(Color(red: 0.94, green: 0.55, blue: 0.27).opacity(0.18))
                        .frame(width: 280, height: 280)
                        .blur(radius: 70)
                        .offset(x: 300, y: 180)
                }
            }

            HStack(spacing: 18) {
                toolDock

                ZStack {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.23, green: 0.24, blue: 0.28),
                                    Color(red: 0.14, green: 0.15, blue: 0.19)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.32), radius: 28, y: 18)

                    CanvasView(
                        store: store.scope(
                            state: \.canvas,
                            action: \.canvas
                        )
                    )
                    .padding(18)

                    VStack {
                        HStack {
                            CanvasHUD(title: "Document", value: "1152 x 1536")
                            Spacer()
                            CanvasHUD(title: "Zoom", value: "75% - 400%")
                        }
                        Spacer()
                        HStack {
                            Spacer()
                            CanvasHUD(title: "Input", value: "Apple Pencil / Pinch")
                        }
                    }
                    .padding(20)

                    if store.isHydrating {
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Preparing studio...")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.86))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
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

    private var activeLayerName: String {
        store.layerSidebar.layers.first(where: { $0.index == store.layerSidebar.activeLayerIndex })?.name ?? "Layer \(store.layerSidebar.activeLayerIndex + 1)"
    }

    private var toolDock: some View {
        VStack(spacing: 14) {
            ForEach(studioTools) { tool in
                Button(action: {}) {
                    VStack(spacing: 6) {
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 17, weight: .bold))
                        Text(tool.title)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(tool.isPrimary ? Color.white : Color.white.opacity(0.75))
                    .frame(width: 64, height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(tool.isPrimary ? Color(red: 0.89, green: 0.45, blue: 0.24) : Color.white.opacity(0.06))
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
        .frame(width: 88)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Text("Workspace Status")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))

            Text("Layer Count \(store.layerSidebar.layers.count)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58))

            Text("Opacity \(Int(store.brushPalette.brushOpacity * 100))%")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58))

            Spacer()

            Text("Clip-inspired studio chrome")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.54))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.35))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
        }
    }

    private func chromePill(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.72))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
    }

    private func toolbarAction(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .foregroundStyle(.white.opacity(0.76))
    }
}

private struct CanvasHUD: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
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
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 24, y: 14)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
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
        .background(Color.white.opacity(0.03))
    }

    private var panelBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.17, green: 0.18, blue: 0.21),
                Color(red: 0.11, green: 0.12, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func panelButton(systemName: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isActive ? .white : .white.opacity(0.68))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? Color(red: 0.89, green: 0.45, blue: 0.24) : Color.white.opacity(0.06))
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
