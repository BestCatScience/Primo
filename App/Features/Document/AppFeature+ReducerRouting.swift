import ComposableArchitecture
import Foundation

extension AppIntegrationFeature {
    func handleNewCanvasFromImageFailed(
        state: inout State,
        message: String?
    ) {
        state.application.presentBanner(message)
    }

    func handleOpenDocumentFailed(
        state: inout State,
        message: String?
    ) {
        state.application.failHydration(
            message: message
        )
    }

    func handlePhotoImportFailed(
        state: inout State,
        message: String?
    ) {
        state.application.presentBanner(message)
    }
}
