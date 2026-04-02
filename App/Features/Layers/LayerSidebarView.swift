import ComposableArchitecture
import SwiftUI
import UIKit

struct LayerSidebarView: View {
    let store: StoreOf<LayerSidebarFeature>
    let layerSnapshots: [MetalLayerSnapshot]
    var showsTitle = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if showsTitle {
                    Text("Layers")
                        .font(StudioTheme.Typography.title(26))
                        .foregroundStyle(.white.opacity(0.94))
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center) {
                        Text("\(store.layers.count) Layers")
                            .font(StudioTheme.Typography.title(18))
                            .foregroundStyle(.white.opacity(0.9))

                        Spacer()

                        Button {
                            store.send(.addLayerButtonTapped)
                        } label: {
                            Label("Add", systemImage: "plus")
                                .font(StudioTheme.Typography.label(12))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(StudioTheme.Palette.accent)
                                )
                        }
                        .buttonStyle(.plain)
                        .minimumHitTarget()
                    }

                    ForEach(store.layers) { layer in
                        let snapshot = layerSnapshots.first(where: { $0.index == layer.index })
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(StudioTheme.Palette.cardFillStrong)
                                .frame(width: 48, height: 48)
                                .overlay {
                                    LayerThumbnailView(
                                        snapshot: snapshot
                                    )
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }

                            VStack(alignment: .leading, spacing: 5) {
                                Text(layer.name)
                                    .font(StudioTheme.Typography.title(15))
                                    .foregroundStyle(.white.opacity(0.92))
                                Text("Opacity \(Int(layer.opacity * 100))%")
                                    .font(StudioTheme.Typography.mono(10))
                                    .foregroundStyle(.white.opacity(0.48))

                                HStack(spacing: 6) {
                                    capsuleTag(layer.visible ? "Visible" : "Hidden")
                                    capsuleTag(store.activeLayerIndex == layer.index ? "Active" : "Standby")
                                }
                            }

                            Spacer()

                            Button {
                                store.send(.visibilityButtonTapped(layer.index))
                            } label: {
                                Image(systemName: layer.visible ? "eye.fill" : "eye.slash.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(layer.visible ? .white.opacity(0.9) : .white.opacity(0.45))
                                    .frame(width: 30, height: 30)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(StudioTheme.Palette.cardFillStrong)
                                    )
                            }
                            .buttonStyle(.plain)
                            .minimumHitTarget()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(store.activeLayerIndex == layer.index ? StudioTheme.Palette.selectedFill : StudioTheme.Palette.cardFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(store.activeLayerIndex == layer.index ? StudioTheme.Palette.selectedBorder : StudioTheme.Palette.cardBorder, lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .onTapGesture {
                            store.send(.layerTapped(layer.index))
                        }
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func capsuleTag(_ title: String) -> some View {
        Text(title)
            .font(StudioTheme.Typography.mono(9))
            .foregroundStyle(.white.opacity(0.56))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(StudioTheme.Palette.cardFillStrong)
            )
    }
}

private struct LayerThumbnailView: View {
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
