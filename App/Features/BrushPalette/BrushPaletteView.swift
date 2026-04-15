import ComposableArchitecture
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct BrushPaletteView: View {
    @Bindable var store: StoreOf<BrushPaletteFeature>
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    let currentTool: StudioToolKind
    let hasSelection: Bool
    let transformPreviewOffset: CGSize
    var transformPreviewScale: CGFloat = 1.0
    var transformPreviewRotationDegrees: Double = 0
    let language: AppLanguage
    var showsTitle = true
    @State var isImportingBrush = false
    @State var isImportingTextFont = false
    @State var showsSavedBrushDeleteMode = false
    @State var selectedBrushSettingsCategory: BrushSettingsCategory = .tip
    @State var selectedToolInspectorTab: ToolInspectorTab = .basic
    @State var importErrorMessage: String?
    @State var textFontImportErrorMessage: String?
    var rendersFloatingPanelOnly = false
    var onSelectTool: (StudioToolKind) -> Void = { _ in }
    var onRequestExpandSelection: () -> Void = {}
    var onRequestContractSelection: () -> Void = {}
    let paletteColumns = Array(repeating: GridItem(.fixed(22), spacing: 8), count: 5)

    var body: some View {
        GeometryReader { proxy in
            if rendersFloatingPanelOnly {
                floatingBrushSettingsPanel(proxy: proxy)
                    .frame(width: floatingPanelWidth(in: proxy))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                HStack(alignment: .top, spacing: 14) {
                    if showsBrushLibrarySidebar {
                        brushLibrarySidebar
                            .frame(minWidth: 196, maxWidth: .infinity, alignment: .topLeading)
                            .zIndex(1)
                    } else {
                        settingsPanelContent(proxy: proxy, showHeaderTitle: showsTitle)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: store.ui.showsBrushSettingsPopover)
        .sheet(isPresented: $isImportingBrush) {
            BrushImportDocumentPicker(
                allowedContentTypes: [.png, .atelierBrushTip, UTType(filenameExtension: "abr") ?? .data],
                allowsMultipleSelection: true,
                onPick: importBrushes,
                onCancel: { isImportingBrush = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isImportingTextFont) {
            BrushImportDocumentPicker(
                allowedContentTypes: [UTType(filenameExtension: "ttf") ?? .data, UTType(filenameExtension: "otf") ?? .data],
                allowsMultipleSelection: true,
                onPick: importTextFonts,
                onCancel: { isImportingTextFont = false }
            )
            .ignoresSafeArea()
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
        .alert(
            language.localized("フォントを読み込めませんでした"),
            isPresented: Binding(
                get: { textFontImportErrorMessage != nil },
                set: { newValue in
                    if !newValue {
                        textFontImportErrorMessage = nil
                    }
                }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    textFontImportErrorMessage = nil
                }
            },
            message: {
                Text(textFontImportErrorMessage ?? "")
            }
        )
    }

    private func floatingPanelWidth(in proxy: GeometryProxy) -> CGFloat {
        if currentTool == .brush || currentTool == .erase {
            return min(max(proxy.size.width * 0.24, 260), 320)
        }
        let availableWidth = proxy.size.width + floatingPanelXOffset + 80
        if horizontalSizeClass == .regular {
            return min(max(availableWidth * 0.72, 560), 720)
        }
        return min(max(availableWidth * 0.9, 360), 460)
    }

    private var floatingPanelXOffset: CGFloat {
        208
    }

    private func importBrushes(_ urls: [URL]) {
        isImportingBrush = false
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

    private func importTextFonts(_ urls: [URL]) {
        isImportingTextFont = false
        var importedFonts: [TextFontOption] = []
        var failures: [String] = []

        for url in urls {
            withSecurityScopedAccess(to: url) {
                do {
                    importedFonts.append(contentsOf: try TextFontLibrary.importFonts(from: [url]))
                } catch {
                    failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }

        if !importedFonts.isEmpty {
            store.send(.importedTextFonts(importedFonts))
        }
        if !failures.isEmpty {
            textFontImportErrorMessage = failures.joined(separator: "\n")
        }
    }
}

private struct BrushImportDocumentPicker: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onPick: ([URL]) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = allowsMultipleSelection
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: ([URL]) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping ([URL]) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}
