import ComposableArchitecture
import SwiftUI

struct BrushPaletteView: View {
    @Bindable var store: StoreOf<BrushPaletteFeature>
    var showsTitle = true

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
            }
            .font(.subheadline.weight(.medium))

            Button("Clear Active Layer") {
                store.send(.clearActiveLayerButtonTapped)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
