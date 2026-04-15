import SwiftUI

extension LayerSidebarView {
    func activeLayerOpacitySection(_ activeLayer: LayerRowModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                layerStatusButton(
                    systemImage: "arrow.down.to.line",
                    isActive: false,
                    accessibilityLabel: language.localized("下のレイヤーと結合")
                ) {
                    store.send(.mergeDownButtonTapped(activeLayer.index))
                }
                .disabled(activeLayer.index <= 0)

                layerStatusButton(
                    systemImage: activeLayer.isAlphaLocked ? "a.square.fill" : "a.square",
                    isActive: activeLayer.isAlphaLocked,
                    accessibilityLabel: language.localized("アルファロック")
                ) {
                    store.send(.alphaLockButtonTapped(activeLayer.index))
                }

                layerStatusButton(
                    systemImage: "arrow.turn.down.right",
                    rotationDegrees: 90,
                    isActive: activeLayer.isClipped,
                    accessibilityLabel: language.localized("Clipping Mask")
                ) {
                    store.send(.clippingMaskButtonTapped(activeLayer.index))
                }
                .disabled(activeLayer.index <= 0 && !activeLayer.isClipped)

                layerStatusButton(
                    systemImage: activeLayer.isLocked ? "lock.fill" : "lock.open",
                    isActive: activeLayer.isLocked,
                    accessibilityLabel: language.localized("レイヤーロック")
                ) {
                    store.send(.layerLockButtonTapped(activeLayer.index))
                }

                layerStatusButton(
                    systemImage: "plus.square.on.square",
                    isActive: false,
                    accessibilityLabel: language.localized("Duplicate Layer")
                ) {
                    store.send(.duplicateLayerButtonTapped(activeLayer.index))
                }

                layerStatusButton(
                    systemImage: "trash",
                    isActive: false,
                    accessibilityLabel: language.localized("アクティブレイヤーを削除")
                ) {
                    store.send(.deleteLayerButtonTapped(activeLayer.index))
                }
                .disabled(store.layers.count <= 1)

                Spacer(minLength: 0)
            }

            HStack {
                Text(language.localized("レイヤー不透明度"))
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(StudioTheme.Palette.textMuted)
                Spacer(minLength: 0)
                Text("\(Int(activeLayer.opacity * 100))%")
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(StudioTheme.Palette.textSecondary)
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

    func layerStatusButton(
        systemImage: String,
        rotationDegrees: Double = 0,
        isActive: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .rotationEffect(.degrees(rotationDegrees))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? .white : StudioTheme.Palette.textSecondary)
                .frame(width: 30, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? StudioTheme.Palette.accent.opacity(0.82) : StudioTheme.Palette.cardFillStrong)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isActive ? StudioTheme.Palette.accentBright.opacity(0.78) : StudioTheme.Palette.cardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .minimumHitTarget()
        .accessibilityLabel(accessibilityLabel)
    }

    func folderRow(for folder: LayerFolderModel) -> some View {
        HStack(spacing: 10) {
            Button {
                store.send(.folderTapped(folder.id))
            } label: {
                Image(systemName: folder.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.52))
                    .frame(width: 14, height: 24)
            }
            .buttonStyle(.plain)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(StudioTheme.Palette.cardFillStrong)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: folder.isExpanded ? "folder.fill" : "folder")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(folder.visible ? StudioTheme.Palette.warning : .white.opacity(0.34))
                }

            VStack(alignment: .leading, spacing: 4) {
                if editingFolderID == folder.id {
                    TextField("", text: $editingFolderName)
                        .font(StudioTheme.Typography.title(14))
                        .foregroundStyle(.white.opacity(0.96))
                        .textFieldStyle(.plain)
                        .submitLabel(.done)
                        .focused($focusedEditorTarget, equals: .folder(folder.id))
                        .onSubmit {
                            commitFolderNameEdit(for: folder.id)
                        }
                } else {
                    Text(folder.name)
                        .font(StudioTheme.Typography.title(14))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                }

                Text(StudioStrings.layers(folder.childLayerIndices.count, language))
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(.white.opacity(0.46))
            }

            Spacer(minLength: 0)

            Button {
                store.send(.folderVisibilityButtonTapped(folder.id))
            } label: {
                Image(systemName: folder.visible ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(folder.visible ? .white.opacity(0.9) : .white.opacity(0.45))
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(StudioTheme.Palette.cardFillStrong)
                    )
            }
            .buttonStyle(.plain)
            .minimumHitTarget()

            miniActionButton(systemImage: "trash") {
                store.send(.deleteFolderButtonTapped(folder.id))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(folderBackgroundFill(for: folder))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(folderBorderColor(for: folder), lineWidth: folderStrokeWidth(for: folder))
        }
        .shadow(color: folderShadowColor(for: folder), radius: dropTargetFolderID == folder.id ? 12 : 0, x: 0, y: 0)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: LayerSidebarDragTargetPreferenceKey.self,
                    value: [.folder(folder.id): proxy.frame(in: .global)]
                )
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            isDraggingLayer = false
            draggedLayerIndex = nil
            dropTargetLayerIndex = nil
            dropTargetFolderID = nil
            if editingFolderID == folder.id {
                commitFolderNameEdit(for: folder.id)
            } else {
                store.send(.folderTapped(folder.id))
            }
        }
        .onTapGesture(count: 2) {
            startEditingFolder(folder)
        }
    }

    func layerRow(for layer: LayerRowModel, depth: Int = 0) -> some View {
        let snapshot = layerSnapshots.first(where: { $0.index == layer.index })
        let childIndent = CGFloat(depth) * 28

        return HStack(spacing: 10) {
            layerDragHandle(for: layer, snapshot: snapshot)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(StudioTheme.Palette.cardFillStrong)
                .frame(width: 34, height: 34)
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
                            .focused($focusedEditorTarget, equals: .layer(layer.index))
                            .onSubmit {
                                commitLayerNameEdit(for: layer.index)
                            }
                    } else {
                        Text(layer.name)
                            .font(StudioTheme.Typography.title(14))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                    }

                    if layer.hasMask {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(StudioTheme.Palette.accentBright)
                    }

                    if layer.isClipped {
                        Image(systemName: "arrow.turn.down.right")
                            .rotationEffect(.degrees(90))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(StudioTheme.Palette.warning)
                    }

                    if layer.isTextLayer {
                        Image(systemName: "textformat")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(StudioTheme.Palette.warning)
                    }

                    Spacer(minLength: 10)

                    Menu {
                        Button {
                            store.send(.clippingMaskButtonTapped(layer.index))
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.turn.down.right")
                                    .rotationEffect(.degrees(90))
                                Text(language.localized("Clipping Mask"))
                            }
                        }

                        Divider()

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

                if layer.folderID != nil {
                    HStack(spacing: 8) {
                        miniActionButton(systemImage: "arrow.uturn.left") {
                            store.send(.removeLayerFromFolderButtonTapped(layer.index))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                store.send(.visibilityButtonTapped(layer.index))
            } label: {
                Image(systemName: layer.visible ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(layer.visible ? .white.opacity(0.9) : .white.opacity(0.45))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(StudioTheme.Palette.cardFillStrong)
                    )
            }
            .buttonStyle(.plain)
            .minimumHitTarget()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .padding(.leading, childIndent)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundFill(for: layer))
        )
        .shadow(color: dragShadowColor(for: layer), radius: isDraggedLayer(layer) ? 12 : 0, x: 0, y: 0)
        .scaleEffect(isDraggedLayer(layer) ? (dragAnimationPhase ? 1.024 : 1.012) : 1.0)
        .offset(y: isDraggedLayer(layer) ? (dragAnimationPhase ? -1.5 : -3.5) : 0)
        .animation(.easeInOut(duration: 0.12), value: draggedLayerIndex)
        .animation(.easeInOut(duration: 0.12), value: dropTargetLayerIndex)
        .animation(.easeInOut(duration: 0.12), value: dropTargetFolderID)
        .overlay {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor(for: layer), lineWidth: borderWidth(for: layer))

                if depth > 0 {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(StudioTheme.Palette.accent.opacity(0.3))
                        .frame(width: 3, height: 26)
                        .offset(x: 12, y: 12)
                }

                if showsInsertionIndicator(for: layer) {
                    layerInsertionIndicator
                        .offset(y: -7)
                }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: LayerSidebarDragTargetPreferenceKey.self,
                    value: [.layer(layer.index): proxy.frame(in: .global)]
                )
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            isDraggingLayer = false
            draggedLayerIndex = nil
            dropTargetLayerIndex = nil
            dropTargetFolderID = nil
            if editingLayerIndex == layer.index {
                commitLayerNameEdit(for: layer.index)
            } else {
                store.send(.layerTapped(layer.index))
            }
        }
        .onTapGesture(count: 2) {
            startEditingLayer(layer)
        }
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
            isDraggingLayer = false
            draggedLayerIndex = nil
            dropTargetLayerIndex = nil
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
        .onDisappear {
            isDraggingLayer = false
            draggedLayerIndex = nil
            dropTargetLayerIndex = nil
            dropTargetFolderID = nil
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
            .foregroundStyle(isDraggedLayer(layer) ? StudioTheme.Palette.accentBright : .white.opacity(0.34))
            .frame(width: 24, height: 36)
            .scaleEffect(isDraggedLayer(layer) ? (dragAnimationPhase ? 1.14 : 1.04) : 1.0)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        handleLayerDragChanged(for: layer, at: value.location)
                    }
                    .onEnded { value in
                        finishLayerDrag(at: value.location)
                    }
            )
    }

    func showsInsertionIndicator(for layer: LayerRowModel) -> Bool {
        dropTargetLayerIndex == layer.index && draggedLayerIndex != layer.index
    }

    func isDraggedLayer(_ layer: LayerRowModel) -> Bool {
        isDraggingLayer && draggedLayerIndex == layer.index
    }

    func backgroundFill(for layer: LayerRowModel) -> Color {
        if isDraggedLayer(layer) {
            return StudioTheme.Palette.accent.opacity(0.18)
        }
        if showsInsertionIndicator(for: layer) {
            return StudioTheme.Palette.accent.opacity(0.10)
        }
        return store.activeLayerIndex == layer.index ? StudioTheme.Palette.selectedFill : StudioTheme.Palette.cardFill
    }

    func borderColor(for layer: LayerRowModel) -> Color {
        if isDraggedLayer(layer) {
            return StudioTheme.Palette.accentBright.opacity(0.92)
        }
        if showsInsertionIndicator(for: layer) {
            return StudioTheme.Palette.accent.opacity(0.55)
        }
        return store.activeLayerIndex == layer.index ? StudioTheme.Palette.selectedBorder : StudioTheme.Palette.cardBorder
    }

    func borderWidth(for layer: LayerRowModel) -> CGFloat {
        isDraggedLayer(layer) ? 1.4 : 1
    }

    func dragShadowColor(for layer: LayerRowModel) -> Color {
        isDraggedLayer(layer) ? StudioTheme.Palette.accentGlow.opacity(0.34) : .clear
    }

    func folderBackgroundFill(for folder: LayerFolderModel) -> Color {
        dropTargetFolderID == folder.id ? StudioTheme.Palette.accent.opacity(0.10) : StudioTheme.Palette.cardFill
    }

    func folderBorderColor(for folder: LayerFolderModel) -> Color {
        dropTargetFolderID == folder.id ? StudioTheme.Palette.accentBright.opacity(0.82) : StudioTheme.Palette.cardBorder
    }

    func folderStrokeWidth(for folder: LayerFolderModel) -> CGFloat {
        dropTargetFolderID == folder.id ? 1.4 : 1
    }

    func folderShadowColor(for folder: LayerFolderModel) -> Color {
        dropTargetFolderID == folder.id ? StudioTheme.Palette.accentGlow.opacity(0.26) : .clear
    }

    func startEditingLayer(_ layer: LayerRowModel) {
        editingFolderID = nil
        editingLayerIndex = layer.index
        editingLayerName = layer.name
        focusedEditorTarget = .layer(layer.index)
    }

    func startEditingFolder(_ folder: LayerFolderModel) {
        editingLayerIndex = nil
        editingFolderID = folder.id
        editingFolderName = folder.name
        focusedEditorTarget = .folder(folder.id)
    }

    func commitLayerNameEdit(for index: Int) {
        guard editingLayerIndex == index else { return }
        let trimmed = editingLayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentName = store.layers.first(where: { $0.index == index })?.name ?? ""
        if !trimmed.isEmpty && trimmed != currentName {
            store.send(.renameLayerCommitted(index, trimmed))
        }
        editingLayerIndex = nil
        if editingFolderID == nil {
            focusedEditorTarget = nil
        }
    }

    func commitFolderNameEdit(for folderID: Int) {
        guard editingFolderID == folderID else { return }
        let trimmed = editingFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentName = store.rows.compactMap { row -> LayerFolderModel? in
            if case let .folder(folder) = row, folder.id == folderID {
                return folder
            }
            return nil
        }.first?.name ?? ""
        if !trimmed.isEmpty && trimmed != currentName {
            store.send(.renameFolderCommitted(folderID, trimmed))
        }
        editingFolderID = nil
        if editingLayerIndex == nil {
            focusedEditorTarget = nil
        }
    }

    func commitCurrentNameEdit() {
        if let editingLayerIndex {
            commitLayerNameEdit(for: editingLayerIndex)
        }
        if let editingFolderID {
            commitFolderNameEdit(for: editingFolderID)
        }
    }

    func handleLayerDragChanged(for layer: LayerRowModel, at location: CGPoint) {
        if !isDraggingLayer {
            isDraggingLayer = true
            draggedLayerIndex = layer.index
            dropTargetLayerIndex = layer.index
            dropTargetFolderID = nil
        }

        guard let draggedLayerIndex else { return }

        if let destinationIndex = layerIndex(at: location) {
            dropTargetFolderID = nil
            guard destinationIndex != draggedLayerIndex else { return }
            guard dropTargetLayerIndex != destinationIndex else { return }
            dropTargetLayerIndex = destinationIndex
            store.send(.moveLayerRequested(draggedLayerIndex, destinationIndex))
            self.draggedLayerIndex = destinationIndex
            return
        }

        if let folderID = folderID(at: location) {
            dropTargetLayerIndex = nil
            dropTargetFolderID = folderID
        }
    }

    func finishLayerDrag(at location: CGPoint) {
        defer {
            isDraggingLayer = false
            draggedLayerIndex = nil
            dropTargetLayerIndex = nil
            dropTargetFolderID = nil
        }

        guard let draggedLayerIndex else { return }
        guard let folderID = folderID(at: location) else { return }
        store.send(.moveLayerToFolderRequested(draggedLayerIndex, folderID))
    }

    func layerIndex(at location: CGPoint) -> Int? {
        dragTargetFrames
            .compactMap { target, frame -> (Int, CGRect)? in
                guard case let .layer(index) = target else { return nil }
                return (index, frame)
            }
            .first(where: { $0.1.contains(location) })?
            .0
    }

    func folderID(at location: CGPoint) -> Int? {
        dragTargetFrames
            .compactMap { target, frame -> (Int, CGRect)? in
                guard case let .folder(id) = target else { return nil }
                return (id, frame)
            }
            .first(where: { $0.1.contains(location) })?
            .0
    }
}
