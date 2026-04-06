import ComposableArchitecture
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct BrushPaletteView: View {
    @Bindable var store: StoreOf<BrushPaletteFeature>
    let currentTool: StudioToolKind
    let hasSelection: Bool
    let transformPreviewOffset: CGSize
    var transformPreviewScale: CGFloat = 1.0
    let language: AppLanguage
    var showsTitle = true
    @State var isImportingBrush = false
    @State var showsBrushSettingsPopover = false
    @State var showsSavedBrushDeleteMode = false
    @State var selectedBrushSettingsCategory: BrushSettingsCategory = .tip
    @State var importErrorMessage: String?
    let paletteColumns = Array(repeating: GridItem(.fixed(22), spacing: 8), count: 5)

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .top, spacing: 14) {
                if showsBrushLibrarySidebar {
                    brushLibrarySidebar
                        .frame(minWidth: 196, maxWidth: .infinity, alignment: .topLeading)
                        .overlay(alignment: .topLeading) {
                            if showsBrushSettingsPopover {
                                let panelWidth = floatingPanelWidth
                                floatingBrushSettingsPanel(proxy: proxy)
                                    .frame(width: panelWidth)
                                    .offset(x: floatingPanelXOffset, y: 0)
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                                    .zIndex(10)
                            }
                        }
                        .zIndex(1)
                } else {
                    settingsPanelContent(proxy: proxy, showHeaderTitle: showsTitle)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: showsBrushSettingsPopover)
        .fileImporter(
            isPresented: $isImportingBrush,
            allowedContentTypes: [.png, .atelierBrushTip, UTType(filenameExtension: "abr") ?? .data],
            allowsMultipleSelection: true
        ) { result in
            guard case let .success(urls) = result else { return }
            var imported: [BrushPreset] = []
            var failures: [String] = []
            for url in urls {
                withSecurityScopedAccess(to: url) {
                    if url.pathExtension.lowercased() == "abr" {
                        do {
                            let brushes = try BrushTipLibrary.importPhotoshopBrushes(from: url).map(\.preset)
                            if brushes.isEmpty {
                                failures.append("\(url.lastPathComponent): \(language.localized("対応している先端が見つかりませんでした。"))")
                            } else {
                                imported.append(contentsOf: brushes)
                            }
                        } catch {
                            failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                        }
                        return
                    }
                    let brushName = url.deletingPathExtension().lastPathComponent
                    do {
                        let tip = try BrushTipLibrary.loadRaster(from: url)
                        imported.append(BrushPreset.photoshopImported(name: brushName, tip: tip))
                    } catch {
                        failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            }
            if !imported.isEmpty {
                store.send(.importedPresets(imported))
            }
            if !failures.isEmpty {
                importErrorMessage = failures.joined(separator: "\n")
            }
        }
        .alert(
            language.localized("ブラシを読み込めませんでした"),
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { newValue in
                    if !newValue {
                        importErrorMessage = nil
                    }
                }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    importErrorMessage = nil
                }
            },
            message: {
                Text(importErrorMessage ?? "")
            }
        )
    }

    private var floatingPanelWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return min(max(screenWidth * 0.42, 520), 720)
    }

    private var floatingPanelXOffset: CGFloat {
        208
    }
}
