import PrimoDocumentContracts
import PrimoDocumentDomain
import SwiftUI
import UIKit

extension ContentView {
    private var workspaceBottomGestureClearance: CGFloat { 36 }
    private var workspaceAIImagePickerMaximumHeight: CGFloat { 144 }
    private var studioPanelAnimation: Animation {
        .spring(response: 0.28, dampingFraction: 0.88)
    }
    private var responsiveDragMinimumDistance: CGFloat { 2 }
    private var responsivePanelCloseThreshold: CGFloat { 28 }
    private var responsiveBottomPanelCloseThreshold: CGFloat { 24 }
    private var workspaceStageLeadingPadding: CGFloat {
        store.document.editing.brushPanel.isCollapsed ? 6 : 18
    }
    private var workspaceStageTrailingPadding: CGFloat {
        store.document.editing.layerPanel.isCollapsed ? 6 : 18
    }
    private var workspaceStageHorizontalInsets: EdgeInsets {
        EdgeInsets(top: 0, leading: workspaceStageLeadingPadding, bottom: 0, trailing: workspaceStageTrailingPadding)
    }

    func dismissBrushSettingsPopover() {
        if store.document.editing.brushPalette.ui.showsBrushSettingsPopover {
            _ = withAnimation(studioPanelAnimation) {
                store.send(.document(.brushPalette(.binding(.set(\.ui.showsBrushSettingsPopover, false)))))
            }
        }
    }

    func toggleStudioPanel(_ panel: StudioPanelKind) {
        _ = withAnimation(studioPanelAnimation) {
            store.send(.document(.canvasEditing(.editing(.panelCollapseToggled(panel)))))
        }
    }

    func setWorkspaceBottomPanelCollapsed(_ isCollapsed: Bool) {
        _ = withAnimation(studioPanelAnimation) {
            store.send(.aiImage(.workspaceBottomPanelCollapsedChanged(isCollapsed)))
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
                if workspaceState.workspaceLayout == .splitRight {
                    HStack(spacing: 12) {
                        workspacePaneStage(.primary)
                        workspacePaneStage(.secondary)
                    }
                    .padding(workspaceStageHorizontalInsets)
                    .padding(.top, 8)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else if workspaceState.workspaceLayout == .splitBelow {
                    VStack(spacing: 12) {
                        workspacePaneStage(.primary)
                        workspacePaneStage(.secondary)
                    }
                    .padding(workspaceStageHorizontalInsets)
                    .padding(.top, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    workspacePaneStage(.primary)
                        .padding(workspaceStageHorizontalInsets)
                        .padding(.top, 8)
                        .transition(.opacity)
                }

                if !aiImageState.workspaceBottomPanelCollapsed {
                    workspaceBottomPanel
                        .padding(workspaceStageHorizontalInsets)
                        .padding(.bottom, workspaceBottomGestureClearance)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.88), value: workspaceState.workspaceLayout)
        }
        .overlay(alignment: .bottomTrailing) {
            if aiImageState.workspaceBottomPanelCollapsed {
                bottomWorkspacePanelToggle
                    .padding(.trailing, workspaceStageTrailingPadding + 10)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(studioPanelAnimation, value: aiImageState.workspaceBottomPanelCollapsed)
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissBrushSettingsPopover()
            }
        )
    }

    var bottomWorkspacePanelToggle: some View {
        Button {
            setWorkspaceBottomPanelCollapsed(false)
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "tag")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 22, height: 22)

                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 12, height: 12)
                    .background(
                        Circle()
                            .fill(StudioTheme.Palette.accentBright)
                    )
                    .offset(x: 5, y: -5)
            }
            .foregroundStyle(StudioTheme.Palette.accentBright)
            .frame(width: 30, height: 26)
        }
        .buttonStyle(WorkspaceFlatButtonStyle())
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .minimumHitTarget(52)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(StudioTheme.Palette.accentBright.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(StudioTheme.Palette.accentBright.opacity(0.64), lineWidth: 1.5)
        }
        .shadow(color: StudioTheme.Palette.accentBright.opacity(0.20), radius: 8, x: 0, y: 0)
        .contentShape(Rectangle())
        .hoverEffect(.lift)
        .accessibilityLabel(language.localized("AI Image パネルを表示"))
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
                        state: \.document.editing.canvas,
                        action: \.document.canvas
                    ),
                    allowsFingerTouchInput: store.document.editing.brushPalette.allowsFingerTouchInput
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
            let snapshot = store.document.editing.canvas.renderSnapshot
        else {
            return nil
        }
        return DocumentFeature.renderedCompositeSurfaceIfAvailable(
            snapshot: snapshot,
            paperStyle: store.document.editing.canvas.paperStyle,
            gpuOperations: documentRenderingWorkflow
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
        .frame(width: 70)
        .padding(.top, 8)
        .background(StudioTheme.Gradients.chrome)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(StudioTheme.Palette.hairline)
                .frame(width: 1)
        }
    }

    @ViewBuilder
    func panelRail(for panel: StudioPanelKind) -> some View {
        let panelState = panelState(for: panel)

        if panelState.isCollapsed {
            Color.clear
                .frame(width: 0)
        } else {
            let panelDragGesture = DragGesture(minimumDistance: responsiveDragMinimumDistance)
                .onEnded { value in
                    let translation = value.translation.width
                    let predictedTranslation = value.predictedEndTranslation.width
                    let horizontalTravel = max(abs(translation), abs(predictedTranslation))
                    let isMostlyHorizontal = horizontalTravel > abs(value.translation.height) * 1.25

                    switch panel {
                    case .brush:
                        if isMostlyHorizontal,
                           min(translation, predictedTranslation) < -responsivePanelCloseThreshold {
                            toggleStudioPanel(panel)
                        }
                    case .layers:
                        if isMostlyHorizontal,
                           max(translation, predictedTranslation) > responsivePanelCloseThreshold {
                            toggleStudioPanel(panel)
                        }
                    }
                }

            VStack(spacing: 12) {
                studioPanel(for: panel)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(width: panel == .layers ? 324 : 332)
            .frame(maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .simultaneousGesture(panelDragGesture)
            .simultaneousGesture(
                TapGesture().onEnded {
                    if panel != .brush {
                        dismissBrushSettingsPopover()
                    }
                }
            )
            .transition(.move(edge: panel == .brush ? .leading : .trailing).combined(with: .opacity))
        }
    }

    @ViewBuilder
    func studioPanel(for panel: StudioPanelKind) -> some View {
        StudioPanelShell(
            title: panel.title(language),
            isCollapsed: false
        ) {
            switch panel {
            case .brush:
                BrushPaletteView(
                    store: store.scope(
                        state: \.document.editing.brushPalette,
                        action: \.document.brushPalette
                    ),
                    currentTool: store.document.editing.canvas.currentTool,
                    hasSelection: store.document.editing.canvas.selection != nil,
                    transformPreviewOffset: store.document.editing.canvas.transformPreviewOffset,
                    transformPreviewScaleX: store.document.editing.canvas.transformPreviewScaleX,
                    transformPreviewScaleY: store.document.editing.canvas.transformPreviewScaleY,
                    transformPreviewRotationDegrees: store.document.editing.canvas.transformPreviewRotationDegrees,
                    transformMode: store.document.editing.canvas.transformMode,
                    transformLocksAspectRatio: store.document.editing.canvas.transformLocksAspectRatio,
                    language: language,
                    showsTitle: false,
                    onSelectTool: { tool in
                        store.send(.document(.canvasEditing(.editing(.toolSelected(tool)))))
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
                        state: \.document.editing.layerSidebar,
                        action: \.document.layerSidebar
                    ),
                    layerSnapshots: store.document.editing.canvas.renderSnapshot?.layers ?? [],
                    language: language,
                    showsTitle: false
                )
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(studioPanelAnimation, value: store.document.editing.brushPanel.isCollapsed)
        .animation(studioPanelAnimation, value: store.document.editing.layerPanel.isCollapsed)
    }

    func panelState(for panel: StudioPanelKind) -> StudioPanelLayoutState {
        switch panel {
        case .brush:
            return store.document.editing.brushPanel
        case .layers:
            return store.document.editing.layerPanel
        }
    }

    var workspaceBottomPanel: some View {
        let panelDragGesture = DragGesture(minimumDistance: responsiveDragMinimumDistance)
            .onEnded { value in
                let verticalTravel = max(value.translation.height, value.predictedEndTranslation.height)
                let isMostlyVertical = abs(verticalTravel) > abs(value.translation.width) * 1.25

                if isMostlyVertical, verticalTravel > responsiveBottomPanelCloseThreshold {
                    setWorkspaceBottomPanelCollapsed(true)
                }
            }

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                workspaceBottomTab(title: "AI IMAGE", section: .aiImage)
                workspaceBottomTab(title: "HISTORY", section: .history)
                workspaceBottomTab(title: "OUTPUT", section: .output)
                Spacer(minLength: 0)
                workspaceBottomPanelCloseButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.03))

            Group {
                switch aiImageState.workspaceBottomPanelSection {
                case .aiImage:
                    workspaceAIImagePanel
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
        .studioWindowGlow(cornerRadius: 16, intensity: 0.58)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .simultaneousGesture(panelDragGesture)
    }

    var workspaceBottomPanelCloseButton: some View {
        Button {
            setWorkspaceBottomPanelCollapsed(true)
        } label: {
            Image(systemName: "dock.arrow.down.rectangle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(StudioTheme.Palette.accentBright)
                .frame(width: 28, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(StudioTheme.Palette.accentBright.opacity(0.10))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(StudioTheme.Palette.accentBright.opacity(0.88), lineWidth: 1.5)
                }
        }
        .buttonStyle(WorkspaceFlatButtonStyle())
        .minimumHitTarget(52)
        .contentShape(Rectangle())
        .hoverEffect(.lift)
        .accessibilityLabel(language.localized("AI Image パネルを閉じる"))
    }

    func workspaceBottomTab(title: String, section: AIImageFeature.WorkspaceBottomPanelSection) -> some View {
        let isSelected = aiImageState.workspaceBottomPanelSection == section
        return Button {
            store.send(.aiImage(.workspaceBottomPanelSectionChanged(section)))
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .white.opacity(0.46))
                Rectangle()
                    .fill(isSelected ? Color.white.opacity(0.82) : Color.clear)
                    .frame(height: 1)
            }
            .fixedSize()
            .padding(.horizontal, 4)
            .padding(.top, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(WorkspaceFlatButtonStyle())
    }

    var workspaceAIImagePanel: some View {
        GeometryReader { geometry in
            let usesCompactStack = geometry.size.width < 980
            let promptWidth = usesCompactStack ? geometry.size.width : max(geometry.size.width * 0.62, 420)

            Group {
                if usesCompactStack {
                    VStack(alignment: .leading, spacing: 12) {
                        workspaceAIImagePromptEditor
                        HStack(alignment: .top, spacing: 10) {
                            workspaceAIImageMetaColumn
                            workspaceAIImageActions
                                .frame(width: 128, alignment: .topTrailing)
                        }
                    }
                } else {
                    HStack(alignment: .top, spacing: 14) {
                        workspaceAIImagePromptEditor
                            .frame(width: promptWidth, alignment: .leading)
                        VStack(alignment: .leading, spacing: 12) {
                            workspaceAIImageMetaColumn
                            workspaceAIImageActions
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func workspaceAIImageStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(StudioTheme.Typography.mono(9))
                .foregroundStyle(.white.opacity(0.38))
            Text(value)
                .font(StudioTheme.Typography.label(11))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
        }
    }

    var workspaceAIImagePromptEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.localized("プロンプト"))
                .font(StudioTheme.Typography.label(12))
                .foregroundStyle(.white.opacity(0.55))

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)

                if aiImageState.composer.prompt.isEmpty {
                    Text(language.localized("AI画像にどう編集させたいか入力してください"))
                        .font(StudioTheme.Typography.body(13))
                        .foregroundStyle(Color.black.opacity(0.38))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }

                StudioPlainTextView(
                    text: aiImagePromptBinding,
                    textColor: .black,
                    tintColor: .black,
                    font: .systemFont(ofSize: 13, weight: .medium),
                    backgroundColor: .clear
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, minHeight: 74, maxHeight: 96, alignment: .topLeading)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black.opacity(0.14), lineWidth: 1)
            )
        }
    }

    var workspaceAIImageMetaColumn: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(minimum: 110), spacing: 8),
                        GridItem(.flexible(minimum: 110), spacing: 8)
                    ],
                    alignment: .leading,
                    spacing: 8
                ) {
                    workspaceAIImageInputLayerMenu
                    workspaceAIImageEditScopeMenu
                    workspaceAIImageOutputModeMenu
                    workspaceAIImageModelMenu
                }
            }

            if let activeAIImageWorkspacePicker {
                workspaceAIImagePickerPopup(activeAIImageWorkspacePicker)
                    .padding(.top, 68)
                    .zIndex(20)
            }
        }
    }

    @ViewBuilder
    func workspaceAIImagePickerPopup(_ picker: AIImageWorkspacePicker) -> some View {
        let rowCount = workspaceAIImagePickerRowCount(for: picker)
        let popupHeight = min(CGFloat(rowCount) * 33 + 12, workspaceAIImagePickerMaximumHeight)
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                switch picker {
                case .inputLayer:
                    ForEach(store.document.editing.layerSidebar.layers) { layer in
                        workspaceAIImagePickerPopupRow(
                            title: layer.name,
                            isSelected: layer.index == resolvedAIImageInputLayerIndex
                        ) {
                            store.send(.aiImage(.inputLayerIndexChanged(layer.index)))
                        }
                    }
                case .editScope:
                    let hasSelection = store.document.editing.canvas.selection?.isEmpty == false
                    ForEach(AIImageEditScope.allCases) { scope in
                        workspaceAIImagePickerPopupRow(
                            title: scope.title(language),
                            isSelected: scope == aiImageState.composer.editScope,
                            isDisabled: scope == .selectedArea && !hasSelection
                        ) {
                            store.send(.aiImage(.editScopeChanged(scope)))
                        }
                    }
                case .outputMode:
                    ForEach(AIImageOutputMode.allCases) { mode in
                        workspaceAIImagePickerPopupRow(
                            title: mode.title(language),
                            isSelected: mode == aiImageState.composer.outputMode
                        ) {
                            store.send(.aiImage(.outputModeChanged(mode)))
                        }
                    }
                case .model:
                    ForEach(AIImageModel.allCases) { model in
                        workspaceAIImagePickerPopupRow(
                            title: model.title(language),
                            isSelected: model == aiImageState.composer.model
                        ) {
                            store.send(.aiImage(.modelChanged(model)))
                        }
                    }
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollDisabled(rowCount <= 4)
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, minHeight: popupHeight, maxHeight: popupHeight, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.16, blue: 0.19).opacity(0.98),
                            Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.98)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            StudioTheme.Palette.accentBright.opacity(0.34),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 1)
        }
        .shadow(color: .black.opacity(0.34), radius: 18, y: 10)
    }

    func workspaceAIImagePickerRowCount(for picker: AIImageWorkspacePicker) -> Int {
        switch picker {
        case .inputLayer:
            return max(store.document.editing.layerSidebar.layers.count, 1)
        case .editScope:
            return AIImageEditScope.allCases.count
        case .outputMode:
            return AIImageOutputMode.allCases.count
        case .model:
            return AIImageModel.allCases.count
        }
    }

    func workspaceAIImagePickerPopupRow(
        title: String,
        isSelected: Bool,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            activeAIImageWorkspacePicker = nil
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isSelected ? StudioTheme.Palette.accentBright.opacity(0.92) : Color.white.opacity(0.12))
                    .frame(width: 3, height: 18)
                Text(title)
                    .font(StudioTheme.Typography.label(12))
                    .foregroundStyle(.white.opacity(isDisabled ? 0.28 : (isSelected ? 0.96 : 0.82)))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(StudioTheme.Palette.accentBright.opacity(0.9))
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? StudioTheme.Palette.accentBright.opacity(0.10) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(WorkspaceFlatButtonStyle())
        .disabled(isDisabled)
    }

    @ViewBuilder
    var workspaceAIImageAccessNotice: some View {
        if aiImageState.requiresSubscriptionForCurrentAccessMode {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 1)
                Text(aiImageGeminiPlanSoftHint)
                    .font(StudioTheme.Typography.body(11))
                    .foregroundStyle(.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                workspaceNoticeLink(title: language.localized("プランを見る"), isSecondary: true) {
                    store.send(.aiImage(.paywallPresentationChanged(true)))
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    func workspaceNoticeLink(
        title: String,
        isSecondary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(
                        isSecondary
                        ? .white.opacity(0.58)
                        : StudioTheme.Palette.accentBright.opacity(0.92)
                    )
                Rectangle()
                    .fill(
                        isSecondary
                        ? Color.white.opacity(0.22)
                        : StudioTheme.Palette.accentBright.opacity(0.75)
                    )
                    .frame(height: 1)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(WorkspaceFlatButtonStyle())
    }

    func workspaceAIImageStatCard(label: String, value: String) -> some View {
        workspaceAIImageStat(label: label, value: value)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    func workspaceAIImageMenuCard(
        label: String,
        value: String,
        picker: AIImageWorkspacePicker
    ) -> some View {
        let isActive = activeAIImageWorkspacePicker == picker
        return Button {
            activeAIImageWorkspacePicker = isActive ? nil : picker
        } label: {
            HStack(alignment: .center, spacing: 8) {
                workspaceAIImageStat(label: label, value: value)
                Spacer(minLength: 0)
                Image(systemName: isActive ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isActive ? StudioTheme.Palette.accentBright.opacity(0.92) : .white.opacity(0.42))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isActive ? 0.085 : 0.052),
                                Color.white.opacity(isActive ? 0.035 : 0.025)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        isActive
                        ? StudioTheme.Palette.accentBright.opacity(0.42)
                        : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(isActive ? 0.10 : 0.045), lineWidth: 1)
                    .padding(1)
            }
        }
        .buttonStyle(WorkspaceFlatButtonStyle())
    }

    var workspaceAIImageInputLayerMenu: some View {
        workspaceAIImageMenuCard(
            label: language.localized("入力"),
            value: resolvedAIImageInputLayerName,
            picker: .inputLayer
        )
    }

    var workspaceAIImageEditScopeMenu: some View {
        workspaceAIImageMenuCard(
            label: language.localized("対象"),
            value: aiImageState.composer.editScope.title(language),
            picker: .editScope
        )
    }

    var workspaceAIImageOutputModeMenu: some View {
        workspaceAIImageMenuCard(
            label: language.localized("出力"),
            value: aiImageState.composer.outputMode.title(language),
            picker: .outputMode
        )
    }

    var workspaceAIImageModelMenu: some View {
        workspaceAIImageMenuCard(
            label: language.localized("モデル"),
            value: aiImageState.composer.model.title(language),
            picker: .model
        )
    }

    var workspaceAIImageActions: some View {
        let requiresSubscription = aiImageState.requiresSubscriptionForCurrentAccessMode
        let isDimmed = aiImageState.isGenerating || store.document.editing.layerSidebar.layers.isEmpty || aiImageState.commerce.isLoading
        return HStack(spacing: 8) {
            Button {
                handleAIImagePrimaryAction(closeSheet: false)
            } label: {
                Label(
                    aiImagePrimaryActionTitle(fallback: language.localized("実行")),
                    systemImage: requiresSubscription ? "lock.fill" : "sparkles"
                )
                    .font(StudioTheme.Typography.label(12))
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            }
            .buttonStyle(WorkspaceFlatButtonStyle())
            .foregroundStyle(.white.opacity(0.94))
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                (isDimmed
                                 ? StudioTheme.Palette.accentBright.opacity(0.30)
                                 : StudioTheme.Palette.accentBright.opacity(requiresSubscription ? 0.72 : 0.86)),
                                (isDimmed
                                 ? StudioTheme.Palette.accentBright.opacity(0.20)
                                 : StudioTheme.Palette.accentBright.opacity(requiresSubscription ? 0.48 : 0.62))
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .disabled(aiImagePrimaryActionDisabled)

            Button {
                store.send(.aiImage(.sheetPresentationChanged(true)))
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.74))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(WorkspaceFlatButtonStyle())
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .accessibilityLabel(language.localized("フルパネルを開く"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var workspaceHistoryPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(aiImageState.history.prefix(8)) { item in
                    Button {
                        store.send(.aiImage(.historyItemSelected(item.descriptor)))
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
                ForEach(aiImageState.jobs.prefix(8)) { job in
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
        VStack(spacing: 6) {
            ForEach(studioTools) { tool in
                let isActive = store.document.editing.canvas.currentTool == tool

                toolDockItem(tool: tool, isActive: isActive)
                .minimumHitTarget()
                .accessibilityLabel(tool.localizedTitle(language))
            }

            Spacer()
        }
        .padding(6)
        .frame(width: 50)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(StudioTheme.Palette.panelInset.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
                .allowsHitTesting(false)
        )
        .shadow(color: .black.opacity(0.16), radius: 10, y: 6)
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissBrushSettingsPopover()
            }
        )
    }

    func toolDockItem(tool: StudioToolKind, isActive: Bool) -> some View {
        Image(systemName: tool.systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isActive ? StudioTheme.Palette.textPrimary : StudioTheme.Palette.iconInactive)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isActive ? StudioTheme.Palette.selectedFill : StudioTheme.Palette.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isActive ? StudioTheme.Palette.selectedBorder : StudioTheme.Palette.hairline, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .onTapGesture {
                store.send(.document(.canvasEditing(.editing(.toolSelected(tool)))))
            }
            .onLongPressGesture(minimumDuration: 0.45) {
                if tool == .brush || tool == .erase {
                    store.send(.document(.canvasEditing(.editing(.toolLongPressed(tool)))))
                }
            }
    }

    var toolDockMetrics: some View {
        VStack(spacing: 8) {
            toolMetricBubble(
                text: "\(Int(store.document.editing.brushPalette.brush.storedRadius(for: store.document.editing.canvas.currentTool).rounded()))",
                title: language.localized("ブラシサイズ"),
                metric: .size
            )

            toolMetricBubble(
                text: "\(Int((store.document.editing.brushPalette.brush.opacity * 100).rounded()))",
                title: language.localized("不透明度"),
                metric: .opacity
            )
        }
        .frame(width: 54)
    }

    func toolMetricBubble(
        text: String,
        title: String,
        metric: ContentView.ToolMetricEditor
    ) -> some View {
        ZStack {
            Circle()
                .fill(StudioTheme.Palette.panelInset)

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
        .frame(width: 42, height: 42)
        .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
        .contentShape(Circle())
        .onTapGesture {
            if selectedToolMetricEditor == metric {
                commitToolMetricInput(for: metric)
            } else {
                selectedToolMetricEditor = metric
                switch metric {
                case .size:
                    toolMetricSizeText = "\(Int(store.document.editing.brushPalette.brush.radius.rounded()))"
                case .opacity:
                    toolMetricOpacityText = "\(Int((store.document.editing.brushPalette.brush.opacity * 100).rounded()))"
                }
            }
        }
        .accessibilityLabel(title)
    }

    func commitToolMetricSizeInput() {
        guard let value = Double(toolMetricSizeText) else {
            toolMetricSizeText = "\(Int(store.document.editing.brushPalette.brush.radius.rounded()))"
            return
        }
        let clamped = min(max(value, 1), BrushPaletteFeature.maximumBrushRadius)
        store.send(.document(.brushPalette(.binding(.set(\.brush.radius, clamped)))))
        toolMetricSizeText = "\(Int(clamped.rounded()))"
        selectedToolMetricEditor = nil
    }

    func commitToolMetricOpacityInput() {
        guard let value = Double(toolMetricOpacityText) else {
            toolMetricOpacityText = "\(Int((store.document.editing.brushPalette.brush.opacity * 100).rounded()))"
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
                    let primary = store.document.editing.brushPalette.brush.color
                    let secondary = store.document.editing.brushPalette.brush.secondaryColor
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
        let isSelected = store.document.editing.brushPalette.brush.selectedColorSlot == slot

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
                        .fill(slot == .primary ? store.document.editing.brushPalette.brush.color : store.document.editing.brushPalette.brush.secondaryColor)
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

private struct WorkspaceFlatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.linear(duration: 0.06), value: configuration.isPressed)
    }
}
