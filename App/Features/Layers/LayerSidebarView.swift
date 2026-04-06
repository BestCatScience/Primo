import ComposableArchitecture
import SwiftUI

struct LayerSidebarView: View {
    @Bindable var store: StoreOf<LayerSidebarFeature>
    let layerSnapshots: [MetalLayerSnapshot]
    var language: AppLanguage = .japanese
    var showsTitle = true
    @State var draggedLayerIndex: Int?
    @State var dropTargetLayerIndex: Int?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if showsTitle {
                    Text(StudioStrings.layersTitle(language))
                        .font(StudioTheme.Typography.title(26))
                        .foregroundStyle(.white.opacity(0.94))
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center) {
                        Text(StudioStrings.layers(store.layers.count + 1, language))
                            .font(StudioTheme.Typography.title(18))
                            .foregroundStyle(.white.opacity(0.9))

                        Spacer()

                        Button {
                            store.send(.addLayerButtonTapped)
                        } label: {
                            Label(StudioStrings.addLayer(language), systemImage: "plus")
                                .font(StudioTheme.Typography.label(12))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(StudioTheme.Palette.accent)
                                )
                        }
                        .buttonStyle(.plain)
                        .minimumHitTarget()
                    }

                    if let activeLayer = store.layers.first(where: { $0.index == store.activeLayerIndex }) {
                        activeLayerOpacitySection(activeLayer)
                    }

                    ForEach(store.layers) { layer in
                        layerRow(for: layer)
                    }

                    paperLayerRow
                }
                .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
