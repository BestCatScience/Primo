import ComposableArchitecture
import SwiftUI
import UIKit

struct ContentView: View {
    let store: StoreOf<AppFeature>
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
}
