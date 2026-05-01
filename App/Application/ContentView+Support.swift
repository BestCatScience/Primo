import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentPresentationContracts
import PrimoDocumentRuntime
import SwiftUI
import UIKit

struct SurfacePreviewView: UIViewRepresentable {
    let surface: DocumentCompositeSurface?
    var opacity: CGFloat = 1.0
    var filtering: PrimoMetalSurfaceFiltering = .linear

    func makeUIView(context: Context) -> CanvasPixelSurfaceView {
        CanvasPixelSurfaceView()
    }

    func updateUIView(_ uiView: CanvasPixelSurfaceView, context: Context) {
        uiView.update(surface: surface, opacity: opacity, filtering: filtering)
    }
}

enum StoredSurfaceAdapter {
    static func surface(from encodedImageData: Data?) -> DocumentCompositeSurface? {
        guard
            let encodedImageData,
            let decoded = DocumentRasterImageService.decodedImage(fromEncodedData: encodedImageData)
        else {
            return nil
        }
        return DocumentCompositeSurface(
            validatingWidth: decoded.width,
            height: decoded.height,
            pixelData: decoded.pixelData
        )
    }
}

struct TimelapseExportHUD: View {
    let previewSurface: DocumentCompositeSurface?
    let previewImageData: Data?
    let progress: Double
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 12) {
            if let previewSurface {
                SurfacePreviewView(surface: previewSurface)
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            } else if let fallbackSurface = StoredSurfaceAdapter.surface(from: previewImageData) {
                SurfacePreviewView(surface: fallbackSurface)
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(StudioStrings.exportingTimelapse(language))
                    .font(StudioTheme.Typography.title(16))
                    .foregroundStyle(.white.opacity(0.94))

                ProgressView(value: progress, total: 1.0)
                    .tint(StudioTheme.Palette.accentBright)

                Text("\(Int((progress * 100).rounded()))%")
                    .font(StudioTheme.Typography.mono(11))
                    .foregroundStyle(.white.opacity(0.62))
            }
            .frame(width: 220, alignment: .leading)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(StudioTheme.Palette.overlayBlack.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 24, y: 16)
        .allowsHitTesting(false)
    }
}

struct AIImageProgressHUD: View {
    let previewSurface: DocumentCompositeSurface?
    let previewImageData: Data?
    let progress: Double
    let language: AppLanguage
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if let previewSurface {
                SurfacePreviewView(surface: previewSurface)
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            } else if let fallbackSurface = StoredSurfaceAdapter.surface(from: previewImageData) {
                SurfacePreviewView(surface: fallbackSurface)
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(language.localized("AI画像で生成中"))
                    .font(StudioTheme.Typography.title(16))
                    .foregroundStyle(.white.opacity(0.94))

                ProgressView(value: progress, total: 1.0)
                    .tint(StudioTheme.Palette.accentBright)

                Text("\(Int((progress * 100).rounded()))%")
                    .font(StudioTheme.Typography.mono(11))
                    .foregroundStyle(.white.opacity(0.62))

                Button(action: onCancel) {
                    Text(language.localized("キャンセル"))
                        .font(StudioTheme.Typography.label(13))
                        .foregroundStyle(.white.opacity(0.94))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .frame(width: 220, alignment: .leading)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(StudioTheme.Palette.overlayBlack.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 24, y: 16)
    }
}

struct MinimumHitTargetModifier: ViewModifier {
    let minSize: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(minWidth: minSize, minHeight: minSize)
            .contentShape(Rectangle())
    }
}

extension View {
    func minimumHitTarget(_ minSize: CGFloat = 44) -> some View {
        modifier(MinimumHitTargetModifier(minSize: minSize))
    }

    func studioWindowGlow(cornerRadius: CGFloat, intensity: Double = 1) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            StudioTheme.Palette.accentBright.opacity(0.72 * intensity),
                            Color.white.opacity(0.20 * intensity),
                            StudioTheme.Palette.accentBright.opacity(0.38 * intensity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
                .shadow(color: StudioTheme.Palette.accentBright.opacity(0.34 * intensity), radius: 9, x: 0, y: 0)
                .allowsHitTesting(false)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct StudioPlainTextView: UIViewRepresentable {
    @Binding var text: String
    let textColor: UIColor
    let tintColor: UIColor
    let font: UIFont
    let backgroundColor: UIColor

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = backgroundColor
        textView.textContainerInset = UIEdgeInsets(top: 1, left: 0, bottom: 1, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.spellCheckingType = .yes
        textView.keyboardDismissMode = .interactive
        textView.text = text
        textView.textColor = textColor
        textView.tintColor = tintColor
        textView.font = font
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.textColor = textColor
        uiView.tintColor = tintColor
        uiView.backgroundColor = backgroundColor
        uiView.font = font
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }
    }
}

struct BannerToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(StudioTheme.Typography.label(13))
            .foregroundStyle(.white.opacity(0.94))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(StudioTheme.Palette.overlayBlack.opacity(0.96))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
    }
}

struct AutosaveRecoverySheet: View {
    let items: [AutosaveRecoveryItem]
    let language: AppLanguage
    let onRestore: (WorkspaceItemID) -> Void
    let onDiscard: (WorkspaceItemID) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            preview(item.previewSurface, item.previewImageData, symbol: "clock.arrow.circlepath")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(dateFormatter.string(from: item.updatedAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        HStack(spacing: 10) {
                            Button(language.localized("復元")) {
                                onRestore(item.id)
                            }
                            .buttonStyle(.borderedProminent)

                            Button(language.localized("破棄")) {
                                onDiscard(item.id)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(language.localized("自動保存を復元"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.localized("後で")) {
                        onClose()
                    }
                }
            }
        }
    }

    private func preview(_ surface: DocumentCompositeSurface?, _ data: Data?, symbol: String) -> some View {
        Group {
            if let surface {
                SurfacePreviewView(surface: surface)
            } else if let surface = StoredSurfaceAdapter.surface(from: data) {
                SurfacePreviewView(surface: surface)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.08))
                    .overlay(Image(systemName: symbol).foregroundStyle(.secondary))
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

struct SaveHistorySheet: View {
    let title: String
    let entries: [SaveHistoryEntry]
    let language: AppLanguage
    let onRestoreCurrent: (DocumentProjectPath) -> Void
    let onOpenNewTab: (DocumentProjectPath) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    Text(language.localized("保存履歴はまだありません"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                preview(entry.previewSurface, entry.previewImageData, symbol: "clock.arrow.circlepath")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.trigger.title(language))
                                        .font(.headline)
                                    Text(dateFormatter.string(from: entry.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }

                            HStack(spacing: 10) {
                                Button(language.localized("現在のタブに復元")) {
                                    onRestoreCurrent(entry.projectURL)
                                }
                                .buttonStyle(.borderedProminent)

                                Button(language.localized("新しいタブで開く")) {
                                    onOpenNewTab(entry.projectURL)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.localized("閉じる")) {
                        onClose()
                    }
                }
            }
        }
    }

    private func preview(_ surface: DocumentCompositeSurface?, _ data: Data?, symbol: String) -> some View {
        Group {
            if let surface {
                SurfacePreviewView(surface: surface)
            } else if let surface = StoredSurfaceAdapter.surface(from: data) {
                SurfacePreviewView(surface: surface)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.08))
                    .overlay(Image(systemName: symbol).foregroundStyle(.secondary))
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

struct CanvasHUD: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(StudioTheme.Typography.mono(10))
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(StudioTheme.Typography.title(12))
                .foregroundStyle(StudioTheme.Palette.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(StudioTheme.Palette.overlayBlack)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
        )
    }
}

struct DiagonalStageLines: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                stride(from: -height, through: width + height, by: 32).forEach { offset in
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset - height, y: height))
                }
            }
            .stroke(StudioTheme.Palette.hairline, lineWidth: 1)
        }
    }
}

extension ContentView {
    var applicationState: ApplicationFeature.State { store.application }
    var workspaceState: PrimoRootFeature.WorkspaceState { store.workspace }
    var recoveryState: ApplicationFeature.RecoveryState { store.application.recovery }
    var saveHistoryState: ImportExportFeature.SaveHistoryState { store.importExport.saveHistory }
    var exportState: ImportExportFeature.ExportState { store.importExport.export }
    var aiImageState: AIImageFeature.State { store.aiImage }

    func workspaceTabs(in pane: WorkspacePane) -> [OpenDocumentTab] {
        workspaceState.openTabs.filter { $0.pane == pane }
    }

    func workspaceSelectedTabID(for pane: WorkspacePane) -> OpenDocumentTab.ID? {
        switch pane {
        case .primary:
            return workspaceState.primarySelectedTabID
        case .secondary:
            return workspaceState.secondarySelectedTabID
        }
    }

    func workspaceSelectedTab(in pane: WorkspacePane) -> OpenDocumentTab? {
        guard let selectedTabID = workspaceSelectedTabID(for: pane) else { return nil }
        return workspaceState.openTabs.first(where: { $0.id == selectedTabID })
    }

    var homeDashboard: some View {
        ZStack {
            homeBackground

            VStack(spacing: 0) {
                homeTopBar
                if !workspaceState.openTabs.isEmpty {
                    workspaceTabBar
                }

                HStack(spacing: 0) {
                    homeSidebar
                    homePrimaryPane
                }
            }
        }
    }

    private var homeBackground: some View {
        Color(red: 0.17, green: 0.17, blue: 0.17)
        .ignoresSafeArea()
    }

    var workspaceTabBar: some View {
        Group {
            if workspaceState.workspaceLayout != .single {
                HStack(spacing: 0) {
                    workspaceTabStrip(for: .primary)
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1)
                    workspaceTabStrip(for: .secondary)
                }
            } else {
                workspaceTabStrip(for: .primary)
            }
        }
        .frame(height: 48)
        .background(StudioTheme.Gradients.chrome)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
        }
    }

    func workspaceTabStrip(for pane: WorkspacePane) -> some View {
        let tabs = workspaceTabs(in: pane)

        return HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tabs) { tab in
                        workspaceTabItem(tab, in: pane)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .animation(.spring(response: 0.28, dampingFraction: 0.88), value: tabs.map(\.id))
            }
            .dropDestination(for: String.self) { items, _ in
                guard
                    let rawValue = items.first,
                    let movingID = UUID(uuidString: rawValue)
                else {
                    return false
                }
                store.send(.workspace(.tabDropped(moving: movingID, toPane: pane, before: nil)))
                return true
            }
            .frame(height: 48)

            HStack(spacing: 6) {
                if pane == .primary {
                    if workspaceState.activeTabID != nil {
                        workspaceTabAddMenu()
                    }
                    if workspaceState.workspaceLayout != .single {
                        workspaceTabChromeButton(symbol: "sidebar.leading") {
                            store.send(.workspace(.mergeWorkspacePanes))
                        }
                    }
                }
            }
            .padding(.trailing, 10)
            .frame(height: 48)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 48)
    }

    func workspaceTabItem(_ tab: OpenDocumentTab, in pane: WorkspacePane) -> some View {
        let isActive = workspaceState.activeTabID == tab.id && workspaceState.focusedWorkspacePane == pane
        let isSelected = workspaceSelectedTabID(for: pane) == tab.id

        return HStack(spacing: 10) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isActive ? StudioTheme.Palette.textPrimary : StudioTheme.Palette.textSecondary)

            Circle()
                .fill(tab.isDirty ? StudioTheme.Palette.accentBright : Color.clear)
                .frame(width: 7, height: 7)

            Text(tab.title)
                .font(StudioTheme.Typography.label(10))
                .foregroundStyle(isActive ? StudioTheme.Palette.textPrimary : StudioTheme.Palette.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                store.send(.workspace(.tabCloseRequested(tab.id)))
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(StudioTheme.Palette.textSecondary)
                    .frame(width: 18, height: 18)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.16))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 144, height: 32, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? StudioTheme.Palette.selectedFill : (isSelected ? Color.white.opacity(0.08) : StudioTheme.Palette.toolbarFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isActive ? StudioTheme.Palette.selectedBorder : StudioTheme.Palette.cardBorder, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {
            store.send(.workspace(.tabSelected(tab.id)))
        }
        .contextMenu {
            Button(language.localized("閉じる")) {
                store.send(.workspace(.tabCloseRequested(tab.id)))
            }
            Button(language.localized("他を閉じる")) {
                store.send(.workspace(.closeOtherTabsRequested(tab.id)))
            }
            Button(language.localized("右側を閉じる")) {
                store.send(.workspace(.closeTabsToRightRequested(tab.id)))
            }
            Button(language.localized("右ペインへ移動")) {
                store.send(.workspace(.moveTabToSecondaryPane(tab.id)))
            }
        }
        .draggable(tab.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            guard
                let rawValue = items.first,
                let movingID = UUID(uuidString: rawValue),
                movingID != tab.id
            else {
                return false
            }
            store.send(.workspace(.tabDropped(moving: movingID, toPane: pane, before: tab.id)))
            return true
        }
    }

    func workspaceTabAddMenu() -> some View {
        Button {
            showsWorkspaceTabAddMenu = true
        } label: {
            workspaceTabAddMenuLabel
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showsWorkspaceTabAddMenu, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            workspaceTabAddPopover
                .presentationCompactAdaptation(.popover)
        }
    }

    var workspaceTabAddPopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            workspaceTabAddPopoverButton(
                title: language.localized("タブ"),
                systemImage: "tag",
                destination: .currentPane
            )
            workspaceTabAddPopoverButton(
                title: language.localized("右側にキャンバスを複製"),
                systemImage: "square.split.2x1",
                destination: .rightPane
            )
            workspaceTabAddPopoverButton(
                title: language.localized("下側にキャンバスを複製"),
                systemImage: "square.split.1x2",
                destination: .belowPane
            )
        }
        .padding(8)
        .frame(width: 260, alignment: .leading)
        .background(StudioTheme.Gradients.chrome)
    }

    func workspaceTabAddPopoverButton(
        title: String,
        systemImage: String,
        destination: WorkspaceFeature.WorkspaceCanvasDuplicateDestination
    ) -> some View {
        Button {
            showsWorkspaceTabAddMenu = false
            store.send(.workspace(.duplicateActiveCanvasRequested(destination)))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 20)
                Text(title)
                    .font(StudioTheme.Typography.label(12))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(StudioTheme.Palette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    var workspaceTabAddMenuLabel: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "tag")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 19, height: 19)

            Image(systemName: "plus")
                .font(.system(size: 7, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 11, height: 11)
                .background(
                    Circle()
                        .fill(StudioTheme.Palette.accentBright)
                )
                .offset(x: 5, y: -5)
        }
        .foregroundStyle(StudioTheme.Palette.accentBright)
        .frame(width: 30, height: 28)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(StudioTheme.Palette.accentBright.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(StudioTheme.Palette.accentBright.opacity(0.64), lineWidth: 1.4)
        )
        .shadow(color: StudioTheme.Palette.accentBright.opacity(0.24), radius: 8, x: 0, y: 0)
        .contentShape(Rectangle())
    }

    func workspaceTabChromeButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.74))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var homeTopBar: some View {
        HStack(spacing: 14) {
            appLogoMark(size: 34)

            Text("Primo")
                .font(StudioTheme.Typography.title(18))
                .foregroundStyle(.white.opacity(0.88))

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color(red: 0.20, green: 0.20, blue: 0.20))
    }

    private func appLogoMark(size: CGFloat) -> some View {
        Image("AppLogo")
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var homeSidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(spacing: 8) {
                ForEach(HomeSidebarSection.allCases, id: \.self) { section in
                    homeSidebarButton(for: section)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                Text(language.localized("ファイル"))
                    .font(StudioTheme.Typography.label(14))
                    .foregroundStyle(Color.white.opacity(0.42))

                homeFileActionRow(
                    systemName: "doc.fill",
                    title: language.localized("自分のファイル"),
                    action: {
                        store.send(.application(.homeProjectsLoadRequested))
                        store.send(.application(.homeSectionSelected(.home)))
                    }
                )
            }

            Spacer(minLength: 0)

            Divider()
                .overlay(Color.white.opacity(0.10))

            VStack(alignment: .leading, spacing: 14) {
                homeFooterAction(
                    systemName: "plus.circle.fill",
                    title: language.localized("新規作成"),
                    tint: Color(red: 0.24, green: 0.53, blue: 0.98)
                ) {
                    newCanvasWidthText = "\(Int(CanvasFeature.defaultCanvasSize.width.rounded()))"
                    newCanvasHeightText = "\(Int(CanvasFeature.defaultCanvasSize.height.rounded()))"
                    showsNewCanvasSheet = true
                }

                homeFooterAction(
                    systemName: "rectangle.portrait.and.arrow.right",
                    title: language.localized("読み込み／開く"),
                    tint: Color.white.opacity(0.68)
                ) {
                    showsOpenDocumentImporter = true
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .frame(width: 236)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0.14, green: 0.14, blue: 0.14))
    }

    private func homeSidebarButton(for section: HomeSidebarSection) -> some View {
        let isSelected = applicationState.homeSection == section

        return Button {
            store.send(.application(.homeSectionSelected(section)))
        } label: {
            HStack(spacing: 12) {
                homeGlyphBadge(systemName: section.iconSystemName, accent: isSelected ? Color.white : Color(red: 0.60, green: 0.82, blue: 0.98))

                Text(section.title(language))
                    .font(StudioTheme.Typography.title(16))

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? .white : Color.white.opacity(0.72))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func homeFileActionRow(systemName: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                homeGlyphBadge(systemName: systemName, accent: Color.white.opacity(0.86))
                Text(title)
                    .font(StudioTheme.Typography.title(15))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.white.opacity(0.80))
        }
        .buttonStyle(.plain)
    }

    private func homeFooterAction(
        systemName: String,
        title: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                homeGlyphBadge(systemName: systemName, accent: tint)
                Text(title)
                    .font(StudioTheme.Typography.title(17))
                    .foregroundStyle(Color.white.opacity(0.86))
            }
        }
        .buttonStyle(.plain)
    }

    private func homeGlyphBadge(systemName: String, accent: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white.opacity(0.04))
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: 22, height: 22)
    }

    @ViewBuilder
    private var homePrimaryPane: some View {
        switch applicationState.homeSection {
        case .home:
            homeCanvasPane
        case .learn:
            homeSettingsPane
        }
    }

    private var homeCanvasPane: some View {
        Group {
            if applicationState.isLoadingHomeProjects {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(.white.opacity(0.8))
                        .controlSize(.large)
                    Spacer()
                }
            } else if applicationState.homeProjects.isEmpty {
                homeEmptyProjectsView
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 18)],
                        spacing: 18
                    ) {
                        ForEach(applicationState.homeProjects) { project in
                            homeProjectCard(project)
                        }
                    }
                    .padding(14)
                }
            }
        }
        .background(Color(red: 0.20, green: 0.20, blue: 0.20))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var homeSettingsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(language.localized("学ぶ"))
                    .font(StudioTheme.Typography.display(28))
                    .foregroundStyle(.white.opacity(0.92))

                learnPanel(
                    title: language.localized("最近の制作をすぐ再開"),
                    detail: language.localized("ホームでは保存済みの作品、クラウド状態、新規作成と読み込みをすばやく操作できます。")
                )
                learnPanel(
                    title: StudioStrings.appLanguageTitle(language),
                    detail: "\(language.title) / \(StudioStrings.storageSummary(applicationState.homeProjects.count, language))"
                )

                Button {
                    showsLicensesSheet = true
                } label: {
                    learnPanel(
                        title: StudioStrings.openSourceLicenses(language),
                        detail: StudioStrings.openSourceLicensesHomeDetail(language)
                    )
                }
                .buttonStyle(.plain)

                Picker(StudioStrings.appLanguageTitle(language), selection: Binding(
                    get: { applicationState.appLanguage },
                    set: { store.send(.application(.languageChanged($0))) }
                )) {
                    ForEach(AppLanguage.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .colorScheme(.dark)
            }
            .padding(18)
        }
        .background(Color(red: 0.20, green: 0.20, blue: 0.20))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func learnPanel(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(StudioTheme.Typography.title(20))
                .foregroundStyle(.white.opacity(0.92))
            Text(detail)
                .font(StudioTheme.Typography.body(15))
                .foregroundStyle(Color.white.opacity(0.64))
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }

    private var homeEmptyProjectsView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            appLogoMark(size: 64)
                .opacity(0.82)

            Text(StudioStrings.noProjectsTitle(language))
                .font(StudioTheme.Typography.title(24))
                .foregroundStyle(Color.white.opacity(0.88))

            Text(StudioStrings.noProjectsMessage(language))
                .font(StudioTheme.Typography.body(16))
                .foregroundStyle(Color.white.opacity(0.56))

            Button(StudioStrings.createCanvasCTA(language)) {
                newCanvasWidthText = "\(Int(CanvasFeature.defaultCanvasSize.width.rounded()))"
                newCanvasHeightText = "\(Int(CanvasFeature.defaultCanvasSize.height.rounded()))"
                showsNewCanvasSheet = true
            }
            .font(StudioTheme.Typography.title(16))
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func homeProjectCard(_ project: SavedProjectSummary) -> some View {
        Button {
            store.send(.workspace(.homeProjectSelected(project.url)))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Group {
                    if let surface = project.previewSurface ?? StoredSurfaceAdapter.surface(from: project.previewImageData) {
                        SurfacePreviewView(surface: surface)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white)
                    } else {
                        ZStack {
                            Color.white

                            appLogoMark(size: 72)
                                .opacity(0.72)
                        }
                    }
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color(red: 0.40, green: 0.40, blue: 0.40))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Image(systemName: "cloud.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.92))
                        )
                        .padding(6)
                }
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(project.name)
                            .font(StudioTheme.Typography.title(18))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Color.white.opacity(0.54))
                    }

                    Text(StudioStrings.updatedAt(project.modifiedAt, language).replacingOccurrences(of: "更新 ", with: "").replacingOccurrences(of: "Updated ", with: ""))
                        .font(StudioTheme.Typography.body(12))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .lineLimit(2)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(red: 0.22, green: 0.22, blue: 0.22))
            )
            .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

let studioTools: [StudioToolKind] = [.brush, .erase, .blur, .fill, .eyedropper, .shape, .text]

struct StudioPanelShell<Content: View>: View {
    let title: String
    let isCollapsed: Bool
    let content: Content

    init(
        title: String,
        isCollapsed: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.isCollapsed = isCollapsed
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if !isCollapsed {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(panelBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(StudioTheme.Palette.cardBorder, lineWidth: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.025), lineWidth: 1)
                .blur(radius: 0.5)
                .padding(1)
        }
        .studioWindowGlow(cornerRadius: 14, intensity: 0.42)
        .shadow(color: Color.black.opacity(0.24), radius: 18, y: 12)
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(StudioTheme.Palette.accentBright.opacity(isCollapsed ? 0.45 : 0.9))
                    .frame(width: 3, height: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(StudioTheme.Typography.title(16))
                        .foregroundStyle(StudioTheme.Palette.textPrimary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(StudioTheme.Gradients.panelHeader)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StudioTheme.Palette.hairline)
                .frame(height: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var panelBackground: LinearGradient {
        StudioTheme.Gradients.panel
    }
}
