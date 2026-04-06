import SwiftUI
import UIKit

struct LayerThumbnailView: View {
    let snapshot: MetalLayerSnapshot?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.95, green: 0.94, blue: 0.90))

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)

            if let thumbnail = thumbnailImage {
                Image(uiImage: thumbnail)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFit()
                    .padding(3)
            }
        }
    }

    private var thumbnailImage: UIImage? {
        guard let data = snapshot?.thumbnailData else { return nil }
        return UIImage(data: data)
    }
}

struct PaperLayerEditor: View {
    @Binding var paperColor: Color
    @Binding var transparentPaper: Bool
    let language: AppLanguage

    private let swatches: [Color] = [
        Color(red: 0.93, green: 0.93, blue: 0.91),
        Color(red: 0.98, green: 0.97, blue: 0.93),
        Color(red: 0.90, green: 0.88, blue: 0.82),
        Color(red: 0.84, green: 0.89, blue: 0.95),
        Color(red: 0.95, green: 0.86, blue: 0.86),
        Color(red: 0.86, green: 0.92, blue: 0.84)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.localized("紙質"))
                .font(StudioTheme.Typography.title(18))
                .foregroundStyle(.white.opacity(0.94))

            Toggle(isOn: $transparentPaper) {
                Text(language.localized("透明な用紙"))
                    .font(StudioTheme.Typography.title(12))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .tint(StudioTheme.Palette.accentBright)

            ColorPicker(
                language.localized("用紙色"),
                selection: $paperColor,
                supportsOpacity: false
            )
            .disabled(transparentPaper)
            .opacity(transparentPaper ? 0.45 : 1.0)
            .font(StudioTheme.Typography.label(12))
            .foregroundStyle(.white.opacity(0.88))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 28), spacing: 8)], spacing: 8) {
                ForEach(Array(swatches.enumerated()), id: \.offset) { entry in
                    let color = entry.element
                    Button {
                        paperColor = color
                        transparentPaper = false
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.75), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .disabled(transparentPaper)
            .opacity(transparentPaper ? 0.45 : 1.0)
        }
        .padding(16)
        .frame(width: 260, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(StudioTheme.Palette.overlayBlack.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(StudioTheme.Palette.cardBorder, lineWidth: 1)
        )
    }
}

struct LayerReorderDropDelegate: DropDelegate {
    let targetLayerIndex: Int
    @Binding var draggedLayerIndex: Int?
    @Binding var dropTargetLayerIndex: Int?
    let moveAction: (Int, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedLayerIndex, draggedLayerIndex != targetLayerIndex else { return }
        dropTargetLayerIndex = targetLayerIndex
        moveAction(draggedLayerIndex, targetLayerIndex)
        self.draggedLayerIndex = targetLayerIndex
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedLayerIndex = nil
        dropTargetLayerIndex = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if dropTargetLayerIndex == targetLayerIndex {
            dropTargetLayerIndex = nil
        }
    }
}
