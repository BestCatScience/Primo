import SwiftUI

extension ContentView {
    var canvasSizePresets: [(label: String, width: Int, height: Int)] {
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

    var newCanvasSheet: some View {
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

    func parsedCanvasDimension(from text: String) -> Int? {
        let digits = text.filter(\.isNumber)
        guard let value = Int(digits), (64...8192).contains(value) else { return nil }
        return value
    }

    var menuBar: some View {
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

    var undoRedoBar: some View {
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

    func menuBarMenu<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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

    var activeLayer: LayerRowModel? {
        store.layerSidebar.layers.first { $0.index == store.layerSidebar.activeLayerIndex }
    }

    var activeLayerIsVisible: Bool {
        activeLayer?.visible ?? false
    }

    var activeLayerPosition: Int? {
        store.layerSidebar.layers.firstIndex { $0.index == store.layerSidebar.activeLayerIndex }
    }

    var canSelectPreviousLayer: Bool {
        guard let activeLayerPosition else { return false }
        return activeLayerPosition > 0
    }

    var canSelectNextLayer: Bool {
        guard let activeLayerPosition else { return false }
        return activeLayerPosition < store.layerSidebar.layers.count - 1
    }
}
