import ComposableArchitecture
import SwiftUI

struct LayerSidebarView: View {
    let store: StoreOf<LayerSidebarFeature>
    var showsTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if showsTitle {
                Text("Layers")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Spacer()
                    Button {
                        store.send(.addLayerButtonTapped)
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.black))
                    }
                }

                ForEach(store.layers) { layer in
                    let buffer = store.layerBuffers.first(where: { $0.index == layer.index })
                    HStack(spacing: 12) {
                        Button {
                            store.send(.visibilityButtonTapped(layer.index))
                        } label: {
                            Image(systemName: layer.visible ? "eye.fill" : "eye.slash.fill")
                                .foregroundStyle(layer.visible ? .black : .gray)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(layer.name)
                                .font(.headline)
                            Text("Opacity \(Int(layer.opacity * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(red: 0.97, green: 0.96, blue: 0.93))
                            .overlay {
                                LayerThumbnailView(buffer: buffer)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                            .frame(width: 46, height: 46)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(store.activeLayerIndex == layer.index ? Color(red: 0.90, green: 0.86, blue: 0.80) : Color.white.opacity(0.75))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onTapGesture {
                        store.send(.layerTapped(layer.index))
                    }
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
