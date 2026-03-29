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
                        .font(.system(size: 28, weight: .bold, design: .rounded))
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
                                    .fill(Color.white.opacity(0.92))
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
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                    Text("Studio preset")
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.45))
                                }
                                Spacer()
                                if store.selectedBrush == preset {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(red: 0.98, green: 0.70, blue: 0.33))
                                }
                            }
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(store.selectedBrush == preset ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
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
                        .fill(Color.white.opacity(0.04))
                )

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.92),
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
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(store.selectedBrush?.name ?? "Custom Mix")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.52))
                        }

                        Spacer(minLength: 0)
                    }

                    ColorPicker("自由に色を選択", selection: $store.brushColor, supportsOpacity: false)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .labelsHidden()
                        .overlay(alignment: .leading) {
                            Text("自由に色を選択")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.82))
                                .allowsHitTesting(false)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.08))
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
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

                Button("Clear Active Layer") {
                    store.send(.clearActiveLayerButtonTapped)
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color(red: 0.89, green: 0.45, blue: 0.24))
                )
            }
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .foregroundStyle(.white.opacity(0.48))
    }

    private func metricRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.48))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    private func sliderRow<SliderView: View>(title: String, value: String, slider: SliderView) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            slider
                .tint(Color(red: 0.96, green: 0.62, blue: 0.31))
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
