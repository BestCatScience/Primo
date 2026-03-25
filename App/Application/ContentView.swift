import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        HStack(spacing: 0) {
            BrushPaletteView(
                store: store.scope(
                    state: \.brushPalette,
                    action: \.brushPalette
                )
            )
            .frame(width: 280)

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.84, green: 0.86, blue: 0.82),
                        Color(red: 0.76, green: 0.77, blue: 0.73)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                CanvasView(
                    store: store.scope(
                        state: \.canvas,
                        action: \.canvas
                    )
                )
                .padding(28)

                if store.isHydrating {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Preparing studio...")
                            .font(.headline)
                            .foregroundStyle(Color.black.opacity(0.7))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }

            LayerSidebarView(
                store: store.scope(
                    state: \.layerSidebar,
                    action: \.layerSidebar
                )
            )
            .frame(width: 300)
        }
        .task {
            store.send(.task)
        }
    }
}

#Preview {
    ContentView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
