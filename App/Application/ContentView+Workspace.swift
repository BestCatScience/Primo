import PrimoDocumentContracts
import PrimoDocumentDomain
import SwiftUI
import UIKit

extension ContentView {
    func dismissBrushSettingsPopover() {
        if store.brushPalette.ui.showsBrushSettingsPopover {
            store.send(.document(.brushPalette(.binding(.set(\.ui.showsBrushSettingsPopover, false)))))
        }
    }

    var centerStage: some View {
        ZStack {
            StudioTheme.Gradients.stage
                .overlay(alignment: .topLeading) {
                    RadialGradient(
                        colors: [
                            StudioTheme.Palette.accentGlow.opacity(0.42),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: 460
                    )
                }
                .overlay {
                    DiagonalStageLines()
                        .opacity(0.48)
                        .allowsHitTesting(false)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .stroke(Color.white.opacity(0.02), lineWidth: 1)
                }

            VStack(spacing: 10) {
                if workspaceState.workspaceLayout == .split {
                    HStack(spacing: 12) {
                        workspacePaneStage(.primary)
                        workspacePaneStage(.secondary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                } else {
                    workspacePaneStage(.primary)
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                }

                if !nanoBananaState.workspaceBottomPanelCollapsed {
                    workspaceBottomPanel
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                } else {
                    collapsedWorkspaceBottomBar
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                }
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissBrushSettingsPopover()
            }
        )
    }

    @ViewBuilder
    func workspacePaneStage(_ pane: WorkspacePane) -> some View {
        let selectedTab = workspaceSelectedTab(in: pane)
        let isActivePane = workspaceState.focusedWorkspacePane == pane
        let isLivePane = isActivePane && workspaceState.activeTabID == selectedTab?.id && !applicationState.showsHome

        ZStack {
            stageChrome

            if isLivePane {
                CanvasView(
                    store: store.scope(
                        state: \.document.canvas,
                        action: \.document.canvas
                    )
                )
                .padding(10)
            } else {
                workspacePanePreview(pane: pane, selectedTab: selectedTab)
                    .padding(10)
            }

            if applicationState.isHydrating && isActivePane {
                ProgressView()
                    .controlSize(.large)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .topLeading) {
            Text(pane == .primary ? language.localized("左ペイン") : language.localized("右ペイン"))
                .font(StudioTheme.Typography.mono(10))
                .foregroundStyle(.white.opacity(0.48))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isActivePane ? StudioTheme.Palette.selectedBorder : Color.white.opacity(0.05), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            store.send(.workspace(.workspacePaneActivated(pane)))
        }
        .dropDestination(for: String.self) { items, _ in
            guard
                let rawValue = items.first,
                let movingID = UUID(uuidString: rawValue)
            else {
                return false
            }
            store.send(.workspace(.tabDropped(moving: movingID, toPane: pane, before: nil)))
            return true
        }
    }

    @ViewBuilder
    func workspacePanePreview(pane: WorkspacePane, selectedTab: OpenDocumentTab?) -> some View {
        if let selectedTab, let previewSurface = liveWorkspacePreviewSurface(for: selectedTab) {
            VStack(spacing: 18) {
                Spacer(minLength: 0)

                SurfacePreviewView(surface: previewSurface)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                VStack(spacing: 6) {
                    Text(selectedTab.title)
                        .font(StudioTheme.Typography.title(15))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(language.localized("タップしてこのペインを編集"))
                        .font(StudioTheme.Typography.label(12))
                        .foregroundStyle(.white.opacity(0.52))
                }
                .padding(.bottom, 10)
            }
            .padding(22)
        } else if let selectedTab, let previewSurface = selectedTab.previewSurface ?? StoredSurfaceAdapter.surface(from: selectedTab.previewImageData) {
            VStack(spacing: 18) {
                Spacer(minLength: 0)

                SurfacePreviewView(surface: previewSurface)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                VStack(spacing: 6) {
                    Text(selectedTab.title)
                        .font(StudioTheme.Typography.title(15))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(language.localized("タップしてこのペインを編集"))
                        .font(StudioTheme.Typography.label(12))
                        .foregroundStyle(.white.opacity(0.52))
                }
                .padding(.bottom, 10)
            }
            .padding(22)
        } else {
            VStack(spacing: 14) {
                Image(systemName: pane == .secondary ? "square.split.2x1" : "doc")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text(language.localized(pane == .secondary ? "右ペインにタブをドロップ" : "タブを開いてください"))
                    .font(StudioTheme.Typography.title(14))
                    .foregroundStyle(.white.opacity(0.84))
                Text(language.localized("ここをタップするとこのペインへ切り替わります"))
                    .font(StudioTheme.Typography.label(12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func liveWorkspacePreviewSurface(for selectedTab: OpenDocumentTab) -> DocumentCompositeSurface? {
        guard
            selectedTab.id == workspaceState.activeTabID,
            let snapshot = store.canvas.renderSnapshot
        else {
            return nil
        }
        return DocumentFeatureRuntimeReducer.renderedCompositeSurface(
            snapshot: snapshot,
            paperStyle: store.canvas.paperStyle,
            gpuOperations: documentGpuOperationGateway
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
        .frame(width: 82)
        .padding(.top, 12)
        .background(StudioTheme.Gradients.chrome)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(StudioTheme.Palette.hairline)
                .frame(width: 1)
        }
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
                            store.send(.document(.editing(.panelCollapseToggled(panel))))
                        }
                    } else if translation < -dragThreshold {
                        store.send(.document(.editing(.panelCollapseToggled(panel))))
                    }
                case .layers:
                    if panelState.isCollapsed {
                        if translation < -dragThreshold {
                            store.send(.document(.editing(.panelCollapseToggled(panel))))
                        }
                    } else if translation > dragThreshold {
                        store.send(.document(.editing(.panelCollapseToggled(panel))))
                    }
                }
            }

        return VStack(spacing: 12) {
            studioPanel(for: panel)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .padding(.bottom, 8)
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
                        store.send(.document(.editing(.panelCollapseToggled(panel))))
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
            onToggleCollapse: { store.send(.document(.editing(.panelCollapseToggled(panel)))) }
        ) {
            switch panel {
            case .brush:
                BrushPaletteView(
                    store: store.scope(
                        state: \.document.brushPalette,
                        action: \.document.brushPalette
                    ),
                    currentTool: store.canvas.currentTool,
                    hasSelection: store.canvas.selection != nil,
                    transformPreviewOffset: store.canvas.transformPreviewOffset,
                    transformPreviewScaleX: store.canvas.transformPreviewScaleX,
                    transformPreviewScaleY: store.canvas.transformPreviewScaleY,
                    transformPreviewRotationDegrees: store.canvas.transformPreviewRotationDegrees,
                    transformMode: store.canvas.transformMode,
                    transformLocksAspectRatio: store.canvas.transformLocksAspectRatio,
                    language: language,
                    showsTitle: false,
                    onSelectTool: { tool in
                        store.send(.document(.editing(.toolSelected(tool))))
                    },
                    onRequestExpandSelection: {
                        selectionExpansionText = "4"
                        showsExpandSelectionSheet = true
                    },
                    onRequestContractSelection: {
                        selectionContractionText = "4"
                        showsContractSelectionSheet = true
                    },
                    onRequestTransformNumericInput: {
                        syncTransformNumericDraft()
                        showsTransformNumericSheet = true
                    },
                    onSetTransformMode: { mode in
                        store.send(.document(.canvas(.transformModeChanged(mode))))
                    },
                    onSetTransformAspectRatioLock: { isLocked in
                        store.send(.document(.canvas(.transformAspectRatioLockChanged(isLocked))))
                    }
                )
            case .layers:
                LayerSidebarView(
                    store: store.scope(
                        state: \.document.layerSidebar,
                        action: \.document.layerSidebar
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

    var workspaceBottomPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                workspaceBottomTab(title: "NANO BANANA", section: .nanoBanana)
                workspaceBottomTab(title: "HISTORY", section: .history)
                workspaceBottomTab(title: "OUTPUT", section: .output)
                Spacer(minLength: 0)
                workspaceTabChromeButton(symbol: "chevron.down") {
                    store.send(.nanoBanana(.workspaceBottomPanelCollapsedChanged(true)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.03))

            Group {
                switch nanoBananaState.workspaceBottomPanelSection {
                case .nanoBanana:
                    workspaceNanoBananaPanel
                case .history:
                    workspaceHistoryPanel
                case .output:
                    workspaceOutputPanel
                }
            }
            .padding(12)
        }
        .frame(height: 224)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(StudioTheme.Palette.overlayBlack.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
        )
    }

    var collapsedWorkspaceBottomBar: some View {
        HStack {
            Text(
                nanoBananaState.workspaceBottomPanelSection == .nanoBanana
                ? "NANO BANANA"
                : nanoBananaState.workspaceBottomPanelSection == .history ? "HISTORY" : "OUTPUT"
            )
                .font(StudioTheme.Typography.mono(10))
                .foregroundStyle(.white.opacity(0.55))
            Spacer(minLength: 0)
            workspaceTabChromeButton(symbol: "chevron.up") {
                store.send(.nanoBanana(.workspaceBottomPanelCollapsedChanged(false)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(StudioTheme.Palette.overlayBlack.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
        )
    }

    func workspaceBottomTab(title: String, section: NanoBananaFeature.WorkspaceBottomPanelSection) -> some View {
        Button {
            store.send(.nanoBanana(.workspaceBottomPanelSectionChanged(section)))
        } label: {
            Text(title)
                .font(StudioTheme.Typography.mono(10))
                .foregroundStyle(nanoBananaState.workspaceBottomPanelSection == section ? .white.opacity(0.9) : .white.opacity(0.45))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(nanoBananaState.workspaceBottomPanelSection == section ? Color.white.opacity(0.10) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    var workspaceNanoBananaPanel: some View {
        GeometryReader { geometry in
            let usesCompactStack = geometry.size.width < 980
            let promptWidth = usesCompactStack ? geometry.size.width : max(geometry.size.width * 0.56, 360)

            Group {
                if usesCompactStack {
                    VStack(alignment: .leading, spacing: 12) {
                        workspaceNanoBananaPromptEditor
                        workspaceNanoBananaMetaColumn
                        workspaceNanoBananaActions
                    }
                } else {
                    HStack(alignment: .top, spacing: 14) {
                        workspaceNanoBananaPromptEditor
                            .frame(width: promptWidth, alignment: .leading)
                        VStack(alignment: .leading, spacing: 12) {
                            workspaceNanoBananaMetaColumn
                            workspaceNanoBananaActions
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func workspaceNanoBananaStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(StudioTheme.Typography.mono(10))
                .foregroundStyle(.white.opacity(0.42))
            Text(value)
                .font(StudioTheme.Typography.label(12))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
        }
    }

    var workspaceNanoBananaPromptEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.localized("プロンプト"))
                .font(StudioTheme.Typography.label(12))
                .foregroundStyle(.white.opacity(0.55))

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)

                if nanoBananaState.composer.prompt.isEmpty {
                    Text(language.localized("Nano Banana にどう編集させたいか入力してください"))
                        .font(StudioTheme.Typography.body(13))
                        .foregroundStyle(Color.black.opacity(0.38))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }

                StudioPlainTextView(
                    text: nanoBananaPromptBinding,
                    textColor: .black,
                    tintColor: .black,
                    font: .systemFont(ofSize: 13, weight: .medium),
                    backgroundColor: .clear
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, minHeight: 82, maxHeight: 110, alignment: .topLeading)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.14), lineWidth: 1)
            )
        }
    }

    var workspaceNanoBananaMetaColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 110), spacing: 10),
                    GridItem(.flexible(minimum: 110), spacing: 10)
                ],
                alignment: .leading,
                spacing: 10
            ) {
                workspaceNanoBananaStatCard(label: language.localized("入力"), value: resolvedNanoBananaInputLayerName)
                workspaceNanoBananaStatCard(label: language.localized("対象"), value: nanoBananaState.composer.editScope.title(language))
                workspaceNanoBananaStatCard(label: language.localized("出力"), value: nanoBananaState.composer.outputMode.title(language))
                workspaceNanoBananaStatCard(label: language.localized("モデル"), value: nanoBananaState.composer.model.title(language))
            }

            if nanoBananaState.accessMode == .appManaged && !nanoBananaState.commerce.isSubscriptionActive {
                VStack(alignment: .leading, spacing: 8) {
                    Text(language.localized("サブスクリプションが必要です"))
                        .font(StudioTheme.Typography.label(12))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(language.localized("Primo のサブスクリプションで、自分の API キーなしに Nano Banana を利用できます"))
                        .font(StudioTheme.Typography.body(11))
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)

                    Button(language.localized("Nano Banana を有効化")) {
                        store.send(.nanoBanana(.paywallPresentationChanged(true)))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.94))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }

    func workspaceNanoBananaStatCard(label: String, value: String) -> some View {
        workspaceNanoBananaStat(label: label, value: value)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    var workspaceNanoBananaActions: some View {
        HStack(spacing: 8) {
            Button(language.localized("実行")) {
                requestNanoBananaGeneration(closeSheet: false)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.94))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        (nanoBananaState.isGenerating || store.layerSidebar.layers.isEmpty)
                        ? StudioTheme.Palette.accentBright.opacity(0.34)
                        : StudioTheme.Palette.accentBright.opacity(0.8)
                    )
            )
            .disabled(nanoBananaState.isGenerating || store.layerSidebar.layers.isEmpty)

            Button(language.localized("フルパネルを開く")) {
                store.send(.nanoBanana(.sheetPresentationChanged(true)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.72))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            Spacer(minLength: 0)
        }
    }

    var workspaceHistoryPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(nanoBananaState.history.prefix(8)) { item in
                    Button {
                        store.send(.nanoBanana(.historyItemSelected(item.descriptor)))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.descriptor.prompt.rawValue)
                                .font(StudioTheme.Typography.body(13))
                                .foregroundStyle(.white.opacity(0.88))
                                .lineLimit(2)
                            Text(item.descriptor.model.title(language))
                                .font(StudioTheme.Typography.mono(10))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    var workspaceOutputPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(nanoBananaState.jobs.prefix(8)) { job in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(job.status == .succeeded ? Color.green.opacity(0.8) : job.status == .failed ? Color.red.opacity(0.8) : StudioTheme.Palette.accentBright)
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(job.descriptor.model.title(language))
                                    .font(StudioTheme.Typography.label(12))
                                    .foregroundStyle(.white.opacity(0.9))
                                Spacer(minLength: 0)
                                Text(job.status.rawValue.capitalized)
                                    .font(StudioTheme.Typography.mono(10))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            Text(job.descriptor.prompt.rawValue)
                                .font(StudioTheme.Typography.body(12))
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(2)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                }
            }
        }
    }

    var stageChrome: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.13, green: 0.14, blue: 0.16),
                        Color(red: 0.08, green: 0.09, blue: 0.11)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.03), lineWidth: 1)
                    .padding(1)
            )
            .shadow(color: .black.opacity(0.36), radius: 28, y: 18)
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
        .frame(width: 58)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(StudioTheme.Gradients.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
                .allowsHitTesting(false)
        )
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissBrushSettingsPopover()
            }
        )
    }

    func toolDockItem(tool: StudioToolKind, isActive: Bool) -> some View {
        Image(systemName: tool.systemImage)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(isActive ? StudioTheme.Palette.textPrimary : StudioTheme.Palette.textSecondary)
            .frame(width: 38, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? StudioTheme.Palette.selectedFill : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isActive ? StudioTheme.Palette.selectedBorder : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .onTapGesture {
                store.send(.document(.editing(.toolSelected(tool))))
            }
            .onLongPressGesture(minimumDuration: 0.45) {
                if tool == .brush || tool == .erase {
                    store.send(.document(.editing(.toolLongPressed(tool))))
                }
            }
    }

    var toolDockMetrics: some View {
        VStack(spacing: 8) {
            toolMetricBubble(
                text: "\(Int(store.brushPalette.brush.storedRadius(for: store.canvas.currentTool).rounded()))",
                title: language.localized("ブラシサイズ"),
                metric: .size
            )

            toolMetricBubble(
                text: "\(Int((store.brushPalette.brush.opacity * 100).rounded()))",
                title: language.localized("不透明度"),
                metric: .opacity
            )
        }
        .frame(width: 62)
    }

    func toolMetricBubble(
        text: String,
        title: String,
        metric: ContentView.ToolMetricEditor
    ) -> some View {
        ZStack {
            Circle()
                .fill(StudioTheme.Gradients.surface)

            Circle()
                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)

            if selectedToolMetricEditor == metric {
                TextField(
                    "",
                    text: metric == .size ? $toolMetricSizeText : $toolMetricOpacityText
                )
                .font(StudioTheme.Typography.mono(12))
                .foregroundStyle(StudioTheme.Palette.textPrimary)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .keyboardType(.numberPad)
                .frame(width: 34)
                .onSubmit {
                    commitToolMetricInput(for: metric)
                }
                .onChange(of: metric == .size ? toolMetricSizeText : toolMetricOpacityText) { _, newValue in
                    let filtered = newValue.filter(\.isNumber)
                    if metric == .size {
                        if filtered != newValue {
                            toolMetricSizeText = filtered
                        }
                    } else if filtered != newValue {
                        toolMetricOpacityText = filtered
                    }
                }
            } else {
                Text(text)
                    .font(StudioTheme.Typography.title(18))
                    .foregroundStyle(StudioTheme.Palette.textPrimary)
            }
        }
        .frame(width: 46, height: 46)
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        .contentShape(Circle())
        .onTapGesture {
            if selectedToolMetricEditor == metric {
                commitToolMetricInput(for: metric)
            } else {
                selectedToolMetricEditor = metric
                switch metric {
                case .size:
                    toolMetricSizeText = "\(Int(store.brushPalette.brush.radius.rounded()))"
                case .opacity:
                    toolMetricOpacityText = "\(Int((store.brushPalette.brush.opacity * 100).rounded()))"
                }
            }
        }
        .accessibilityLabel(title)
    }

    func commitToolMetricSizeInput() {
        guard let value = Double(toolMetricSizeText) else {
            toolMetricSizeText = "\(Int(store.brushPalette.brush.radius.rounded()))"
            return
        }
        let clamped = min(max(value, 1), BrushPaletteFeature.maximumBrushRadius)
        store.send(.document(.brushPalette(.binding(.set(\.brush.radius, clamped)))))
        toolMetricSizeText = "\(Int(clamped.rounded()))"
        selectedToolMetricEditor = nil
    }

    func commitToolMetricOpacityInput() {
        guard let value = Double(toolMetricOpacityText) else {
            toolMetricOpacityText = "\(Int((store.brushPalette.brush.opacity * 100).rounded()))"
            return
        }
        let clampedPercent = min(max(value, 10), 100)
        store.send(.document(.brushPalette(.binding(.set(\.brush.opacity, clampedPercent / 100.0)))))
        toolMetricOpacityText = "\(Int(clampedPercent.rounded()))"
        selectedToolMetricEditor = nil
    }

    func commitToolMetricInput(for metric: ContentView.ToolMetricEditor) {
        switch metric {
        case .size:
            commitToolMetricSizeInput()
        case .opacity:
            commitToolMetricOpacityInput()
        }
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
                    store.send(.document(.brushPalette(.binding(.set(\.brush.color, secondary)))))
                    store.send(.document(.brushPalette(.binding(.set(\.brush.secondaryColor, primary)))))
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
            store.send(.document(.brushPalette(.binding(.set(\.brush.selectedColorSlot, slot)))))
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(StudioTheme.Gradients.surface)

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
                    .stroke(isSelected ? StudioTheme.Palette.accentBright : StudioTheme.Palette.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(slot == .primary ? 0.24 : 0.16), radius: slot == .primary ? 12 : 8, y: 6)
        }
        .buttonStyle(.plain)
        .minimumHitTarget()
        .accessibilityLabel(slot.localizedTitle(language))
    }

    func toolDockActionButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(StudioTheme.Palette.textSecondary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(StudioTheme.Gradients.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
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
                    .fill(Color(red: 0.28, green: 0.30, blue: 0.34))

                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<columns, id: \.self) { column in
                                Rectangle()
                                    .fill((row + column).isMultiple(of: 2) ? Color.white.opacity(0.22) : Color.clear)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
    }
}
