import ComposableArchitecture
import SwiftUI

struct BrushPaletteView: View {
    @Bindable var store: StoreOf<BrushPaletteFeature>
    let currentTool: StudioToolKind
    var showsTitle = true
    private let paletteColumns = Array(repeating: GridItem(.fixed(22), spacing: 8), count: 5)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if showsTitle {
                    Text(currentTool == .fill ? "Fill" : "Brush")
                        .font(StudioTheme.Typography.title(26))
                        .foregroundStyle(.white.opacity(0.94))
                }

                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel(currentTool == .fill ? "Fill Engine" : "Brush Engine")

                    if currentTool == .fill {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            store.brushColor.opacity(0.95),
                                            store.brushColor.opacity(0.32)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: "paintbrush.fill")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundStyle(StudioTheme.Palette.textPrimary)
                                )

                            VStack(alignment: .leading, spacing: 6) {
                                metricRow("Threshold", value: store.fillThresholdMode.title)
                                metricRow(
                                    store.fillThresholdMode == .opacity ? "Opacity Match" : "Color Match",
                                    value: "\(Int((store.fillThresholdMode == .opacity ? store.fillOpacityTolerance : store.fillColorTolerance) * 100))%"
                                )
                                metricRow("Expansion", value: "\(Int(store.fillExpansion)) px")
                                metricRow("Color", value: store.selectedBrush?.name ?? "Custom Mix")
                            }
                        }
                    } else {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            store.brushColor.opacity(0.95),
                                            store.brushColor.opacity(0.32)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Circle()
                                        .fill(StudioTheme.Palette.textPrimary)
                                        .frame(
                                            width: min(58, max(10, store.brushRadius * 3.4)),
                                            height: min(58, max(10, store.brushRadius * 3.4))
                                        )
                                )

                            VStack(alignment: .leading, spacing: 6) {
                                metricRow("Radius", value: "\(Int(store.brushRadius)) px")
                                metricRow("Opacity", value: "\(Int(store.brushOpacity * 100))%")
                                metricRow("Hardness", value: "\(Int(store.brushHardness * 100))%")
                                metricRow("Pressure", value: store.brushPressureSensitivity < 0.6 ? "Soft" : store.brushPressureSensitivity > 1.2 ? "Hard" : "Medium")
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    if currentTool == .fill {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Threshold Mode")
                                .font(StudioTheme.Typography.title(12))
                                .foregroundStyle(.white.opacity(0.88))
                            HStack(spacing: 8) {
                                ForEach(FillThresholdMode.allCases) { mode in
                                    let isSelected = store.fillThresholdMode == mode
                                    Button {
                                        store.send(.binding(.set(\.fillThresholdMode, mode)))
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(isSelected ? StudioTheme.Palette.accent : StudioTheme.Palette.cardFillStrong)

                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(isSelected ? Color.white.opacity(0.18) : StudioTheme.Palette.cardBorder, lineWidth: 1)

                                            Text(mode.title)
                                                .font(StudioTheme.Typography.label(12))
                                                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.72))
                                                .padding(.horizontal, 12)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 46)
                                        .contentShape(Rectangle())
                                    }
                                    .frame(maxWidth: .infinity)
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        sliderRow(
                            title: store.fillThresholdMode == .opacity ? "Opacity Threshold" : "Color Threshold",
                            value: "\(Int((store.fillThresholdMode == .opacity ? store.fillOpacityTolerance : store.fillColorTolerance) * 100))%",
                            slider: Group {
                                if store.fillThresholdMode == .opacity {
                                    Slider(value: $store.fillOpacityTolerance, in: 0.0...1.0)
                                } else {
                                    Slider(value: $store.fillColorTolerance, in: 0.0...1.0)
                                }
                            }
                        )
                        sliderRow(
                            title: "Expansion",
                            value: "\(Int(store.fillExpansion)) px",
                            slider: Slider(value: $store.fillExpansion, in: 0...24, step: 1)
                        )
                    } else {
                        sliderRow(title: "Size", value: "\(Int(store.brushRadius)) px", slider: Slider(value: $store.brushRadius, in: 1...100))
                        sliderRow(title: "Opacity", value: "\(Int(store.brushOpacity * 100))%", slider: Slider(value: $store.brushOpacity, in: 0.1...1.0))
                        sliderRow(title: "Hardness", value: "\(Int(store.brushHardness * 100))%", slider: Slider(value: $store.brushHardness, in: 0.2...0.98))
                        sliderRow(title: "Pressure", value: store.brushPressureSensitivity < 0.6 ? "Soft" : store.brushPressureSensitivity > 1.2 ? "Hard" : "Medium", slider: Slider(value: $store.brushPressureSensitivity, in: 0.1...2.0))
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(StudioTheme.Palette.cardFill)
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            StudioTheme.Palette.textPrimary,
                                            Color.white.opacity(0.55)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(store.brushColor)
                                .padding(4)
                        }
                        .frame(width: 38, height: 38)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(currentTool == .fill ? "Fill Color" : "Color Palette")
                                .font(StudioTheme.Typography.title(14))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(store.selectedBrush?.name ?? "Custom Mix")
                                .font(StudioTheme.Typography.body(11))
                                .foregroundStyle(.white.opacity(0.52))
                        }

                        Spacer(minLength: 0)
                    }

                    ColorPicker("", selection: $store.brushColor, supportsOpacity: false)
                        .labelsHidden()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(StudioTheme.Palette.hairline)
                        )

                    LazyVGrid(columns: paletteColumns, alignment: .leading, spacing: 8) {
                        ForEach(store.presets) { preset in
                            colorSwatch(color: preset.color, isSelected: store.selectedBrush == preset) {
                                store.send(.selectPreset(preset))
                            }
                        }

                        ForEach(PaletteSwatch.defaults) { swatch in
                            colorSwatch(color: swatch.color, isSelected: false) {
                                store.send(.binding(.set(\.brushColor, swatch.color)))
                            }
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(StudioTheme.Palette.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
                )

            }
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(StudioTheme.Typography.mono(10))
            .foregroundStyle(.white.opacity(0.48))
    }

    private func metricRow(_ title: String, value: String) -> some View {
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

    private func sliderRow<SliderView: View>(title: String, value: String, slider: SliderView) -> some View {
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
            slider
                .tint(StudioTheme.Palette.accentBright)
                .frame(minHeight: 38)
                .contentShape(Rectangle())
        }
    }

    private func colorSwatch(color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.95), lineWidth: 1.5)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.95 : 0.16), lineWidth: isSelected ? 2.5 : 1)
                        .padding(isSelected ? -4 : -2)
                )
        }
        .buttonStyle(.plain)
        .minimumHitTarget()
    }
}

private struct PaletteSwatch: Identifiable {
    let id: String
    let color: Color

    static let defaults: [PaletteSwatch] = [
        PaletteSwatch(id: "graphite", color: Color(red: 0.14, green: 0.15, blue: 0.18)),
        PaletteSwatch(id: "ruby", color: Color(red: 0.77, green: 0.23, blue: 0.26)),
        PaletteSwatch(id: "amber", color: Color(red: 0.89, green: 0.61, blue: 0.18)),
        PaletteSwatch(id: "moss", color: Color(red: 0.34, green: 0.55, blue: 0.29)),
        PaletteSwatch(id: "lagoon", color: Color(red: 0.19, green: 0.55, blue: 0.72)),
        PaletteSwatch(id: "violet", color: Color(red: 0.49, green: 0.37, blue: 0.76)),
        PaletteSwatch(id: "rose", color: Color(red: 0.86, green: 0.46, blue: 0.59))
    ]
}
