import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        HStack(spacing: 0) {
            BrushPaletteView(
                store: store.scope(
                    state: \.brushPalette,
                    action: { .brushPalette($0) }
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
                        action: { .canvas($0) }
                    )
                )
                .padding(28)
            }

            LayerSidebarView(
                store: store.scope(
                    state: \.layerSidebar,
                    action: { .layerSidebar($0) }
                )
            )
            .frame(width: 300)
        }
        .task {
            await store.send(.task).finish()
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
