import ComposableArchitecture
import PrimoDocumentContracts
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct BrushPaletteView: View {
    @Bindable var store: StoreOf<BrushPaletteFeature>
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    let currentTool: StudioToolKind
    let hasSelection: Bool
    let transformPreviewOffset: CGSize
    var transformPreviewScaleX: CGFloat = 1.0
    var transformPreviewScaleY: CGFloat = 1.0
    var transformPreviewRotationDegrees: Double = 0
    var transformMode: CanvasTransformMode = .standard
    var transformLocksAspectRatio = true
    let language: AppLanguage
    var showsTitle = true
    @State var isImportingBrush = false
    @State var isImportingCustomTip = false
    @State var isImportingTextFont = false
    @State var showsSavedBrushDeleteMode = false
    @State var selectedBrushSettingsCategory: BrushSettingsCategory = .tip
    @State var selectedToolInspectorTab: ToolInspectorTab = .basic
    @State var renamingSavedTipPresetName: String?
    @State var savedTipRenameDraft = ""
    var rendersFloatingPanelOnly = false
    var onSelectTool: (StudioToolKind) -> Void = { _ in }
    var onRequestExpandSelection: () -> Void = {}
    var onRequestContractSelection: () -> Void = {}
    var onRequestTransformNumericInput: () -> Void = {}
    var onSetTransformMode: (CanvasTransformMode) -> Void = { _ in }
    var onSetTransformAspectRatioLock: (Bool) -> Void = { _ in }
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
        .task {
            store.send(.task)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: store.ui.showsBrushSettingsPopover)
        .sheet(isPresented: $isImportingBrush) {
            BrushImportDocumentPicker(
                allowedContentTypes: [.png, .primoBrushTip, UTType(filenameExtension: "abr") ?? .data],
                allowsMultipleSelection: true,
                onPick: { urls in
                    isImportingBrush = false
                    store.send(.importBrushesRequested(urls))
                },
                onCancel: { isImportingBrush = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isImportingCustomTip) {
            BrushImportDocumentPicker(
                allowedContentTypes: [.png, .primoBrushTip],
                allowsMultipleSelection: false,
                onPick: { urls in
                    isImportingCustomTip = false
                    guard let url = urls.first else { return }
                    store.send(.importCustomTipRequested(url))
                },
                onCancel: { isImportingCustomTip = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isImportingTextFont) {
            BrushImportDocumentPicker(
                allowedContentTypes: [UTType(filenameExtension: "ttf") ?? .data, UTType(filenameExtension: "otf") ?? .data],
                allowsMultipleSelection: true,
                onPick: { urls in
                    isImportingTextFont = false
                    store.send(.importTextFontsRequested(urls))
                },
                onCancel: { isImportingTextFont = false }
            )
            .ignoresSafeArea()
        }
        .alert(
            language.localized("ブラシを読み込めませんでした"),
            isPresented: Binding(
                get: { store.ui.brushLibraryErrorMessage != nil },
                set: { newValue in
                    if !newValue {
                        store.send(.dismissBrushLibraryError)
                    }
                }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    store.send(.dismissBrushLibraryError)
                }
            },
            message: {
                Text(store.ui.brushLibraryErrorMessage ?? "")
            }
        )
        .alert(
            language.localized("フォントを読み込めませんでした"),
            isPresented: Binding(
                get: { store.ui.textFontImportErrorMessage != nil },
                set: { newValue in
                    if !newValue {
                        store.send(.dismissTextFontImportError)
                    }
                }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    store.send(.dismissTextFontImportError)
                }
            },
            message: {
                Text(store.ui.textFontImportErrorMessage ?? "")
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
