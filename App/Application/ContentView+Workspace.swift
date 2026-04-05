import SwiftUI

extension ContentView {
    var centerStage: some View {
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

    var toolDockColumn: some View {
        VStack {
            toolDock
                .padding(.leading, 10)
                .padding(.top, 20)
            Spacer(minLength: 0)
        }
        .frame(width: 74)
    }

    func panelRail(for panel: StudioPanelKind) -> some View {
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

    func panelState(for panel: StudioPanelKind) -> StudioPanelLayoutState {
        switch panel {
        case .brush:
            return store.brushPanel
        case .layers:
            return store.layerPanel
        }
    }

    var stageChrome: some View {
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

    var toolDock: some View {
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
