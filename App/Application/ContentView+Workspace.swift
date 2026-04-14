import SwiftUI
import UIKit

extension ContentView {
    func dismissBrushSettingsPopover() {
        if store.brushPalette.ui.showsBrushSettingsPopover {
            store.send(.brushPalette(.binding(.set(\.ui.showsBrushSettingsPopover, false))))
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
                if store.workspaceLayout == .split {
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

                if !workspaceBottomPanelCollapsed {
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
        let isActivePane = store.focusedWorkspacePane == pane
        let isLivePane = isActivePane && store.activeTabID == selectedTab?.id && !store.showsHome

        ZStack {
            stageChrome

            if isLivePane {
                CanvasView(
                    store: store.scope(
                        state: \.canvas,
                        action: \.canvas
                    )
                )
                .padding(10)
            } else {
                workspacePanePreview(pane: pane, selectedTab: selectedTab)
                    .padding(10)
            }

            if store.isHydrating && isActivePane {
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
            store.send(.workspacePaneActivated(pane))
        }
        .dropDestination(for: String.self) { items, _ in
            guard
                let rawValue = items.first,
                let movingID = UUID(uuidString: rawValue)
            else {
                return false
            }
            store.send(.tabDropped(moving: movingID, toPane: pane, before: nil))
            return true
        }
    }

    @ViewBuilder
    func workspacePanePreview(pane: WorkspacePane, selectedTab: OpenDocumentTab?) -> some View {
        if let selectedTab, let previewImageData = selectedTab.previewImageData, let image = UIImage(data: previewImageData) {
            VStack(spacing: 18) {
                Spacer(minLength: 0)

                Image(uiImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFit()
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

    var toolDockColumn: some View {
        VStack {
            workspaceActivityBar

            Spacer(minLength: 0)
        }
        .frame(width: 72)
        .padding(.top, 10)
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
            title: panelTitle(for: panel),
            isCollapsed: panelState.isCollapsed,
            onToggleCollapse: { store.send(.panelCollapseToggled(panel)) }
        ) {
            switch panel {
            case .brush:
                leftWorkspaceSidebar
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

    func panelTitle(for panel: StudioPanelKind) -> String {
        switch panel {
        case .brush:
            switch workspaceSidebarSection {
            case .explorer:
                return "Explorer"
            case .brush:
                return panel.title(language)
            case .ai:
                return "Nano Banana"
            }
        case .layers:
            return panel.title(language)
        }
    }

    @ViewBuilder
    var leftWorkspaceSidebar: some View {
        switch workspaceSidebarSection {
        case .explorer:
            workspaceExplorerSidebar
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
        case .ai:
            workspaceAISidebar
        }
    }

    var workspaceActivityBar: some View {
        VStack(spacing: 10) {
            workspaceBrandBadge

            VStack(spacing: 6) {
                workspaceActivityButton(
                    symbol: "folder",
                    isActive: workspaceSidebarSection == .explorer,
                    label: "Explorer"
                ) {
                    workspaceSidebarSection = .explorer
                    if store.brushPanel.isCollapsed {
                        store.send(.panelCollapseToggled(.brush))
                    }
                }

                workspaceActivityButton(
                    symbol: "paintbrush.pointed",
                    isActive: workspaceSidebarSection == .brush,
                    label: language.localized("ブラシ")
                ) {
                    workspaceSidebarSection = .brush
                    if store.brushPanel.isCollapsed {
                        store.send(.panelCollapseToggled(.brush))
                    }
                }

                workspaceActivityButton(
                    symbol: "sparkles.rectangle.stack",
                    isActive: workspaceSidebarSection == .ai,
                    label: "Nano Banana"
                ) {
                    workspaceSidebarSection = .ai
                    workspaceBottomPanelSection = .nanoBanana
                    workspaceBottomPanelCollapsed = false
                    if store.brushPanel.isCollapsed {
                        store.send(.panelCollapseToggled(.brush))
                    }
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.08))
                .padding(.vertical, 6)

            toolDock
            toolDockMetrics
                .padding(.top, 4)
            toolDockColorCluster
                .padding(.top, 6)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 10)
    }

    var workspaceBrandBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(StudioTheme.Palette.cardFillStrong)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
            Text("P")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(StudioTheme.Palette.accentBright)
        }
        .frame(width: 38, height: 38)
    }

    func workspaceActivityButton(symbol: String, isActive: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isActive ? StudioTheme.Palette.textPrimary : StudioTheme.Palette.textSecondary)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? StudioTheme.Palette.selectedFill : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isActive ? StudioTheme.Palette.selectedBorder : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    var workspaceExplorerSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                workspaceExplorerSection(title: "OPEN EDITORS") {
                    ForEach(store.openTabs) { tab in
                        Button {
                            store.send(.tabSelected(tab.id))
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: tab.pane == .secondary ? "sidebar.right" : "doc")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(tab.id == store.activeTabID ? StudioTheme.Palette.accentBright : StudioTheme.Palette.textSecondary)
                                Text(tab.title)
                                    .font(StudioTheme.Typography.label(12))
                                    .foregroundStyle(StudioTheme.Palette.textPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                if tab.isDirty {
                                    Circle()
                                        .fill(StudioTheme.Palette.accentBright)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(tab.id == store.activeTabID ? Color.white.opacity(0.08) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(language.localized("閉じる")) {
                                store.send(.tabClosed(tab.id))
                            }
                            Button(language.localized("他を閉じる")) {
                                store.send(.closeOtherTabs(tab.id))
                            }
                            Button(language.localized("右側を閉じる")) {
                                store.send(.closeTabsToRight(tab.id))
                            }
                            Button(language.localized("右ペインへ移動")) {
                                store.send(.moveTabToSecondaryPane(tab.id))
                            }
                            Button(language.localized("Explorer に表示")) {
                                workspaceSidebarSection = .explorer
                            }
                        }
                    }
                }

                workspaceExplorerSection(title: "WORKSPACE") {
                    Button {
                        showsOpenDocumentImporter = true
                    } label: {
                        workspaceExplorerActionRow(symbol: "folder.badge.plus", title: language.localized("ファイルを開く"))
                    }
                    .buttonStyle(.plain)

                    Button {
                        newCanvasWidthText = "\(Int(CanvasFeature.defaultCanvasSize.width.rounded()))"
                        newCanvasHeightText = "\(Int(CanvasFeature.defaultCanvasSize.height.rounded()))"
                        showsNewCanvasSheet = true
                    } label: {
                        workspaceExplorerActionRow(symbol: "square.and.pencil", title: language.localized("新規キャンバス"))
                    }
                    .buttonStyle(.plain)
                }

                workspaceExplorerSection(title: "FILES") {
                    ForEach(workspaceExplorerFolders, id: \.self) { folderPath in
                        workspaceExplorerFolderSection(folderPath: folderPath)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    func workspaceExplorerSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(StudioTheme.Typography.mono(10))
                .foregroundStyle(.white.opacity(0.45))
            content()
        }
    }

    func workspaceExplorerActionRow(symbol: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(StudioTheme.Palette.textSecondary)
            Text(title)
                .font(StudioTheme.Typography.label(12))
                .foregroundStyle(StudioTheme.Palette.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    var workspaceExplorerFolders: [String?] {
        let folders = Set(store.homeProjects.map(\.relativeFolderPath))
        return folders
            .sorted { lhs, rhs in
                switch (lhs, rhs) {
                case (nil, nil):
                    return false
                case (nil, _):
                    return true
                case (_, nil):
                    return false
                case let (lhs?, rhs?):
                    return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
                }
            }
    }

    func workspaceExplorerProjects(in folderPath: String?) -> [SavedProjectSummary] {
        store.homeProjects.filter { $0.relativeFolderPath == folderPath }
    }

    func workspaceExplorerFolderSection(folderPath: String?) -> some View {
        let projects = workspaceExplorerProjects(in: folderPath)
        let title = folderPath ?? "root"

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: folderPath == nil ? "internaldrive" : "folder")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Text(title)
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .dropDestination(for: URL.self) { items, _ in
                guard let projectURL = items.first else { return false }
                store.send(.moveSavedProject(projectURL, folderPath))
                return true
            }

            ForEach(projects) { project in
                Button {
                    store.send(.homeProjectSelected(project.url))
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(StudioTheme.Palette.textSecondary)
                            Text(project.name)
                                .font(StudioTheme.Typography.label(12))
                                .foregroundStyle(StudioTheme.Palette.textPrimary)
                                .lineLimit(1)
                        }
                        Text("\(Int(project.canvasSize.width)) × \(Int(project.canvasSize.height))")
                            .font(StudioTheme.Typography.mono(10))
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.leading, 19)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.02))
                    )
                }
                .buttonStyle(.plain)
                .draggable(project.url)
            }
        }
    }

    var workspaceAISidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                workspaceExplorerSection(title: "NANO BANANA") {
                    Text(language.localized("生成AIの編集ハブ。下部パネルからすぐ実行し、必要なときだけ詳細シートを開けます。"))
                        .font(StudioTheme.Typography.body(13))
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }

                workspaceExplorerSection(title: "SHORTCUTS") {
                    Button {
                        prepareNanoBananaComposer()
                        workspaceBottomPanelSection = .nanoBanana
                        workspaceBottomPanelCollapsed = false
                    } label: {
                        workspaceExplorerActionRow(symbol: "text.badge.plus", title: language.localized("クイックプロンプト"))
                    }
                    .buttonStyle(.plain)

                    Button {
                        prepareNanoBananaComposer()
                        showsNanoBananaSheet = true
                    } label: {
                        workspaceExplorerActionRow(symbol: "slider.horizontal.3", title: language.localized("詳細設定を開く"))
                    }
                    .buttonStyle(.plain)
                }

                if !store.nanoBananaJobs.isEmpty {
                    workspaceExplorerSection(title: "RECENT JOBS") {
                        ForEach(store.nanoBananaJobs.prefix(5)) { job in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(job.request.model.title(language))
                                        .font(StudioTheme.Typography.label(12))
                                        .foregroundStyle(StudioTheme.Palette.textPrimary)
                                    Spacer()
                                    Text(job.status.rawValue.capitalized)
                                        .font(StudioTheme.Typography.mono(10))
                                        .foregroundStyle(.white.opacity(0.45))
                                }
                                Text(job.request.prompt)
                                    .font(StudioTheme.Typography.body(12))
                                    .foregroundStyle(.white.opacity(0.62))
                                    .lineLimit(2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                            )
                        }
                    }
                }
            }
            .padding(.vertical, 6)
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
                    workspaceBottomPanelCollapsed = true
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.03))

            Group {
                switch workspaceBottomPanelSection {
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
            Text(workspaceBottomPanelSection == .nanoBanana ? "NANO BANANA" : workspaceBottomPanelSection == .history ? "HISTORY" : "OUTPUT")
                .font(StudioTheme.Typography.mono(10))
                .foregroundStyle(.white.opacity(0.55))
            Spacer(minLength: 0)
            workspaceTabChromeButton(symbol: "chevron.up") {
                workspaceBottomPanelCollapsed = false
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

    func workspaceBottomTab(title: String, section: ContentView.WorkspaceBottomPanelSection) -> some View {
        Button {
            workspaceBottomPanelSection = section
        } label: {
            Text(title)
                .font(StudioTheme.Typography.mono(10))
                .foregroundStyle(workspaceBottomPanelSection == section ? .white.opacity(0.9) : .white.opacity(0.45))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(workspaceBottomPanelSection == section ? Color.white.opacity(0.10) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    var workspaceNanoBananaPanel: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(language.localized("Prompt"))
                    .font(StudioTheme.Typography.label(12))
                    .foregroundStyle(.white.opacity(0.55))
                TextEditor(text: $nanoBananaPrompt)
                    .font(StudioTheme.Typography.body(13))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 10) {
                workspaceNanoBananaStat(label: language.localized("Input"), value: resolvedNanoBananaInputLayerName)
                workspaceNanoBananaStat(label: language.localized("Scope"), value: nanoBananaEditScope.title(language))
                workspaceNanoBananaStat(label: language.localized("Output"), value: nanoBananaOutputMode.title(language))
                workspaceNanoBananaStat(label: language.localized("Model"), value: nanoBananaModel.title(language))

                HStack(spacing: 8) {
                    Button(language.localized("Run")) {
                        submitNanoBananaRequest(closeSheet: false)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.94))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(StudioTheme.Palette.accentBright.opacity(0.8))
                    )
                    .disabled(nanoBananaGenerateDisabled)

                    Button(language.localized("Open Full Panel")) {
                        showsNanoBananaSheet = true
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.72))
                }
            }
            .frame(width: 250, alignment: .leading)
        }
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

    var workspaceHistoryPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(store.nanoBananaHistory.prefix(8)) { item in
                    Button {
                        nanoBananaPrompt = item.request.prompt
                        nanoBananaInputLayerIndex = item.request.inputLayerIndex
                        nanoBananaEditScope = item.request.editScope
                        nanoBananaOutputMode = item.request.outputMode
                        nanoBananaModel = item.request.model
                        nanoBananaMaskExpansion = item.request.maskSettings.expansion
                        nanoBananaInvertsMask = item.request.maskSettings.isInverted
                        workspaceBottomPanelSection = .nanoBanana
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.request.prompt)
                                .font(StudioTheme.Typography.body(13))
                                .foregroundStyle(.white.opacity(0.88))
                                .lineLimit(2)
                            Text(item.request.model.title(language))
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
                ForEach(store.nanoBananaJobs.prefix(8)) { job in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(job.status == .succeeded ? Color.green.opacity(0.8) : job.status == .failed ? Color.red.opacity(0.8) : StudioTheme.Palette.accentBright)
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(job.request.model.title(language))
                                    .font(StudioTheme.Typography.label(12))
                                    .foregroundStyle(.white.opacity(0.9))
                                Spacer(minLength: 0)
                                Text(job.status.rawValue.capitalized)
                                    .font(StudioTheme.Typography.mono(10))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            Text(job.request.prompt)
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
        store.send(.brushPalette(.binding(.set(\.brush.radius, clamped))))
        toolMetricSizeText = "\(Int(clamped.rounded()))"
        selectedToolMetricEditor = nil
    }

    func commitToolMetricOpacityInput() {
        guard let value = Double(toolMetricOpacityText) else {
            toolMetricOpacityText = "\(Int((store.brushPalette.brush.opacity * 100).rounded()))"
            return
        }
        let clampedPercent = min(max(value, 10), 100)
        store.send(.brushPalette(.binding(.set(\.brush.opacity, clampedPercent / 100.0))))
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
