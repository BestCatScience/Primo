import ComposableArchitecture
import Foundation
import SwiftUI
import UIKit

struct ContentView: View {
    let store: StoreOf<AppFeature>
    private let studioUIScale: CGFloat = 0.56
    @State var showsOpenDocumentImporter = false
    @State var showsNewCanvasSheet = false
    @State var showsHSBSheet = false
    @State var showsBrightnessContrastSheet = false
    @State var showsLevelsSheet = false
    @State var showsToneCurveSheet = false
    @State var showsColorBalanceSheet = false
    @State var showsThresholdSheet = false
    @State var showsPosterizeSheet = false
    @State var showsGradientMapSheet = false
    @State var newCanvasWidthText = ""
    @State var newCanvasHeightText = ""
    @State var gradientMapSettings = GradientMapSettings()
    @State var selectedGradientStopID: GradientMapStopSettings.ID?
    @State var hsbAdjustmentSettings = HueSaturationBrightnessSettings()
    @State var brightnessContrastSettings = BrightnessContrastSettings()
    @State var levelsAdjustmentSettings = LevelsAdjustmentSettings()
    @State var toneCurveSettings = ToneCurveSettings()
    @State var colorBalanceSettings = ColorBalanceSettings()
    @State var thresholdSettings = ThresholdSettings()
    @State var posterizeSettings = PosterizeSettings()
    var language: AppLanguage { store.appLanguage }

    var body: some View {
        GeometryReader { proxy in
            scaledStudioInterface(in: proxy.size)
        }
        .ignoresSafeArea(edges: [.horizontal, .bottom])
        .task {
            store.send(.task)
        }
        .sheet(item: Binding(
            get: { store.exportSheet },
            set: { _ in store.send(.exportSheetDismissed) }
        )) { export in
            ShareSheet(items: [export.url])
        }
        .sheet(isPresented: $showsNewCanvasSheet) {
            newCanvasSheet
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
        .fileImporter(
            isPresented: $showsOpenDocumentImporter,
            allowedContentTypes: [.atelierDocument],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let sourceURL = urls.first else { return }
            guard let stagedURL = stageImportedDocument(from: sourceURL) else { return }
            store.send(.openDocumentSelected(stagedURL))
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
        .background(
            ZStack {
                StudioTheme.Gradients.appBackground

                RadialGradient(
                    colors: [
                        StudioTheme.Palette.accentGlow.opacity(0.22),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 30,
                    endRadius: 520
                )

                RadialGradient(
                    colors: [
                        StudioTheme.Palette.coolGlow.opacity(0.20),
                        .clear
                    ],
                    center: .bottomLeading,
                    startRadius: 40,
                    endRadius: 520
                )
            }
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                menuBar
                undoRedoBar
            }
            .background(WindowGestureShield())
            .contentShape(Rectangle())
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
                            transformPreviewScale: store.canvas.transformPreviewScale,
                            language: language,
                            showsTitle: false,
                            rendersFloatingPanelOnly: true
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
            if let bannerMessage = store.bannerMessage {
                BannerToast(message: bannerMessage)
                    .padding(.bottom, 18)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            store.send(.bannerDismissed)
                        }
                    }
            }
        }
        .overlay {
            if let preview = store.timelapseExportPreview {
                TimelapseExportHUD(
                    previewImageData: preview.previewImageData,
                    progress: preview.progress,
                    language: language
                )
            }
        }
    }

    private func stageImportedDocument(from sourceURL: URL) -> URL? {
        withSecurityScopedAccess(to: sourceURL) {
            let fileManager = FileManager.default
            let stagingRoot = fileManager.temporaryDirectory
                .appendingPathComponent("atelierprime-open", isDirectory: true)
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            let destinationURL = stagingRoot.appendingPathComponent(sourceURL.lastPathComponent, isDirectory: true)

            do {
                try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                return destinationURL
            } catch {
                store.send(.openDocumentFailed(error.localizedDescription))
                return nil
            }
        }
    }

    private func withSecurityScopedAccess<T>(to url: URL, _ work: () -> T) -> T {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return work()
    }
}
