import ComposableArchitecture
import SwiftUI

struct BrushPaletteView: View {
    @Bindable var store: StoreOf<BrushPaletteFeature>
    var showsTitle = true
    private let paletteColumns = Array(repeating: GridItem(.fixed(24), spacing: 10), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showsTitle {
                Text("Brush")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Preset")
                    .font(.headline)

                ForEach(store.presets) { preset in
                    Button {
                        store.send(.selectPreset(preset))
                    } label: {
                        HStack {
                            Circle()
                                .fill(preset.color)
                                .frame(width: 16, height: 16)
                            Text(preset.name)
                            Spacer()
                            if store.selectedBrush == preset {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(store.selectedBrush == preset ? Color.black.opacity(0.08) : Color.black.opacity(0.03))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Group {
                Text("Size \(Int(store.brushRadius))")
                Slider(value: $store.brushRadius, in: 1...18)

                Text("Opacity \(Int(store.brushOpacity * 100))%")
                Slider(value: $store.brushOpacity, in: 0.1...1.0)

                Text("Hardness \(Int(store.brushHardness * 100))%")
                Slider(value: $store.brushHardness, in: 0.2...0.98)

                Text("Pressure \(store.brushPressureSensitivity < 0.6 ? "Soft" : store.brushPressureSensitivity > 1.2 ? "Hard" : "Medium")")
                Slider(value: $store.brushPressureSensitivity, in: 0.1...2.0)
            }
            .font(.subheadline.weight(.medium))

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
                        Text(store.selectedBrush?.name ?? "Custom Mix")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.black.opacity(0.62))
                    }

                    Spacer(minLength: 0)
                }

                ColorPicker("自由に色を選択", selection: $store.brushColor, supportsOpacity: false)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .labelsHidden()
                    .overlay(alignment: .leading) {
                        Text("自由に色を選択")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.82))
                            .allowsHitTesting(false)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.6))
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
                    .fill(Color.white.opacity(0.34))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )

            Button("Clear Active Layer") {
                store.send(.clearActiveLayerButtonTapped)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                        .stroke(Color.black.opacity(isSelected ? 0.85 : 0.14), lineWidth: isSelected ? 2.5 : 1)
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
