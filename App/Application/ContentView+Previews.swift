import ComposableArchitecture
import SwiftUI

#Preview {
    ContentView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
