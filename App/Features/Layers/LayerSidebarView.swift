import ComposableArchitecture
import SwiftUI

struct LayerSidebarView: View {
    let store: StoreOf<LayerSidebarFeature>
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
                        let buffer = store.layerBuffers.first(where: { $0.index == layer.index })
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(StudioTheme.Palette.cardFillStrong)
                                .frame(width: 48, height: 48)
                                .overlay {
                                    LayerThumbnailView(buffer: buffer)
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
    let buffer: LayerCanvasBuffer?

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard let buffer else { return }

                for stroke in buffer.strokes {
                    guard stroke.points.count > 1 else { continue }

                    var path = Path()
                    for (index, point) in stroke.points.enumerated() {
                        let mapped = CGPoint(
                            x: (point.point.x / 1152.0) * size.width,
                            y: (point.point.y / 1536.0) * size.height
                        )
                        if index == 0 {
                            path.move(to: mapped)
                        } else {
                            path.addLine(to: mapped)
                        }
                    }

                    let color = Color(cgColor: stroke.style.color).opacity(buffer.opacity * 0.9)
                    let lineWidth: CGFloat
                    let lineCap: CGLineCap
                    switch stroke.style.tipKind {
                    case .pencil:
                        lineWidth = max(0.5, stroke.style.radius * 0.16)
                        lineCap = .round
                    case .ink:
                        lineWidth = max(0.55, stroke.style.radius * 0.18)
                        lineCap = .round
                    case .oil:
                        lineWidth = max(0.7, stroke.style.radius * 0.24)
                        lineCap = .square
                    case .airbrush:
                        lineWidth = max(0.8, stroke.style.radius * 0.28)
                        lineCap = .round
                    }
                    context.stroke(
                        path,
                        with: .color(color),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: lineCap, lineJoin: .round)
                    )
                }
            }
        }
    }
}
