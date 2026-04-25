import PrimoDocumentContracts
import SwiftUI
import UIKit

extension BrushPaletteView {
    @ViewBuilder
    func floatingBrushSettingsPanel(proxy: GeometryProxy) -> some View {
        if currentTool == .brush || currentTool == .erase {
            compactBrushToolPanel(proxy: proxy)
        } else {
            legacyFloatingBrushSettingsPanel(proxy: proxy)
        }
    }

    private func legacyFloatingBrushSettingsPanel(proxy: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            floatingPanelHeader
                .padding(.horizontal, floatingPanelHorizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    floatingPanelTopSection
                    floatingPanelCategoryStrip
                    floatingPanelCategoryContent(proxy: proxy)
                }
                .padding(.horizontal, floatingPanelHorizontalPadding)
                .padding(.bottom, 24)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.98),
                            Color(red: 0.97, green: 0.97, blue: 0.96)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 28, x: 0, y: 18)
        .environment(\.colorScheme, .light)
    }

    var floatingPanelIsWide: Bool {
        horizontalSizeClass == .regular && currentTool != .brush && currentTool != .erase
    }

    var floatingPanelHorizontalPadding: CGFloat {
        floatingPanelIsWide ? 24 : 18
    }

    var floatingPanelHeader: some View {
        HStack(spacing: 12) {
            Button {
                store.ui.showsBrushSettingsPopover = false
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.62))
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.04))
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.library.selectedBrush?.name ?? currentTool.localizedTitle(language))
                    .font(StudioTheme.Typography.title(16))
                    .foregroundStyle(Color.black.opacity(0.72))
                Text(language.localized("ブラシの詳細設定"))
                    .font(StudioTheme.Typography.body(11))
                    .foregroundStyle(Color.black.opacity(0.38))
            }

            Spacer(minLength: 0)
        }
    }

    func compactBrushToolPanel(proxy: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            compactBrushToolHeader
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    compactBrushPreviewCard
                    compactInspectorTabPicker
                    compactBrushToolContent(proxy: proxy)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.99),
                            Color(red: 0.97, green: 0.97, blue: 0.96)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 26, x: 0, y: 16)
        .environment(\.colorScheme, .light)
    }

    var compactBrushToolHeader: some View {
        HStack(spacing: 8) {
            Button {
                store.ui.showsBrushSettingsPopover = false
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.52))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)

            Text(language.localized("ツール"))
                .font(StudioTheme.Typography.title(18))
                .foregroundStyle(Color.black.opacity(0.76))

            Spacer(minLength: 0)
        }
    }

    var compactBrushPreviewCard: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(currentTool == .erase ? Color(red: 0.74, green: 0.74, blue: 0.74) : Color.white)
            .frame(height: 84)
            .overlay {
                ZStack {
                    if currentTool == .brush {
                        CompactPreviewCheckerboard(cornerRadius: 12)
                            .padding(1)
                    }

                    BrushStrokePreview(style: currentBrushPreviewStyle)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
    }

    var compactInspectorTabPicker: some View {
        HStack(spacing: 8) {
            ForEach(ToolInspectorTab.allCases) { tab in
                let isSelected = selectedToolInspectorTab == tab
                Button {
                    selectedToolInspectorTab = tab
                } label: {
                    Text(tab.localizedTitle(language))
                        .font(StudioTheme.Typography.title(14))
                        .foregroundStyle(isSelected ? StudioTheme.Palette.accent : Color.black.opacity(0.62))
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected ? Color(red: 0.86, green: 0.93, blue: 1.0) : Color.black.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    func compactBrushToolContent(proxy: GeometryProxy) -> some View {
        if selectedToolInspectorTab == .basic {
            compactBasicBrushControls
        } else {
            VStack(alignment: .leading, spacing: 12) {
                controlsCard(proxy: proxy, showsChrome: true)
                if currentTool == .brush {
                    detailCard(showsChrome: true)
                }
            }
        }
    }

    var compactBasicBrushControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            compactSliderRow(
                title: language.localized("ブラシサイズ"),
                value: "\(Int(store.brush.radius.rounded()))",
                slider: Slider(value: $store.brush.radius, in: 1...BrushPaletteFeature.maximumBrushRadius, step: 1)
            )

            compactSliderRow(
                title: language.localized("不透明度"),
                value: "\(Int((store.brush.opacity * 100).rounded()))",
                slider: Slider(value: $store.brush.opacity, in: 0.1...1.0)
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(language.localized("ブラシタイプ"))
                    .font(StudioTheme.Typography.title(14))
                    .foregroundStyle(Color.black.opacity(0.72))

                HStack(spacing: 0) {
                    compactToolSwitchButton(tool: .brush)
                    compactToolSwitchButton(tool: .erase)
                }
                .padding(2)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.06))
                )
            }

            compactSliderRow(
                title: language.localized("手ぶれ補正"),
                value: "\(Int((store.brush.stabilization * 100).rounded()))",
                slider: Slider(value: $store.brush.stabilization, in: 0.0...1.0)
            )
        }
    }

    func compactSliderRow<SliderView: View>(title: String, value: String, slider: SliderView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(StudioTheme.Typography.title(14))
                    .foregroundStyle(Color.black.opacity(0.74))

                Spacer(minLength: 0)

                Text(value)
                    .font(StudioTheme.Typography.title(14))
                    .foregroundStyle(Color.black.opacity(0.6))
                    .padding(.horizontal, 8)
                    .frame(minWidth: 48, minHeight: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.black.opacity(0.05))
                    )
            }

            slider
                .tint(Color.black.opacity(0.45))
                .frame(minHeight: 28)
        }
    }

    func compactToolSwitchButton(tool: StudioToolKind) -> some View {
        let isSelected = currentTool == tool

        return Button {
            onSelectTool(tool)
        } label: {
            Text(tool.localizedTitle(language))
                .font(StudioTheme.Typography.title(14))
                .foregroundStyle(isSelected ? Color.black.opacity(0.78) : Color.black.opacity(0.54))
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.95) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var floatingPanelTopSection: some View {
        if floatingPanelIsWide {
            HStack(alignment: .top, spacing: 18) {
                floatingPanelPreviewCard
                    .frame(maxWidth: .infinity)
                floatingPanelPrimaryControls
                    .frame(width: 240)
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                floatingPanelPreviewCard
                floatingPanelPrimaryControls
            }
        }
    }

    var floatingPanelPreviewCard: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Color.white)
            .frame(height: floatingPanelIsWide ? 186 : 150)
            .overlay(
                BrushStrokePreview(style: currentBrushPreviewStyle)
                    .padding(.horizontal, floatingPanelIsWide ? 24 : 18)
                    .padding(.vertical, floatingPanelIsWide ? 18 : 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
    }

    var floatingPanelPrimaryControls: some View {
        VStack(spacing: 14) {
            heroSliderRow(
                title: language.localized("ブラシサイズ"),
                value: String(format: "%.1f", store.brush.radius),
                slider: Slider(value: $store.brush.radius, in: 1...BrushPaletteFeature.maximumBrushRadius)
            )

            heroSliderRow(
                title: language.localized("不透明度"),
                value: "\(Int((store.brush.opacity * 100).rounded()))",
                slider: Slider(value: $store.brush.opacity, in: 0.1...1.0)
            )

            Button {
                store.send(.resetCurrentBrushSettingsButtonTapped)
            } label: {
                Text(language.localized("設定をリセット"))
                    .font(StudioTheme.Typography.title(14))
                    .foregroundStyle(Color.black.opacity(0.52))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, floatingPanelIsWide ? 4 : 0)
        .padding(.vertical, floatingPanelIsWide ? 8 : 0)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(floatingPanelIsWide ? 0.03 : 0.0))
        )
    }

    var floatingPanelCategoryStrip: some View {
        HStack(spacing: 12) {
            ForEach(BrushSettingsCategory.allCases) { category in
                let isSelected = selectedBrushSettingsCategory == category
                Button {
                    selectedBrushSettingsCategory = category
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: category.systemImage)
                            .font(.system(size: 15, weight: .semibold))
                        Text(category.localizedTitle(language))
                            .font(StudioTheme.Typography.mono(9))
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.black.opacity(0.52))
                    .frame(maxWidth: .infinity)
                    .frame(height: floatingPanelIsWide ? 60 : 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isSelected ? StudioTheme.Palette.accent : Color.black.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    func floatingPanelCategoryContent(proxy: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            categorySummaryPills
            controlsCard(proxy: proxy, showsChrome: true, showsCategoryPicker: false)
            if selectedBrushSettingsCategory == .texture {
                detailCard(showsChrome: true)
            }
        }
        .padding(.top, 2)
    }

    var categorySummaryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                summaryPill(
                    title: language.localized("先端"),
                    value: store.brush.tipKind.localizedTitle(language)
                )
                summaryPill(
                    title: language.localized("硬さ"),
                    value: "\(Int((store.brush.hardness * 100).rounded()))%"
                )
                summaryPill(
                    title: language.localized("フロー"),
                    value: "\(Int((store.brush.flow * 100).rounded()))%"
                )
                summaryPill(
                    title: language.localized("散布"),
                    value: store.brush.scatterEnabled ? language.localized("オン") : language.localized("オフ")
                )
            }
            .padding(.vertical, 2)
        }
    }

    func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(StudioTheme.Typography.mono(9))
                .foregroundStyle(Color.black.opacity(0.35))
            Text(value)
                .font(StudioTheme.Typography.title(12))
                .foregroundStyle(Color.black.opacity(0.68))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.05))
        )
    }
}

private struct CompactPreviewCheckerboard: View {
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let tile: CGFloat = 10

            Canvas { context, size in
                let rows = Int(ceil(size.height / tile))
                let columns = Int(ceil(size.width / tile))

                for row in 0..<rows {
                    for column in 0..<columns {
                        let rect = CGRect(
                            x: CGFloat(column) * tile,
                            y: CGFloat(row) * tile,
                            width: tile,
                            height: tile
                        )
                        let color = (row + column).isMultiple(of: 2)
                            ? Color(red: 0.94, green: 0.94, blue: 0.94)
                            : Color(red: 0.84, green: 0.84, blue: 0.84)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
