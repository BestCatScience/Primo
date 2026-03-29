import ComposableArchitecture
import SwiftUI

struct BrushPaletteView: View {
    @Bindable var store: StoreOf<BrushPaletteFeature>
    var showsTitle = true
    private let paletteColumns = Array(repeating: GridItem(.fixed(24), spacing: 10), count: 5)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if showsTitle {
                    Text("Brush")
                        .font(StudioTheme.Typography.title(30))
                        .foregroundStyle(.white.opacity(0.94))
                }

                VStack(alignment: .leading, spacing: 14) {
                    sectionLabel("Brush Engine")

                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                            .frame(width: 82, height: 82)
                            .overlay(
                                Circle()
                                    .fill(StudioTheme.Palette.textPrimary)
                                    .frame(width: max(12, store.brushRadius * 4), height: max(12, store.brushRadius * 4))
                            )

                        VStack(alignment: .leading, spacing: 8) {
                            metricRow("Radius", value: "\(Int(store.brushRadius)) px")
                            metricRow("Opacity", value: "\(Int(store.brushOpacity * 100))%")
                            metricRow("Hardness", value: "\(Int(store.brushHardness * 100))%")
                            metricRow("Pressure", value: store.brushPressureSensitivity < 0.6 ? "Soft" : store.brushPressureSensitivity > 1.2 ? "Hard" : "Medium")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("Preset Library")

                    ForEach(store.presets) { preset in
                        Button {
                            store.send(.selectPreset(preset))
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 18, height: 18)
                                Text(preset.name)
                                    .font(StudioTheme.Typography.title(15))
                                Spacer()
                                if store.selectedBrush == preset {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(StudioTheme.Palette.accentBright)
                                }
                            }
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(store.selectedBrush == preset ? StudioTheme.Palette.selectedFill : StudioTheme.Palette.cardFill)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    sliderRow(title: "Size", value: "\(Int(store.brushRadius))", slider: Slider(value: $store.brushRadius, in: 1...18))
                    sliderRow(title: "Opacity", value: "\(Int(store.brushOpacity * 100))%", slider: Slider(value: $store.brushOpacity, in: 0.1...1.0))
                    sliderRow(title: "Hardness", value: "\(Int(store.brushHardness * 100))%", slider: Slider(value: $store.brushHardness, in: 0.2...0.98))
                    sliderRow(title: "Pressure", value: store.brushPressureSensitivity < 0.6 ? "Soft" : store.brushPressureSensitivity > 1.2 ? "Hard" : "Medium", slider: Slider(value: $store.brushPressureSensitivity, in: 0.1...2.0))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(StudioTheme.Palette.cardFill)
                )

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
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

                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(store.brushColor)
                                .padding(5)
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Color Palette")
                                .font(StudioTheme.Typography.title(15))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(store.selectedBrush?.name ?? "Custom Mix")
                                .font(StudioTheme.Typography.body(12))
                                .foregroundStyle(.white.opacity(0.52))
                        }

                        Spacer(minLength: 0)
                    }

                    ColorPicker("", selection: $store.brushColor, supportsOpacity: false)
                        .labelsHidden()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(StudioTheme.Palette.hairline)
                        )

                    LazyVGrid(columns: paletteColumns, alignment: .leading, spacing: 10) {
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
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(StudioTheme.Palette.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
                )

                Button("Clear Active Layer") {
                    store.send(.clearActiveLayerButtonTapped)
                }
                .buttonStyle(.plain)
                .font(StudioTheme.Typography.label(13))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(StudioTheme.Palette.accent)
                )
            }
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(StudioTheme.Typography.mono(11))
            .foregroundStyle(.white.opacity(0.48))
    }

    private func metricRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(StudioTheme.Typography.mono(11))
                .foregroundStyle(.white.opacity(0.48))
            Spacer()
            Text(value)
                .font(StudioTheme.Typography.title(13))
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
                    .font(StudioTheme.Typography.mono(11))
                    .foregroundStyle(.white.opacity(0.5))
            }
            slider
                .tint(StudioTheme.Palette.accentBright)
        }
    }

    private func colorSwatch(color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
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
