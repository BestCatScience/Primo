import ComposableArchitecture
import PrimoDocumentEngineInfrastructure
import SwiftUI

@main
struct PrimoApp: App {
    let store: StoreOf<PrimoRootFeature>

    init() {
        let documentRuntimeComposition = DocumentRuntimeCompositionFactory.live()
        self.store = Store(initialState: PrimoRootFeature.State()) {
            PrimoRootFeature()
        } withDependencies: {
            $0.documentRuntimeComposition = documentRuntimeComposition
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .statusBarHidden(true)
        }
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    store.send(.document(.lifecycle(.undoRequested)))
                }
                .keyboardShortcut("z", modifiers: .command)

                Button("Redo") {
                    store.send(.document(.lifecycle(.redoRequested)))
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
