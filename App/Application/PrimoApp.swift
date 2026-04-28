import ComposableArchitecture
import SwiftUI

@main
struct PrimoApp: App {
    let store = Store(initialState: PrimoRootFeature.State()) {
        PrimoRootFeature()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .statusBarHidden(true)
        }
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    store.send(.document(.undoRequested))
                }
                .keyboardShortcut("z", modifiers: .command)

                Button("Redo") {
                    store.send(.document(.redoRequested))
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }

            CommandGroup(after: .saveItem) {
                Button("Save") {
                    store.send(.importExport(.saveDocumentRequested))
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Save As") {
                    store.send(.importExport(.saveDocumentCopyRequested))
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])

                Button("Save History") {
                    store.send(.importExport(.saveHistoryRequested))
                }
            }
        }
    }
}
