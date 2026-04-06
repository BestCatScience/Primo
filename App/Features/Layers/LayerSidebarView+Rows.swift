import SwiftUI
import UniformTypeIdentifiers

extension LayerSidebarView {
    func activeLayerOpacitySection(_ activeLayer: LayerRowModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(language.localized("レイヤー不透明度"))
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

    func layerRow(for layer: LayerRowModel) -> some View {
        let snapshot = layerSnapshots.first(where: { $0.index == layer.index })

        return HStack(spacing: 10) {
            layerDragHandle(for: layer, snapshot: snapshot)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(StudioTheme.Palette.cardFillStrong)
                .frame(width: 40, height: 40)
                .overlay {
                    LayerThumbnailView(snapshot: snapshot)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    if editingLayerIndex == layer.index {
                        TextField("", text: $editingLayerName)
                            .font(StudioTheme.Typography.title(14))
                            .foregroundStyle(.white.opacity(0.96))
                            .textFieldStyle(.plain)
                            .submitLabel(.done)
                            .focused($focusedLayerEditorIndex, equals: layer.index)
                            .onSubmit {
                                commitLayerNameEdit(for: layer.index)
                            }
                            .onAppear {
                                if focusedLayerEditorIndex != layer.index {
                                    DispatchQueue.main.async {
                                        focusedLayerEditorIndex = layer.index
                                    }
                                }
                            }
                    } else {
                        Text(layer.name)
                            .font(StudioTheme.Typography.title(14))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                    }

                    Spacer(minLength: 10)

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
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(StudioTheme.Palette.cardFillStrong)
                            )
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .minimumHitTarget()
                    .fixedSize(horizontal: true, vertical: false)
                }

                HStack(spacing: 8) {
                    Text(StudioStrings.opacityValue(Int(layer.opacity * 100), language))
                        .font(StudioTheme.Typography.mono(10))
                        .foregroundStyle(.white.opacity(0.48))

                    miniActionButton(systemImage: "trash") {
                        store.send(.deleteLayerButtonTapped(layer.index))
                    }
                    .disabled(store.layers.count <= 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                store.send(.visibilityButtonTapped(layer.index))
            } label: {
                Image(systemName: layer.visible ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(layer.visible ? .white.opacity(0.9) : .white.opacity(0.45))
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(StudioTheme.Palette.cardFillStrong)
                    )
            }
            .buttonStyle(.plain)
            .minimumHitTarget()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundFill(for: layer))
        )
        .overlay {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor(for: layer), lineWidth: 1)

                if showsInsertionIndicator(for: layer) {
                    layerInsertionIndicator
                        .offset(y: -7)
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            if editingLayerIndex == layer.index {
                commitLayerNameEdit(for: layer.index)
            } else {
                store.send(.layerTapped(layer.index))
            }
        }
        .onTapGesture(count: 2) {
            startEditingLayer(layer)
        }
        .onDrag {
            draggedLayerIndex = layer.index
            dropTargetLayerIndex = layer.index
            return NSItemProvider(object: NSString(string: "\(layer.index)"))
        } preview: {
            layerRowDragPreview(for: layer, snapshot: snapshot)
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

    var paperLayerRow: some View {
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
                    Text(language.localized("用紙"))
                        .font(StudioTheme.Typography.title(15))
                        .foregroundStyle(.white.opacity(0.92))

                    Spacer(minLength: 0)
                }

                HStack(spacing: 7) {
                    Text(store.transparentPaper ? language.localized("透明") : language.localized("用紙色"))
                        .font(StudioTheme.Typography.mono(10))
                        .foregroundStyle(.white.opacity(0.48))

                    capsuleTag(store.transparentPaper ? language.localized("透明") : language.localized("表示"))
                    capsuleTag(language.localized("最背面"))
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
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
        }
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

    func capsuleTag(_ title: String) -> some View {
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

    func miniActionButton(systemImage: String, action: @escaping () -> Void) -> some View {
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

    func layerRowDragPreview(for layer: LayerRowModel, snapshot: MetalLayerSnapshot?) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(StudioTheme.Palette.cardFillStrong)
                .frame(width: 40, height: 40)
                .overlay {
                    LayerThumbnailView(snapshot: snapshot)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(layer.name)
                    .font(StudioTheme.Typography.title(14))
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(1)

                Text(layer.blendMode.localizedTitle(language))
                    .font(StudioTheme.Typography.mono(9))
                    .foregroundStyle(.white.opacity(0.54))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(width: 240, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(StudioTheme.Palette.overlayBlack.opacity(0.96))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(StudioTheme.Palette.accent.opacity(0.55), lineWidth: 1)
        }
    }

    var layerInsertionIndicator: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(StudioTheme.Palette.accentBright)
                .frame(width: 10, height: 10)

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            StudioTheme.Palette.accentBright.opacity(0.92),
                            StudioTheme.Palette.accent.opacity(0.72)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 5)

            Circle()
                .fill(StudioTheme.Palette.accentBright)
                .frame(width: 10, height: 10)
        }
        .padding(.horizontal, 12)
        .shadow(color: StudioTheme.Palette.accentGlow.opacity(0.42), radius: 10, x: 0, y: 0)
    }

    func layerDragHandle(for layer: LayerRowModel, snapshot: MetalLayerSnapshot?) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.34))
            .frame(width: 14, height: 32)
            .contentShape(Rectangle())
            .onDrag {
                draggedLayerIndex = layer.index
                dropTargetLayerIndex = layer.index
                return NSItemProvider(object: NSString(string: "\(layer.index)"))
            } preview: {
                layerRowDragPreview(for: layer, snapshot: snapshot)
            }
    }

    func showsInsertionIndicator(for layer: LayerRowModel) -> Bool {
        dropTargetLayerIndex == layer.index && draggedLayerIndex != layer.index
    }

    func backgroundFill(for layer: LayerRowModel) -> Color {
        if showsInsertionIndicator(for: layer) {
            return StudioTheme.Palette.accent.opacity(0.10)
        }
        return store.activeLayerIndex == layer.index ? StudioTheme.Palette.selectedFill : StudioTheme.Palette.cardFill
    }

    func borderColor(for layer: LayerRowModel) -> Color {
        if showsInsertionIndicator(for: layer) {
            return StudioTheme.Palette.accent.opacity(0.55)
        }
        return store.activeLayerIndex == layer.index ? StudioTheme.Palette.selectedBorder : StudioTheme.Palette.cardBorder
    }

    func startEditingLayer(_ layer: LayerRowModel) {
        editingLayerIndex = layer.index
        editingLayerName = layer.name
        focusedLayerEditorIndex = layer.index
    }

    func commitLayerNameEdit(for index: Int) {
        guard editingLayerIndex == index else { return }
        let trimmed = editingLayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentName = store.layers.first(where: { $0.index == index })?.name ?? ""
        if !trimmed.isEmpty && trimmed != currentName {
            store.send(.renameLayerCommitted(index, trimmed))
        }
        editingLayerIndex = nil
        focusedLayerEditorIndex = nil
    }
}
