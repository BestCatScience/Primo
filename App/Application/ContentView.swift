import ComposableArchitecture
import Foundation
import SwiftUI
import UIKit

struct ContentView: View {
    let store: StoreOf<AppFeature>
    @State var showsOpenDocumentImporter = false
    @State var showsNewCanvasSheet = false
    @State var newCanvasWidthText = ""
    @State var newCanvasHeightText = ""
    var language: AppLanguage { store.appLanguage }

    var body: some View {
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
                .zIndex(1000)
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
        .fileImporter(
            isPresented: $showsOpenDocumentImporter,
            allowedContentTypes: [.atelierDocument],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let sourceURL = urls.first else { return }
            guard let stagedURL = stageImportedDocument(from: sourceURL) else { return }
            store.send(.openDocumentSelected(stagedURL))
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
                            .onTapGesture {
                                dismissBrushSettingsPopover()
                            }

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
