import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleNewCanvasFromImageFailed(
        state: inout State,
        message: String
    ) {
        state.application.presentBanner(
            message.isEmpty ? state.application.appLanguage.localized("Could not create canvas from image") : message
        )
    }

    func handleOpenDocumentFailed(
        state: inout State,
        message: String
    ) {
        state.application.failHydration(
            message: message.isEmpty ? StudioStrings.openFailed(state.application.appLanguage) : message
        )
    }

    func handlePhotoImportFailed(
        state: inout State,
        message: String
    ) {
        state.application.presentBanner(
            message.isEmpty ? state.application.appLanguage.localized("Could not import photo") : message
        )
    }
}
