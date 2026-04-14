import ComposableArchitecture
import SwiftUI

@main
struct PrimoApp: App {
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .statusBarHidden(true)
        }
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    store.send(.undoRequested)
                }
                .keyboardShortcut("z", modifiers: .command)

                Button("Redo") {
                    store.send(.redoRequested)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }

            CommandGroup(after: .saveItem) {
                Button("Save") {
                    store.send(.saveDocumentRequested)
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
    }
}
