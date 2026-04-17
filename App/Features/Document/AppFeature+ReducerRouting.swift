import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleNewCanvasFromImageFailed(
        state: inout State,
        feedback: ApplicationFeedback
    ) {
        state.application.presentFeedback(feedback)
    }

    func handleOpenDocumentFailed(
        state: inout State,
        feedback: ApplicationFeedback
    ) {
        state.application.failHydration(feedback: feedback)
    }

    func handlePhotoImportFailed(
        state: inout State,
        feedback: ApplicationFeedback
    ) {
        state.application.presentFeedback(feedback)
    }
}
