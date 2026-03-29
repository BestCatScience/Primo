import ComposableArchitecture
import SwiftUI

struct LayerSidebarView: View {
    let store: StoreOf<LayerSidebarFeature>
    var showsTitle = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                if showsTitle {
                    Text("Layers")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.94))
                }

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("STACK")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                            Text("\(store.layers.count) Layers")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                        }

                        Spacer()

                        Button {
                            store.send(.addLayerButtonTapped)
                        } label: {
                            Label("Add", systemImage: "plus")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(red: 0.89, green: 0.45, blue: 0.24))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(store.layers) { layer in
                        let buffer = store.layerBuffers.first(where: { $0.index == layer.index })
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 56, height: 56)
                                .overlay {
                                    LayerThumbnailView(buffer: buffer)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }

                            VStack(alignment: .leading, spacing: 5) {
                                Text(layer.name)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.92))
                                Text("Opacity \(Int(layer.opacity * 100))%")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.48))

                                HStack(spacing: 8) {
                                    capsuleTag(layer.visible ? "Visible" : "Hidden")
                                    capsuleTag(store.activeLayerIndex == layer.index ? "Active" : "Standby")
                                }
                            }

                            Spacer()

                            Button {
                                store.send(.visibilityButtonTapped(layer.index))
                            } label: {
                                Image(systemName: layer.visible ? "eye.fill" : "eye.slash.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(layer.visible ? .white.opacity(0.9) : .white.opacity(0.45))
                                    .frame(width: 34, height: 34)
                                    .background(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .fill(Color.white.opacity(0.06))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(store.activeLayerIndex == layer.index ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(store.activeLayerIndex == layer.index ? Color(red: 0.96, green: 0.62, blue: 0.31).opacity(0.55) : Color.white.opacity(0.05), lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(.white.opacity(0.56))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.06))
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
                    context.stroke(
                        path,
                        with: .color(color),
                        style: StrokeStyle(lineWidth: max(0.6, stroke.style.radius * 0.18), lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
    }
}
