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
