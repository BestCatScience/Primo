import SwiftUI

extension ContentView {
    func dismissBrushSettingsPopover() {
        if store.brushPalette.ui.showsBrushSettingsPopover {
            store.send(.brushPalette(.binding(.set(\.ui.showsBrushSettingsPopover, false))))
        }
    }

    var centerStage: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.97, blue: 0.95),
                    Color(red: 0.95, green: 0.96, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                DiagonalStageLines()
                    .opacity(0.035)
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
                    .padding(10)

                    if store.isHydrating {
                        ProgressView()
                            .controlSize(.large)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 10)
                .padding(.top, 10)
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissBrushSettingsPopover()
            }
        )
    }

    var toolDockColumn: some View {
        VStack {
            toolDock
                .padding(.top, 0)

            toolDockMetrics
                .padding(.top, 10)

            toolDockColorCluster
                .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .frame(width: 72)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.99, blue: 0.98),
                    Color(red: 0.96, green: 0.96, blue: 0.97)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    func panelRail(for panel: StudioPanelKind) -> some View {
        let panelState = panelState(for: panel)
        let dragThreshold: CGFloat = 80

        let panelDragGesture = DragGesture(minimumDistance: 12)
            .onEnded { value in
                let translation = value.translation.width

                switch panel {
                case .brush:
                    if panelState.isCollapsed {
                        if translation > dragThreshold {
                            store.send(.panelCollapseToggled(panel))
                        }
                    } else if translation < -dragThreshold {
                        store.send(.panelCollapseToggled(panel))
                    }
                case .layers:
                    if panelState.isCollapsed {
                        if translation < -dragThreshold {
                            store.send(.panelCollapseToggled(panel))
                        }
                    } else if translation > dragThreshold {
                        store.send(.panelCollapseToggled(panel))
                    }
                }
            }

        return VStack(spacing: 12) {
            studioPanel(for: panel)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .frame(width: panelState.isCollapsed ? 64 : (panel == .layers ? 290 : 332))
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: panel == .brush ? .trailing : .leading) {
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(width: 18)
                .gesture(panelDragGesture)
                .onTapGesture {
                    if panelState.isCollapsed {
                        store.send(.panelCollapseToggled(panel))
                    }
                }
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                if panel != .brush {
                    dismissBrushSettingsPopover()
                }
            }
        )
    }

    @ViewBuilder
    func studioPanel(for panel: StudioPanelKind) -> some View {
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
                    transformPreviewRotationDegrees: store.canvas.transformPreviewRotationDegrees,
                    language: language,
                    showsTitle: false,
                    onSelectTool: { tool in
                        store.send(.toolSelected(tool))
                    }
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
        .frame(maxHeight: panelState.isCollapsed ? 50 : .infinity, alignment: .top)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    func panelState(for panel: StudioPanelKind) -> StudioPanelLayoutState {
        switch panel {
        case .brush:
            return store.brushPanel
        case .layers:
            return store.layerPanel
        }
    }

    var stageChrome: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.96),
                        Color(red: 0.96, green: 0.97, blue: 0.99)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 24, y: 10)
    }

    var toolDock: some View {
        VStack(spacing: 8) {
            ForEach(studioTools) { tool in
                let isActive = store.canvas.currentTool == tool

                toolDockItem(tool: tool, isActive: isActive)
                .minimumHitTarget()
                .accessibilityLabel(tool.localizedTitle(language))
            }

            Spacer()
        }
        .padding(8)
        .frame(width: 54)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissBrushSettingsPopover()
            }
        )
    }

    func toolDockItem(tool: StudioToolKind, isActive: Bool) -> some View {
        Image(systemName: tool.systemImage)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(isActive ? Color(red: 0.13, green: 0.45, blue: 0.88) : Color.black.opacity(0.54))
            .frame(width: 38, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? Color(red: 0.86, green: 0.93, blue: 1.0) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .onTapGesture {
                store.send(.toolSelected(tool))
            }
            .onLongPressGesture(minimumDuration: 0.45) {
                if tool == .brush || tool == .erase {
                    store.send(.toolLongPressed(tool))
                }
            }
    }

    var toolDockMetrics: some View {
        VStack(spacing: 8) {
            toolMetricBubble(text: "\(Int(store.brushPalette.brush.storedRadius(for: store.canvas.currentTool).rounded()))")
            toolMetricBubble(text: "\(Int((store.brushPalette.brush.opacity * 100).rounded()))")
        }
    }

    func toolMetricBubble(text: String) -> some View {
        Text(text)
            .font(StudioTheme.Typography.title(18))
            .foregroundStyle(Color.black.opacity(0.62))
            .frame(width: 46, height: 46)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.92))
            )
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }

    var toolDockColorCluster: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topLeading) {
                toolDockColorSlotButton(
                    slot: .secondary,
                    size: 28,
                    cornerRadius: 8
                )
                .offset(x: 6, y: 4)

                toolDockColorSlotButton(
                    slot: .primary,
                    size: 40,
                    cornerRadius: 10
                )
                .offset(x: 18, y: 18)

                toolDockColorSlotButton(
                    slot: .transparent,
                    size: 28,
                    cornerRadius: 8
                )
                .offset(x: -2, y: 46)
            }
            .frame(width: 62, height: 76)

            HStack(spacing: 6) {
                toolDockActionButton(systemImage: "arrow.triangle.2.circlepath") {
                    let primary = store.brushPalette.brush.color
                    let secondary = store.brushPalette.brush.secondaryColor
                    store.send(.brushPalette(.binding(.set(\.brush.color, secondary))))
                    store.send(.brushPalette(.binding(.set(\.brush.secondaryColor, primary))))
                }
            }
        }
        .padding(.vertical, 8)
    }

    func toolDockColorSlotButton(
        slot: BrushColorSlot,
        size: CGFloat,
        cornerRadius: CGFloat
    ) -> some View {
        let isSelected = store.brushPalette.brush.selectedColorSlot == slot

        return Button {
            store.send(.brushPalette(.binding(.set(\.brush.selectedColorSlot, slot))))
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.96))

                if slot == .transparent {
                    dockCheckerboard(cornerRadius: max(4, cornerRadius - 2))
                        .padding(3)

                    Image(systemName: "slash.circle.fill")
                        .font(.system(size: max(8, size * 0.42), weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                } else {
                    RoundedRectangle(cornerRadius: max(4, cornerRadius - 2), style: .continuous)
                        .fill(slot == .primary ? store.brushPalette.brush.color : store.brushPalette.brush.secondaryColor)
                        .padding(3)
                }
            }
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isSelected ? StudioTheme.Palette.accentBright : Color.black.opacity(0.10), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(slot == .primary ? 0.14 : 0.08), radius: slot == .primary ? 10 : 6, y: 4)
        }
        .buttonStyle(.plain)
        .minimumHitTarget()
        .accessibilityLabel(slot.localizedTitle(language))
    }

    func toolDockActionButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.56))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.94))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .minimumHitTarget()
    }

    func dockCheckerboard(cornerRadius: CGFloat) -> some View {
        GeometryReader { geometry in
            let cellSize = max(5, min(geometry.size.width, geometry.size.height) / 4)
            let columns = max(2, Int(ceil(geometry.size.width / cellSize)))
            let rows = max(2, Int(ceil(geometry.size.height / cellSize)))

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 0.90, green: 0.92, blue: 0.96))

                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<columns, id: \.self) { column in
                                Rectangle()
                                    .fill((row + column).isMultiple(of: 2) ? Color.white.opacity(0.82) : Color.clear)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
    }
}
