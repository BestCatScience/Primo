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

let studioTools: [StudioToolKind] = [.brush, .erase, .fill, .eyedropper, .select, .move, .shape]

struct StudioPanelShell<Content: View>: View {
    let title: String
    let language: AppLanguage
    let side: StudioPanelSide
    let isCollapsed: Bool
    let isStacked: Bool
    let onToggleCollapse: () -> Void
    let onToggleStack: () -> Void
    let onSwapStackOrder: () -> Void
    let onDragEnded: (CGSize) -> Void
    let content: Content

    @State private var dragOffset: CGSize = .zero
    @GestureState private var isDragging = false

    init(
        title: String,
        language: AppLanguage,
        side: StudioPanelSide,
        isCollapsed: Bool,
        isStacked: Bool,
        onToggleCollapse: @escaping () -> Void,
        onToggleStack: @escaping () -> Void,
        onSwapStackOrder: @escaping () -> Void,
        onDragEnded: @escaping (CGSize) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.language = language
        self.side = side
        self.isCollapsed = isCollapsed
        self.isStacked = isStacked
        self.onToggleCollapse = onToggleCollapse
        self.onToggleStack = onToggleStack
        self.onSwapStackOrder = onSwapStackOrder
        self.onDragEnded = onDragEnded
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
        .overlay(alignment: .topTrailing) {
            if isDragging {
                dragBadge
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                    .transition(.scale.combined(with: .opacity))
            }
        }
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
        .offset(dragOffset)
        .scaleEffect(isDragging ? 1.015 : 1.0)
        .rotationEffect(.degrees(Double(dragOffset.width / 42)))
        .shadow(color: Color.black.opacity(0.22), radius: 18, y: 10)
        .shadow(color: StudioTheme.Palette.accent.opacity(isDragging ? 0.18 : 0.0), radius: 20, y: 10)
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: dragOffset)
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: isDragging)
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

                    Text(
                        isStacked
                        ? language.localized(japanese: "左右ドラッグで移動、上下ドラッグで並び替え", english: "Drag sideways to move, up/down to reorder")
                        : language.localized(japanese: "左右ドラッグで移動", english: "Drag sideways to move")
                    )
                    .font(StudioTheme.Typography.mono(10))
                    .foregroundStyle(StudioTheme.Palette.textMuted)
                    .lineLimit(1)
                }
            }

            if !isCollapsed {
                Spacer(minLength: 6)

                HStack(spacing: 6) {
                    panelButton(systemName: isStacked ? "square.split.2x1" : "square.split.1x2", isActive: isStacked, action: onToggleStack)
                    if isStacked {
                        panelButton(systemName: "arrow.up.arrow.down", isActive: false, action: onSwapStackOrder)
                    }
                }
            }

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
        .gesture(panelDragGesture)
    }

    private var panelBackground: LinearGradient {
        StudioTheme.Gradients.panel
    }

    private var dragBadge: some View {
        Text(
            side == .leading
            ? language.localized(japanese: "右レールへ移動", english: "Drop to right rail")
            : language.localized(japanese: "左レールへ移動", english: "Drop to left rail")
        )
        .font(StudioTheme.Typography.mono(10))
        .foregroundStyle(.white.opacity(0.82))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
    }

    private var panelDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                dragOffset = .zero
                onDragEnded(value.translation)
            }
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
