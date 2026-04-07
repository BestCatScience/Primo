import ComposableArchitecture
import SwiftUI

struct LayerSidebarView: View {
    enum EditTarget: Hashable {
        case layer(Int)
        case folder(Int)
    }

    enum DragTarget: Hashable {
        case layer(Int)
        case folder(Int)
    }

    @Bindable var store: StoreOf<LayerSidebarFeature>
    let layerSnapshots: [MetalLayerSnapshot]
    var language: AppLanguage = .japanese
    var showsTitle = true
    @State var isDraggingLayer = false
    @State var draggedLayerIndex: Int?
    @State var dropTargetLayerIndex: Int?
    @State var editingLayerIndex: Int?
    @State var editingLayerName = ""
    @State var editingFolderID: Int?
    @State var editingFolderName = ""
    @State var dragTargetFrames: [DragTarget: CGRect] = [:]
    @FocusState var focusedEditorTarget: EditTarget?

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
                            store.send(.addFolderButtonTapped)
                        } label: {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(StudioTheme.Palette.cardFillStrong)
                                )
                        }
                        .buttonStyle(.plain)
                        .minimumHitTarget()

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

                    ForEach(store.rows) { row in
                        switch row {
                        case let .folder(folder):
                            folderRow(for: folder)
                        case let .layer(layer, depth):
                            layerRow(for: layer, depth: depth)
                        }
                    }

                    paperLayerRow
                }
                .padding(.bottom, 10)
            }
        }
        .coordinateSpace(name: "layerSidebarGlobal")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onPreferenceChange(LayerSidebarDragTargetPreferenceKey.self) { dragTargetFrames = $0 }
        .onChange(of: editingLayerIndex) { _, newValue in
            guard let newValue else {
                if editingFolderID == nil {
                    focusedEditorTarget = nil
                }
                return
            }
            DispatchQueue.main.async {
                focusedEditorTarget = .layer(newValue)
            }
        }
        .onChange(of: editingFolderID) { _, newValue in
            guard let newValue else {
                if editingLayerIndex == nil {
                    focusedEditorTarget = nil
                }
                return
            }
            DispatchQueue.main.async {
                focusedEditorTarget = .folder(newValue)
            }
        }
        .onChange(of: store.layers) { _, newLayers in
            guard let draggedLayerIndex else { return }
            guard !newLayers.contains(where: { $0.index == draggedLayerIndex }) else { return }
            isDraggingLayer = false
            self.draggedLayerIndex = nil
            dropTargetLayerIndex = nil
        }
    }

}
