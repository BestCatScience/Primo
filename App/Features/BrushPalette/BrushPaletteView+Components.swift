import SwiftUI
import UIKit

extension BrushPaletteView {
    func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(StudioTheme.Typography.mono(10))
            .foregroundStyle(.white.opacity(0.48))
    }

    func metricRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(StudioTheme.Typography.mono(10))
                .foregroundStyle(.white.opacity(0.48))
            Spacer()
            Text(value)
                .font(StudioTheme.Typography.title(12))
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    func sliderRow<SliderView: View>(title: String, value: String, slider: SliderView, isFullHeight: Bool = false, proxy: GeometryProxy? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(StudioTheme.Typography.title(12))
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                Text(value)
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(.white.opacity(0.5))
            }
            if isFullHeight {
                GeometryReader { geometry in
                    slider
                        .tint(StudioTheme.Palette.accentBright)
                        .frame(height: proxy?.size.height ?? geometry.size.height)
                        .contentShape(Rectangle())
                }
                .frame(height: proxy?.size.height ?? 200)
            } else {
                slider
                    .tint(StudioTheme.Palette.accentBright)
                    .frame(minHeight: 38)
                    .contentShape(Rectangle())
            }
        }
    }

    func segmentedModeRow<Content: View>(
        title: String,
        selectedTitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(StudioTheme.Typography.title(12))
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                Text(selectedTitle)
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(.white.opacity(0.5))
            }
            content()
                .frame(minHeight: 32)
        }
    }

    func dynamicControlMenuRow(
        title: String,
        selection: Binding<PhotoshopDynamicControl>,
        allowed: [PhotoshopDynamicControl]
    ) -> some View {
        segmentedModeRow(
            title: title,
            selectedTitle: selection.wrappedValue.localizedTitle(language)
        ) {
            Menu {
                ForEach(allowed) { control in
                    Button(control.localizedTitle(language)) {
                        selection.wrappedValue = control
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selection.wrappedValue.localizedTitle(language))
                        .font(StudioTheme.Typography.label(11))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.48))
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(StudioTheme.Palette.cardFillStrong)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    func colorSwatch(color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 1.5))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.95 : 0.16), lineWidth: isSelected ? 2.5 : 1)
                        .padding(isSelected ? -4 : -2)
                )
        }
        .buttonStyle(.plain)
        .minimumHitTarget()
    }

    func presetChip(
        preset: BrushPreset,
        isSelected: Bool,
        action: @escaping () -> Void,
        longPressAction: (() -> Void)? = nil
    ) -> some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            StudioTheme.Palette.overlayBlack.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            BrushStrokePreview(style: BrushPreviewStyle(preset: preset), compact: false)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(preset.name)
                    .font(StudioTheme.Typography.label(11))
                    .foregroundStyle(.white.opacity(0.96))
                    .lineLimit(1)
                Text(preset.tipKind.localizedTitle(language))
                    .font(StudioTheme.Typography.mono(9))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(StudioTheme.Palette.overlayBlack.opacity(0.34))
            )
            .padding(8)
        }
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? StudioTheme.Palette.accent.opacity(0.28) : StudioTheme.Palette.hairline)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? StudioTheme.Palette.accent : StudioTheme.Palette.cardBorder, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture(perform: action)
        .onLongPressGesture(minimumDuration: 0.45) {
            longPressAction?()
        }
    }

    func verticalBrushSlider(
        title: String,
        valueText: String,
        normalizedValue: Binding<Double>
    ) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(StudioTheme.Typography.mono(8))
                .foregroundStyle(.white.opacity(0.46))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            VerticalValueSlider(value: normalizedValue)
                .frame(width: 30, height: 132)

            Text(valueText)
                .font(StudioTheme.Typography.mono(8))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    func cardContainer<Content: View>(
        showsChrome: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(showsChrome ? 14 : 0)
            .background(
                Group {
                    if showsChrome {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(StudioTheme.Palette.cardFill)
                    }
                }
            )
            .overlay(
                Group {
                    if showsChrome {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
                    }
                }
            )
    }

    var brushLibrarySidebar: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 12) {
                if showsTitle {
                    Text(language.localized("ブラシライブラリ"))
                        .font(StudioTheme.Typography.title(18))
                        .foregroundStyle(.white.opacity(0.94))
                }

                HStack(spacing: 8) {
                    sidebarIconButton(
                        title: language.localized("設定"),
                        systemImage: "slider.horizontal.3",
                        isActive: store.showsBrushSettingsPopover
                    ) {
                        store.showsBrushSettingsPopover.toggle()
                    }

                    sidebarIconButton(
                        title: language.localized("保存"),
                        systemImage: "square.and.arrow.down.on.square"
                    ) {
                        store.send(.saveCurrentBrushButtonTapped)
                    }

                    sidebarIconButton(
                        title: language.localized("管理"),
                        systemImage: "trash",
                        isActive: showsSavedBrushDeleteMode
                    ) {
                        showsSavedBrushDeleteMode.toggle()
                    }

                    sidebarIconButton(
                        title: language.localized("読込"),
                        systemImage: "square.and.arrow.down"
                    ) {
                        isImportingBrush = true
                    }
                }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        brushLibrarySection(
                            title: language.localized("保存済み"),
                            presets: store.savedPresets,
                            emptyMessage: language.localized("保存したブラシがここに並びます。"),
                            allowsDeletion: true
                        )

                        brushLibrarySection(
                            title: language.localized("プリセット"),
                            presets: store.presets,
                            emptyMessage: language.localized("まだプリセットがありません。"),
                            allowsDeletion: false
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                verticalBrushSlider(
                    title: language.localized("サイズ"),
                    valueText: "\(Int(store.brushRadius.rounded()))",
                    normalizedValue: Binding(
                        get: { min(max((store.brushRadius - 1.0) / 99.0, 0.0), 1.0) },
                        set: { store.brushRadius = 1.0 + ($0 * 99.0) }
                    )
                )

                verticalBrushSlider(
                    title: language.localized("不透明"),
                    valueText: "\(Int((store.brushOpacity * 100).rounded()))%",
                    normalizedValue: $store.brushOpacity
                )
            }
            .frame(width: 34)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }

    func heroSliderRow<SliderView: View>(title: String, value: String, slider: SliderView) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(StudioTheme.Typography.title(floatingPanelIsWide ? 16 : 15))
                    .foregroundStyle(Color.black.opacity(0.72))

                slider
                    .tint(Color.black.opacity(0.55))
                    .frame(minHeight: floatingPanelIsWide ? 36 : 32)
            }

            Text(value)
                .font(StudioTheme.Typography.title(floatingPanelIsWide ? 16 : 15))
                .foregroundStyle(Color.black.opacity(0.64))
                .frame(minWidth: floatingPanelIsWide ? 84 : 74)
                .frame(height: floatingPanelIsWide ? 46 : 42)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.07))
                )
        }
    }

    func brushLibrarySection(
        title: String,
        presets: [BrushPreset],
        emptyMessage: String,
        allowsDeletion: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(StudioTheme.Typography.mono(10))
                .foregroundStyle(.white.opacity(0.48))

            if presets.isEmpty {
                Text(emptyMessage)
                    .font(StudioTheme.Typography.body(11))
                    .foregroundStyle(.white.opacity(0.46))
                    .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(presets) { preset in
                        if allowsDeletion && showsSavedBrushDeleteMode {
                            deletableSavedPresetChip(preset: preset)
                        } else {
                            presetChip(
                                preset: preset,
                                isSelected: store.selectedBrush == preset,
                                action: {
                                    store.send(.selectPreset(preset))
                                },
                                longPressAction: {
                                    store.send(.selectPreset(preset))
                                    store.showsBrushSettingsPopover = true
                                }
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func deletableSavedPresetChip(preset: BrushPreset) -> some View {
        ZStack(alignment: .topTrailing) {
            presetChip(
                preset: preset,
                isSelected: store.selectedBrush == preset
            ) {
                store.send(.deleteSavedPresetButtonTapped(preset.name))
            }

            Circle()
                .fill(Color.red.opacity(0.92))
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                )
                .padding(.top, 6)
                .padding(.trailing, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func sidebarIconButton(
        title: String,
        systemImage: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 20, height: 20)
                Text(title)
                    .font(StudioTheme.Typography.mono(9))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.92))
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? StudioTheme.Palette.accent.opacity(0.28) : StudioTheme.Palette.cardFillStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isActive ? StudioTheme.Palette.accent : StudioTheme.Palette.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    func withSecurityScopedAccess<T>(to url: URL, _ work: () -> T) -> T {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return work()
    }

    func brushTipButton(tipKind: BrushTipKind, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tipKind.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16)

                Text(tipKind.localizedTitle(language))
                    .font(StudioTheme.Typography.label(11))

                Spacer(minLength: 0)
            }
            .foregroundStyle(.white.opacity(isSelected ? 0.96 : 0.82))
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? StudioTheme.Palette.accent.opacity(0.28) : StudioTheme.Palette.hairline)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? StudioTheme.Palette.accent : StudioTheme.Palette.cardBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
