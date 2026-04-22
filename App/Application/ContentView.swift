import ComposableArchitecture
import Foundation
import PhotosUI
import PrimoDocumentContracts
import PrimoDocumentDomain
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    enum NanoBananaFocusedField: Hashable {
        case prompt
        case apiKey
    }

    let store: StoreOf<AppFeature>
    private let studioUIScale: CGFloat = 0.56
    @State var showsOpenDocumentImporter = false
    @State var showsPhotoLayerImporter = false
    @State var showsNewCanvasPhotoImporter = false
    @State var showsNewCanvasSheet = false
    @State var showsResizeCanvasSheet = false
    @State var showsResizeCanvasExtentSheet = false
    @State var showsHSBSheet = false
    @State var showsBrightnessContrastSheet = false
    @State var showsLevelsSheet = false
    @State var showsToneCurveSheet = false
    @State var showsColorBalanceSheet = false
    @State var showsThresholdSheet = false
    @State var showsPosterizeSheet = false
    @State var showsGradientMapSheet = false
    @State var showsExpandSelectionSheet = false
    @State var showsContractSelectionSheet = false
    @State var showsFeatherSelectionSheet = false
    @State var showsColorRangeSelectionSheet = false
    @State var showsTransformNumericSheet = false
    @State var newCanvasWidthText = ""
    @State var newCanvasHeightText = ""
    @State var resizeCanvasWidthText = ""
    @State var resizeCanvasHeightText = ""
    @State var resizeCanvasExtentWidthText = ""
    @State var resizeCanvasExtentHeightText = ""
    @State var gradientMapSettings = GradientMapSettings()
    @State var selectedGradientStopID: GradientMapStopSettings.ID?
    @State var hsbAdjustmentSettings = HueSaturationBrightnessSettings()
    @State var brightnessContrastSettings = BrightnessContrastSettings()
    @State var levelsAdjustmentSettings = LevelsAdjustmentSettings()
    @State var toneCurveSettings = ToneCurveSettings()
    @State var colorBalanceSettings = ColorBalanceSettings()
    @State var thresholdSettings = ThresholdSettings()
    @State var posterizeSettings = PosterizeSettings()
    @State var selectionExpansionText = "4"
    @State var selectionContractionText = "4"
    @State var selectionFeatherRadiusText = "8"
    @State var transformOffsetXText = "0"
    @State var transformOffsetYText = "0"
    @State var transformScaleXText = "100"
    @State var transformScaleYText = "100"
    @State var transformRotationText = "0"
    @State var transformPivotXText = "0"
    @State var transformPivotYText = "0"
    @State var transformLocksAspectRatio = true
    @State var colorRangeTolerance = 0.12
    @State var colorRangeMinimumAlpha = 0.05
    @State var colorRangeExpansion = 0.0
    @State var colorRangeSource: ColorRangeSelectionSource = .activeLayer
    @State var selectedPhotoLayerItem: PhotosPickerItem?
    @State var selectedNewCanvasPhotoItem: PhotosPickerItem?
    @State var selectedToolMetricEditor: ToolMetricEditor?
    @State var toolMetricSizeText = ""
    @State var toolMetricOpacityText = ""
    @FocusState var nanoBananaFocusedField: NanoBananaFocusedField?
    var language: AppLanguage { applicationState.appLanguage }

    enum ToolMetricEditor: Hashable {
        case size
        case opacity
    }

    var body: some View {
        GeometryReader { proxy in
            if applicationState.showsHome {
                homeDashboard
            } else {
                scaledStudioInterface(in: proxy.size)
            }
        }
        .ignoresSafeArea(edges: [.horizontal, .bottom])
        .task {
            store.send(.task)
        }
        .task {
            store.send(.nanoBanana(.task))
        }
        .sheet(item: Binding(
            get: { exportState.shareSheet },
            set: { _ in store.send(.exportSheetDismissed) }
        )) { export in
            ShareSheet(items: [export.url])
        }
        .sheet(isPresented: $showsNewCanvasSheet) {
            newCanvasSheet
        }
        .sheet(isPresented: $showsResizeCanvasSheet) {
            resizeCanvasSheet
        }
        .sheet(isPresented: $showsResizeCanvasExtentSheet) {
            resizeCanvasExtentSheet
        }
        .sheet(isPresented: $showsHSBSheet) {
            hueSaturationBrightnessSheet
        }
        .sheet(isPresented: $showsBrightnessContrastSheet) {
            brightnessContrastSheet
        }
        .sheet(isPresented: $showsLevelsSheet) {
            levelsSheet
        }
        .sheet(isPresented: $showsToneCurveSheet) {
            toneCurveSheet
        }
        .sheet(isPresented: $showsColorBalanceSheet) {
            colorBalanceSheet
        }
        .sheet(isPresented: $showsThresholdSheet) {
            thresholdSheet
        }
        .sheet(isPresented: $showsPosterizeSheet) {
            posterizeSheet
        }
        .sheet(isPresented: $showsGradientMapSheet) {
            gradientMapSheet
        }
        .sheet(isPresented: $showsExpandSelectionSheet) {
            expandSelectionSheet
        }
        .sheet(isPresented: $showsContractSelectionSheet) {
            contractSelectionSheet
        }
        .sheet(isPresented: $showsFeatherSelectionSheet) {
            featherSelectionSheet
        }
        .sheet(isPresented: $showsColorRangeSelectionSheet) {
            colorRangeSelectionSheet
        }
        .sheet(isPresented: $showsTransformNumericSheet) {
            transformNumericSheet
        }
        .sheet(
            isPresented: Binding(
                get: { nanoBananaState.isSheetPresented },
                set: { store.send(.nanoBanana(.sheetPresentationChanged($0))) }
            )
        ) {
            nanoBananaSheet
        }
        .sheet(
            isPresented: Binding(
                get: { nanoBananaState.isPaywallPresented },
                set: { store.send(.nanoBanana(.paywallPresentationChanged($0))) }
            )
        ) {
            nanoBananaPaywallSheet
        }
        .sheet(
            isPresented: Binding(
                get: { recoveryState.isPresented },
                set: { if !$0 { store.send(.autosaveRecoveryDismissed) } }
            )
        ) {
            AutosaveRecoverySheet(
                items: recoveryState.items,
                language: language,
                onRestore: { store.send(.autosaveRecoveryRestoreRequested($0)) },
                onDiscard: { store.send(.autosaveRecoveryDiscardRequested($0)) },
                onClose: { store.send(.autosaveRecoveryDismissed) }
            )
        }
        .sheet(
            isPresented: Binding(
                get: { saveHistoryState.isPresented },
                set: { if !$0 { store.send(.saveHistoryDismissed) } }
            )
        ) {
            SaveHistorySheet(
                title: language.localized("保存履歴"),
                entries: saveHistoryState.entries,
                language: language,
                onRestoreCurrent: { store.send(.saveHistoryRestoreRequested($0, false)) },
                onOpenNewTab: { store.send(.saveHistoryRestoreRequested($0, true)) },
                onClose: { store.send(.saveHistoryDismissed) }
            )
        }
        .fileImporter(
            isPresented: $showsOpenDocumentImporter,
            allowedContentTypes: [.primoDocument],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let sourceURL = urls.first else { return }
            store.send(.openImportedDocumentRequested(sourceURL))
        }
        .photosPicker(
            isPresented: $showsPhotoLayerImporter,
            selection: $selectedPhotoLayerItem,
            matching: .images,
            preferredItemEncoding: .current
        )
        .photosPicker(
            isPresented: $showsNewCanvasPhotoImporter,
            selection: $selectedNewCanvasPhotoItem,
            matching: .images,
            preferredItemEncoding: .current
        )
        .onChange(of: selectedPhotoLayerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await importPhotoLayer(from: newItem)
            }
        }
        .onChange(of: selectedNewCanvasPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await createCanvasFromPhoto(from: newItem)
            }
        }
        .task(id: applicationState.bannerMessage) {
            guard applicationState.bannerMessage != nil else { return }
            do {
                try await Task.sleep(for: .milliseconds(2200))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            store.send(.bannerDismissed)
        }
        .alert(
            language.localized("未保存の変更があります"),
            isPresented: Binding(
                get: { workspaceState.pendingCloseConfirmation != nil },
                set: { if !$0 { store.send(.pendingCloseCancelled) } }
            )
        ) {
            Button(language.localized("保存して閉じる")) {
                store.send(.pendingCloseSaveConfirmed)
            }
            Button(language.localized("保存せず閉じる"), role: .destructive) {
                store.send(.pendingCloseDiscardConfirmed)
            }
            Button(language.localized("キャンセル"), role: .cancel) {
                store.send(.pendingCloseCancelled)
            }
        } message: {
            Text(
                workspaceState.pendingCloseConfirmation?.tabTitles.prefix(3).joined(separator: "\n")
                ?? language.localized("閉じる前に保存するか選んでください")
            )
        }
    }

    @ViewBuilder
    private func scaledStudioInterface(in availableSize: CGSize) -> some View {
        studioInterface
            .frame(
                width: max(availableSize.width / studioUIScale, availableSize.width),
                height: max(availableSize.height / studioUIScale, availableSize.height),
                alignment: .topLeading
            )
            .scaleEffect(studioUIScale, anchor: .topLeading)
            .frame(width: availableSize.width, height: availableSize.height, alignment: .topLeading)
    }

    private var studioInterface: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                toolDockColumn
                    .zIndex(30)

                panelRail(for: .brush)
                    .zIndex(20)

                centerStage
                    .zIndex(1)

                panelRail(for: .layers)
                    .zIndex(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StudioTheme.Gradients.appBackground)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    menuBar
                    undoRedoBar
                }
                .background(WindowGestureShield())
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in },
                    including: .all
                )
                if !workspaceState.openTabs.isEmpty {
                    workspaceTabBar
                }
            }
            .zIndex(1000)
        }
        .overlay(alignment: .topLeading) {
            if store.brushPalette.ui.showsBrushSettingsPopover {
                GeometryReader { proxy in
                    let panelWidth = min(max(proxy.size.width * 0.58, 520), 760)
                    let panelHeight = min(max(proxy.size.height - 128, 520), 760)
                    let panelX = min(max(proxy.size.width * 0.18, 156), 278)
                    let panelY = min(max(proxy.size.height * 0.08, 72), 92)

                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(Color.black.opacity(0.001))
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .allowsHitTesting(false)

                        BrushPaletteView(
                            store: store.scope(
                                state: \.brushPalette,
                                action: \.brushPalette
                            ),
                            currentTool: store.canvas.currentTool,
                            hasSelection: store.canvas.selection != nil,
                            transformPreviewOffset: store.canvas.transformPreviewOffset,
                            transformPreviewScaleX: store.canvas.transformPreviewScaleX,
                            transformPreviewScaleY: store.canvas.transformPreviewScaleY,
                            transformPreviewRotationDegrees: store.canvas.transformPreviewRotationDegrees,
                            transformMode: store.canvas.transformMode,
                            transformLocksAspectRatio: store.canvas.transformLocksAspectRatio,
                            language: language,
                            showsTitle: false,
                            rendersFloatingPanelOnly: true,
                            onSelectTool: { tool in
                                store.send(.toolSelected(tool))
                            },
                            onRequestExpandSelection: {
                                selectionExpansionText = "4"
                                showsExpandSelectionSheet = true
                            },
                            onRequestContractSelection: {
                                selectionContractionText = "4"
                                showsContractSelectionSheet = true
                            },
                            onRequestTransformNumericInput: {
                                syncTransformNumericDraft()
                                showsTransformNumericSheet = true
                            },
                            onSetTransformMode: { mode in
                                store.send(.canvas(.transformModeChanged(mode)))
                            },
                            onSetTransformAspectRatioLock: { isLocked in
                                store.send(.canvas(.transformAspectRatioLockChanged(isLocked)))
                            }
                        )
                        .frame(width: panelWidth, height: panelHeight, alignment: .topLeading)
                        .offset(x: panelX, y: panelY)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .zIndex(500)
            }
        }
        .overlay(alignment: .bottom) {
            if let bannerMessage = applicationState.bannerMessage {
                BannerToast(message: bannerMessage)
                    .padding(.bottom, 18)
            }
        }
        .overlay {
            if let preview = exportState.timelapsePreview {
                TimelapseExportHUD(
                    previewImageData: preview.previewImageData,
                    progress: preview.progress,
                    language: language
                )
            } else if let progress = nanoBananaState.progress {
                ZStack {
                    Color.black.opacity(0.24)
                        .ignoresSafeArea()

                    NanoBananaProgressHUD(
                        previewImageData: nanoBananaInputPreviewImageData,
                        progress: progress,
                        language: language,
                        onCancel: {
                            store.send(.nanoBanana(.cancelGenerationTapped))
                        }
                    )
                }
            }
        }
    }

    private var nanoBananaInputPreviewImageData: Data? {
        guard
            let snapshot = store.canvas.renderSnapshot,
            let layer = snapshot.layers.first(where: { $0.index == resolvedNanoBananaInputLayerIndex })
        else {
            return nil
        }
        return AppFeature.pngData(
            fromLayerPixelData: layer.pixelData,
            width: snapshot.width,
            height: snapshot.height
        )
    }

    @MainActor
    private func importPhotoLayer(from item: PhotosPickerItem) async {
        defer { selectedPhotoLayerItem = nil }
        let language = store.application.appLanguage
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                store.send(
                    .photoImportFailed(
                        AppFeature.ApplicationFeedback
                            .couldNotImportPhoto(nil)
                            .message(for: language)
                    )
                )
                return
            }
            store.send(.photoImportReceived(name: nil, data: data))
        } catch {
            store.send(
                .photoImportFailed(
                    AppFeature.ApplicationFeedback
                        .couldNotImportPhoto(AppFeature.optionalErrorMessage(error))
                        .message(for: language)
                )
            )
        }
    }

    @MainActor
    private func createCanvasFromPhoto(from item: PhotosPickerItem) async {
        defer { selectedNewCanvasPhotoItem = nil }
        let language = store.application.appLanguage
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                store.send(
                    .newCanvasFromImageFailed(
                        AppFeature.ApplicationFeedback
                            .couldNotCreateCanvasFromImage(nil)
                            .message(for: language)
                    )
                )
                return
            }
            store.send(.newCanvasFromImageReceived(name: nil, data: data))
            showsNewCanvasSheet = false
        } catch {
            store.send(
                .newCanvasFromImageFailed(
                    AppFeature.ApplicationFeedback
                        .couldNotCreateCanvasFromImage(AppFeature.optionalErrorMessage(error))
                        .message(for: language)
                )
            )
        }
    }

    func beginCreateCanvasFromImageFlow() {
        showsNewCanvasSheet = false
        DispatchQueue.main.async {
            showsNewCanvasPhotoImporter = true
        }
    }
}
