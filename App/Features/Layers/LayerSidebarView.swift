import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct LayerSidebarView: View {
    @Bindable var store: StoreOf<LayerSidebarFeature>
    let layerSnapshots: [MetalLayerSnapshot]
    var language: AppLanguage = .japanese
    var showsTitle = true
    @State private var draggedLayerIndex: Int?
    @State private var dropTargetLayerIndex: Int?

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
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(language.localized("Layer Opacity"))
                                    .font(StudioTheme.Typography.mono(10))
                                    .foregroundStyle(.white.opacity(0.56))
                                Spacer(minLength: 0)
                                Text("\(Int(activeLayer.opacity * 100))%")
                                    .font(StudioTheme.Typography.mono(10))
                                    .foregroundStyle(.white.opacity(0.72))
                            }

                            Slider(
                                value: Binding(
                                    get: { activeLayer.opacity },
                                    set: { store.send(.opacityChanged(activeLayer.index, $0)) }
                                ),
                                in: 0.0...1.0
                            )
                            .tint(StudioTheme.Palette.accentBright)
                        }
                        .padding(.horizontal, 2)
                    }

                    ForEach(store.layers) { layer in
                        let snapshot = layerSnapshots.first(where: { $0.index == layer.index })
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(StudioTheme.Palette.cardFillStrong)
                                .frame(width: 48, height: 48)
                                .overlay {
                                    LayerThumbnailView(
                                        snapshot: snapshot
                                    )
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }

                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    Text(layer.name)
                                        .font(StudioTheme.Typography.title(15))
                                        .foregroundStyle(.white.opacity(0.92))

                                    Menu {
                                        ForEach(LayerBlendMode.allCases) { blendMode in
                                            Button {
                                                store.send(.blendModeSelected(layer.index, blendMode))
                                            } label: {
                                                if blendMode == layer.blendMode {
                                                    Label(blendMode.localizedTitle(language), systemImage: "checkmark")
                                                } else {
                                                    Text(blendMode.localizedTitle(language))
                                                }
                                            }
                                        }
                                    } label: {
                                        Text(layer.blendMode.localizedTitle(language))
                                            .font(StudioTheme.Typography.mono(9))
                                            .foregroundStyle(.white.opacity(0.9))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .background(
                                                Capsule(style: .continuous)
                                                    .fill(StudioTheme.Palette.cardFillStrong)
                                            )
                                    }
                                    .menuStyle(.button)
                                    .buttonStyle(.plain)
                                    .minimumHitTarget()

                                    Spacer(minLength: 0)
                                }

                                HStack(spacing: 7) {
                                    Text(StudioStrings.opacityValue(Int(layer.opacity * 100), language))
                                        .font(StudioTheme.Typography.mono(10))
                                        .foregroundStyle(.white.opacity(0.48))
                                }

                                HStack(spacing: 6) {
                                    miniActionButton(systemImage: "trash") {
                                        store.send(.deleteLayerButtonTapped(layer.index))
                                    }
                                    .disabled(store.layers.count <= 1)
                                }
                            }

                            Spacer()

                            Button {
                                store.send(.visibilityButtonTapped(layer.index))
                            } label: {
                                Image(systemName: layer.visible ? "eye.fill" : "eye.slash.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(layer.visible ? .white.opacity(0.9) : .white.opacity(0.45))
                                    .frame(width: 30, height: 30)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(StudioTheme.Palette.cardFillStrong)
                                    )
                            }
                            .buttonStyle(.plain)
                            .minimumHitTarget()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(backgroundFill(for: layer))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(borderColor(for: layer), lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .onTapGesture {
                            store.send(.layerTapped(layer.index))
                        }
                        .onDrag {
                            draggedLayerIndex = layer.index
                            return NSItemProvider(object: NSString(string: "\(layer.index)"))
                        }
                        .onDrop(
                            of: [UTType.plainText.identifier],
                            delegate: LayerReorderDropDelegate(
                                targetLayerIndex: layer.index,
                                draggedLayerIndex: $draggedLayerIndex,
                                dropTargetLayerIndex: $dropTargetLayerIndex
                            ) { sourceIndex, destinationIndex in
                                store.send(.moveLayerRequested(sourceIndex, destinationIndex))
                            }
                        )
                    }

                    paperLayerRow
                }
                .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var paperLayerRow: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(store.transparentPaper ? StudioTheme.Palette.cardFillStrong : store.paperColor)
                .frame(width: 48, height: 48)
                .overlay {
                    ZStack {
                        if store.transparentPaper {
                            Image(systemName: "square.dashed")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white.opacity(0.72))
                        } else {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        }
                    }
                }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(language.localized("Paper"))
                        .font(StudioTheme.Typography.title(15))
                        .foregroundStyle(.white.opacity(0.92))

                    Spacer(minLength: 0)
                }

                HStack(spacing: 7) {
                    Text(store.transparentPaper ? (language.localized("Transparent")) : (language.localized("Paper Color")))
                        .font(StudioTheme.Typography.mono(10))
                        .foregroundStyle(.white.opacity(0.48))

                    capsuleTag(store.transparentPaper ? (language.localized("Transparent")) : (language.localized("Visible")))
                    capsuleTag(language.localized("Backmost"))
                }
            }

            Spacer()

            Button {
                store.send(.binding(.set(\.transparentPaper, !store.transparentPaper)))
            } label: {
                Image(systemName: store.transparentPaper ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(store.transparentPaper ? .white.opacity(0.45) : .white.opacity(0.9))
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(StudioTheme.Palette.cardFillStrong)
                    )
            }
            .buttonStyle(.plain)
            .minimumHitTarget()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(StudioTheme.Palette.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            store.send(.paperRowTapped)
        }
        .popover(
            isPresented: Binding(
                get: { store.showsPaperEditor },
                set: { newValue in
                    if !newValue {
                        store.send(.paperEditorDismissed)
                    }
                }
            ),
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .trailing
        ) {
            PaperLayerEditor(
                paperColor: $store.paperColor,
                transparentPaper: $store.transparentPaper,
                language: language
            )
            .presentationCompactAdaptation(.popover)
        }
    }

    private func capsuleTag(_ title: String) -> some View {
        Text(title)
            .font(StudioTheme.Typography.mono(9))
            .foregroundStyle(.white.opacity(0.56))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(StudioTheme.Palette.cardFillStrong)
            )
    }

    private func miniActionButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.84))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(StudioTheme.Palette.cardFillStrong)
                )
        }
        .buttonStyle(.plain)
        .minimumHitTarget()
    }

    private func backgroundFill(for layer: LayerRowModel) -> Color {
        if dropTargetLayerIndex == layer.index {
            return StudioTheme.Palette.accent.opacity(0.18)
        }
        return store.activeLayerIndex == layer.index ? StudioTheme.Palette.selectedFill : StudioTheme.Palette.cardFill
    }

    private func borderColor(for layer: LayerRowModel) -> Color {
        if dropTargetLayerIndex == layer.index {
            return StudioTheme.Palette.accentBright
        }
        return store.activeLayerIndex == layer.index ? StudioTheme.Palette.selectedBorder : StudioTheme.Palette.cardBorder
    }
}

private struct LayerThumbnailView: View {
    let snapshot: MetalLayerSnapshot?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.95, green: 0.94, blue: 0.90))

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)

            if let thumbnail = thumbnailImage {
                Image(uiImage: thumbnail)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFit()
                    .padding(3)
            }
        }
    }

    private var thumbnailImage: UIImage? {
        guard let data = snapshot?.thumbnailData else { return nil }
        return UIImage(data: data)
    }
}

private struct PaperLayerEditor: View {
    @Binding var paperColor: Color
    @Binding var transparentPaper: Bool
    let language: AppLanguage

    private let swatches: [Color] = [
        Color(red: 0.93, green: 0.93, blue: 0.91),
        Color(red: 0.98, green: 0.97, blue: 0.93),
        Color(red: 0.90, green: 0.88, blue: 0.82),
        Color(red: 0.84, green: 0.89, blue: 0.95),
        Color(red: 0.95, green: 0.86, blue: 0.86),
        Color(red: 0.86, green: 0.92, blue: 0.84)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.localized("Paper"))
                .font(StudioTheme.Typography.title(18))
                .foregroundStyle(.white.opacity(0.94))

            Toggle(isOn: $transparentPaper) {
                Text(language.localized("Transparent Paper"))
                    .font(StudioTheme.Typography.title(12))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .tint(StudioTheme.Palette.accentBright)

            ColorPicker(
                language.localized("Paper Color"),
                selection: $paperColor,
                supportsOpacity: false
            )
            .disabled(transparentPaper)
            .opacity(transparentPaper ? 0.45 : 1.0)
            .font(StudioTheme.Typography.label(12))
            .foregroundStyle(.white.opacity(0.88))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 28), spacing: 8)], spacing: 8) {
                ForEach(Array(swatches.enumerated()), id: \.offset) { entry in
                    let color = entry.element
                    Button {
                        paperColor = color
                        transparentPaper = false
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.75), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .disabled(transparentPaper)
            .opacity(transparentPaper ? 0.45 : 1.0)
        }
        .padding(16)
        .frame(width: 260, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(StudioTheme.Palette.overlayBlack.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
        )
    }
}

private struct LayerReorderDropDelegate: DropDelegate {
    let targetLayerIndex: Int
    @Binding var draggedLayerIndex: Int?
    @Binding var dropTargetLayerIndex: Int?
    let moveAction: (Int, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedLayerIndex, draggedLayerIndex != targetLayerIndex else { return }
        dropTargetLayerIndex = targetLayerIndex
        moveAction(draggedLayerIndex, targetLayerIndex)
        self.draggedLayerIndex = targetLayerIndex
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedLayerIndex = nil
        dropTargetLayerIndex = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if dropTargetLayerIndex == targetLayerIndex {
            dropTargetLayerIndex = nil
        }
    }
}
