import ComposableArchitecture
import SwiftUI

@main
struct AtelierPrimeApp: App {
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .statusBarHidden(true)
        }
    }
}
