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
        state.application.failHydration(
            message: feedback.message(for: state.application.appLanguage)
        )
    }

    func handlePhotoImportFailed(
        state: inout State,
        feedback: ApplicationFeedback
    ) {
        state.application.presentFeedback(feedback)
    }
}
