import SwiftUI
import UIKit

extension BrushPaletteView {
    var usesLightPanelTheme: Bool {
        rendersFloatingPanelOnly
    }

    var panelPrimaryTextStyle: Color {
        usesLightPanelTheme ? Color.black.opacity(0.78) : .white.opacity(0.88)
    }

    var panelSecondaryTextStyle: Color {
        usesLightPanelTheme ? Color.black.opacity(0.52) : .white.opacity(0.5)
    }

    var panelTertiaryTextStyle: Color {
        usesLightPanelTheme ? Color.black.opacity(0.4) : .white.opacity(0.48)
    }

    var panelStrongTextStyle: Color {
        usesLightPanelTheme ? Color.black.opacity(0.9) : .white.opacity(0.92)
    }

    var panelCardFill: Color {
        usesLightPanelTheme ? Color.black.opacity(0.03) : StudioTheme.Palette.cardFill
    }

    var panelCardFillStrong: Color {
        usesLightPanelTheme ? Color.black.opacity(0.05) : StudioTheme.Palette.cardFillStrong
    }

    var panelCardBorder: Color {
        usesLightPanelTheme ? Color.black.opacity(0.08) : StudioTheme.Palette.cardBorder
    }

    var panelHairlineFill: Color {
        usesLightPanelTheme ? Color.black.opacity(0.04) : StudioTheme.Palette.hairline
    }

    func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(StudioTheme.Typography.mono(10))
            .foregroundStyle(panelTertiaryTextStyle)
    }

    func metricRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(StudioTheme.Typography.mono(10))
                .foregroundStyle(panelTertiaryTextStyle)
            Spacer()
            Text(value)
                .font(StudioTheme.Typography.title(12))
                .foregroundStyle(panelStrongTextStyle)
        }
    }

    func sliderRow<SliderView: View>(title: String, value: String, slider: SliderView, isFullHeight: Bool = false, proxy: GeometryProxy? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(StudioTheme.Typography.title(12))
                    .foregroundStyle(panelPrimaryTextStyle)
                Spacer()
                Text(value)
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(panelSecondaryTextStyle)
            }
            if isFullHeight {
                if usesLightPanelTheme {
                    slider
                        .tint(StudioTheme.Palette.accentBright)
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                } else {
                    GeometryReader { geometry in
                        slider
                            .tint(StudioTheme.Palette.accentBright)
                            .frame(height: proxy?.size.height ?? geometry.size.height)
                            .contentShape(Rectangle())
                    }
                    .frame(height: proxy?.size.height ?? 200)
                }
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
                    .foregroundStyle(panelPrimaryTextStyle)
                Spacer()
                Text(selectedTitle)
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(panelSecondaryTextStyle)
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
                        .foregroundStyle(usesLightPanelTheme ? Color.black.opacity(0.84) : .white.opacity(0.9))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(panelTertiaryTextStyle)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(panelCardFillStrong)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(panelCardBorder, lineWidth: 1)
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
                .foregroundStyle(usesLightPanelTheme ? Color.black.opacity(0.42) : .white.opacity(0.46))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            VerticalValueSlider(value: normalizedValue)
                .frame(width: 30)
                .frame(minHeight: 132, maxHeight: .infinity)

            Text(valueText)
                .font(StudioTheme.Typography.mono(8))
                .foregroundStyle(usesLightPanelTheme ? Color.black.opacity(0.62) : .white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxHeight: .infinity)
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
                            .fill(panelCardFill)
                    }
                }
            )
            .overlay(
                Group {
                    if showsChrome {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(panelCardBorder, lineWidth: 1)
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
                        .foregroundStyle(StudioTheme.Palette.textPrimary)
                }

                HStack(spacing: 8) {
                    sidebarIconButton(
                        title: language.localized("設定"),
                        systemImage: "slider.horizontal.3",
                        isActive: store.ui.showsBrushSettingsPopover
                    ) {
                        store.ui.showsBrushSettingsPopover.toggle()
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
                            presets: store.library.savedPresets,
                            emptyMessage: language.localized("保存したブラシがここに並びます。"),
                            allowsDeletion: true
                        )

                        brushLibrarySection(
                            title: language.localized("プリセット"),
                            presets: store.library.presets,
                            emptyMessage: language.localized("まだプリセットがありません。"),
                            allowsDeletion: false
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                brushColorSectionUnderPresets
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                verticalBrushSlider(
                    title: language.localized("サイズ"),
                    valueText: "\(Int(store.brush.radius.rounded()))",
                    normalizedValue: Binding(
                        get: { min(max((store.brush.radius - 1.0) / (BrushPaletteFeature.maximumBrushRadius - 1.0), 0.0), 1.0) },
                        set: { store.brush.radius = 1.0 + ($0 * (BrushPaletteFeature.maximumBrushRadius - 1.0)) }
                    )
                )
                .frame(maxHeight: .infinity)

                verticalBrushSlider(
                    title: language.localized("不透明"),
                    valueText: "\(Int((store.brush.opacity * 100).rounded()))%",
                    normalizedValue: $store.brush.opacity
                )
                .frame(maxHeight: .infinity)
            }
            .frame(width: 34)
            .frame(maxHeight: .infinity, alignment: .top)
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
                .foregroundStyle(StudioTheme.Palette.textMuted)

            if presets.isEmpty {
                Text(emptyMessage)
                    .font(StudioTheme.Typography.body(11))
                    .foregroundStyle(StudioTheme.Palette.textMuted)
                    .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(presets) { preset in
                        if allowsDeletion && showsSavedBrushDeleteMode {
                            deletableSavedPresetChip(preset: preset)
                        } else {
                            presetChip(
                                preset: preset,
                                isSelected: store.library.selectedBrush == preset,
                                action: {
                                    store.send(.selectPreset(preset))
                                },
                                longPressAction: {
                                    store.send(.selectPreset(preset))
                                    store.ui.showsBrushSettingsPopover = true
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
                isSelected: store.library.selectedBrush == preset
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

    var brushColorSectionUnderPresets: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(language.localized("色").uppercased())
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(StudioTheme.Palette.textMuted)
                Spacer(minLength: 0)
                Text(store.brush.selectedColorSlot.localizedTitle(language))
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(StudioTheme.Palette.textSecondary)
            }

            SpectrumColorControl(color: editableBrushColorBinding)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(panelHairlineFill)
                )
                .opacity(isTransparentBrushColorSelected ? 0.42 : 1.0)
                .allowsHitTesting(!isTransparentBrushColorSelected)
                .overlay {
                    if isTransparentBrushColorSelected {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.24))
                            .overlay {
                                VStack(spacing: 6) {
                                    Image(systemName: "eraser.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text(language.localized("透明色で描画"))
                                        .font(StudioTheme.Typography.mono(10))
                                }
                                .foregroundStyle(.white.opacity(0.88))
                            }
                    }
                }

            LazyVGrid(columns: paletteColumns, alignment: .leading, spacing: 8) {
                ForEach(PaletteSwatch.defaults) { swatch in
                    colorSwatch(
                        color: swatch.color,
                        isSelected: !isTransparentBrushColorSelected && editableBrushColorBinding.wrappedValue == swatch.color
                    ) {
                        store.send(
                            .binding(
                                .set(
                                    store.brush.selectedColorSlot == .secondary ? \.brush.secondaryColor : \.brush.color,
                                    swatch.color
                                )
                            )
                        )
                    }
                    .opacity(isTransparentBrushColorSelected ? 0.38 : 1.0)
                    .allowsHitTesting(!isTransparentBrushColorSelected)
                }
            }
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
            .foregroundStyle(isActive ? StudioTheme.Palette.textPrimary : StudioTheme.Palette.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? StudioTheme.Palette.selectedFill : StudioTheme.Palette.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isActive ? StudioTheme.Palette.selectedBorder : StudioTheme.Palette.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
            .foregroundStyle(
                usesLightPanelTheme
                    ? Color.black.opacity(isSelected ? 0.86 : 0.72)
                    : .white.opacity(isSelected ? 0.96 : 0.82)
            )
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? StudioTheme.Palette.accent.opacity(0.18) : panelHairlineFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? StudioTheme.Palette.accent.opacity(0.75) : panelCardBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
