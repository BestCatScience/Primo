import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleNewCanvasFromImageFailed(
        state: inout State,
        message: String
    ) {
        state.application.presentFeedback(
            .couldNotCreateCanvasFromImage(message.isEmpty ? nil : message)
        )
    }

    func handleOpenDocumentFailed(
        state: inout State,
        message: String
    ) {
        state.application.failHydration(
            feedback: .openFailed(message.isEmpty ? nil : message)
        )
    }

    func handlePhotoImportFailed(
        state: inout State,
        message: String
    ) {
        state.application.presentFeedback(
            .couldNotImportPhoto(message.isEmpty ? nil : message)
        )
    }
}
