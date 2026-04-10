import SwiftUI
import UIKit

struct TimelapseExportHUD: View {
    let previewImageData: Data?
    let progress: Double
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 12) {
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFit()
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

    private var previewImage: UIImage? {
        guard let previewImageData else { return nil }
        return UIImage(data: previewImageData)
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
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct WindowGestureShield: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ShieldView {
        let view = ShieldView()
        view.addGestureRecognizer(context.coordinator.panRecognizer)
        return view
    }

    func updateUIView(_ uiView: ShieldView, context: Context) {}

    final class Coordinator: NSObject {
        lazy var panRecognizer: UIPanGestureRecognizer = {
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
            recognizer.cancelsTouchesInView = true
            return recognizer
        }()

        @objc private func handlePan() {}
    }

    final class ShieldView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isOpaque = false
            isUserInteractionEnabled = true
            accessibilityElementsHidden = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            true
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
                stride(from: -height, through: width + height, by: 36).forEach { offset in
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset - height, y: height))
                }
            }
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}

extension ContentView {
    var homeDashboard: some View {
        ZStack {
            homeBackground

            VStack(spacing: 0) {
                homeTopBar

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

    private var homeTopBar: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(red: 0.05, green: 0.11, blue: 0.17))
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color(red: 0.23, green: 0.78, blue: 1.0).opacity(0.45), lineWidth: 1)
                Text("Ap")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.38, green: 0.84, blue: 1.0))
            }
            .frame(width: 34, height: 34)

            Text("AtelierPrime")
                .font(StudioTheme.Typography.title(18))
                .foregroundStyle(.white.opacity(0.88))

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color(red: 0.20, green: 0.20, blue: 0.20))
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
                    action: {}
                )
                homeFileActionRow(
                    systemName: "person.2.fill",
                    title: language.localized("共有されたアイテム"),
                    action: {}
                )
                homeFileActionRow(
                    systemName: "trash.fill",
                    title: language.localized("削除済み"),
                    action: {}
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
                    newCanvasWidthText = "\(max(Int(store.canvas.canvasSize.width.rounded()), 1))"
                    newCanvasHeightText = "\(max(Int(store.canvas.canvasSize.height.rounded()), 1))"
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
        let isSelected = store.homeSection == section

        return Button {
            store.send(.homeSectionSelected(section))
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
        switch store.homeSection {
        case .home:
            homeCanvasPane
        case .learn:
            homeSettingsPane
        }
    }

    private var homeCanvasPane: some View {
        Group {
            if store.isLoadingHomeProjects {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(.white.opacity(0.8))
                        .controlSize(.large)
                    Spacer()
                }
            } else if store.homeProjects.isEmpty {
                homeEmptyProjectsView
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 18)],
                        spacing: 18
                    ) {
                        ForEach(store.homeProjects) { project in
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
                    detail: "\(language.title) / \(StudioStrings.storageSummary(store.homeProjects.count, language))"
                )

                Picker(StudioStrings.appLanguageTitle(language), selection: Binding(
                    get: { store.appLanguage },
                    set: { store.send(.languageChanged($0)) }
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

            Image(systemName: "square.grid.2x2")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.42))

            Text(StudioStrings.noProjectsTitle(language))
                .font(StudioTheme.Typography.title(24))
                .foregroundStyle(Color.white.opacity(0.88))

            Text(StudioStrings.noProjectsMessage(language))
                .font(StudioTheme.Typography.body(16))
                .foregroundStyle(Color.white.opacity(0.56))

            Button(StudioStrings.createCanvasCTA(language)) {
                newCanvasWidthText = "\(max(Int(store.canvas.canvasSize.width.rounded()), 1))"
                newCanvasHeightText = "\(max(Int(store.canvas.canvasSize.height.rounded()), 1))"
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
            store.send(.homeProjectSelected(project.url))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Group {
                    if let data = project.previewImageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.medium)
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white)
                    } else {
                        ZStack {
                            Color.white

                            Image(systemName: "scribble")
                                .font(.system(size: 34, weight: .regular))
                                .foregroundStyle(Color(red: 0.60, green: 0.63, blue: 0.70))
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
        }
        .buttonStyle(.plain)
    }
}

let studioTools: [StudioToolKind] = [.brush, .erase, .blur, .fill, .eyedropper, .select, .move, .shape]

struct StudioPanelShell<Content: View>: View {
    let title: String
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    let content: Content

    init(
        title: String,
        isCollapsed: Bool,
        onToggleCollapse: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.isCollapsed = isCollapsed
        self.onToggleCollapse = onToggleCollapse
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
        .background(panelBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .top) {
            Capsule(style: .continuous)
                .fill(StudioTheme.Gradients.accentBar)
                .frame(width: isCollapsed ? 26 : 92, height: 5)
                .padding(.top, 8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(StudioTheme.Palette.hairline, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 18, y: 10)
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(StudioTheme.Palette.accent.opacity(0.9))
                    .frame(width: 4, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(StudioTheme.Typography.title(19))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            panelButton(systemName: isCollapsed ? "chevron.right" : "chevron.left", isActive: false, action: onToggleCollapse)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var panelBackground: LinearGradient {
        StudioTheme.Gradients.panel
    }

    private func panelButton(systemName: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isActive ? .white : .white.opacity(0.68))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isActive ? StudioTheme.Palette.accent : StudioTheme.Palette.cardFillStrong)
                )
        }
        .buttonStyle(.plain)
    }
}
