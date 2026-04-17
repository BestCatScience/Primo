import ComposableArchitecture
import Foundation

extension AppFeature {
    func handleBootstrapPresentationLoaded(
        state: inout State,
        presentation: PaintDocumentPresentation
    ) {
        applyPresentation(presentation, state: &state)
        state.application.finishHydration()
        Self.startupLogger.debug("Bootstrap presentation applied; initial UI is ready")
    }

    func handleAutosaveRecoveryLoaded(
        state: inout State,
        items: [AutosaveRecoveryItem]
    ) {
        state.recovery.present(items: items)
    }

    func handleAutosaveRecoveryDismissed(state: inout State) {
        state.recovery.dismiss()
    }

    func handleHomeSectionSelected(
        state: inout State,
        section: HomeSidebarSection
    ) {
        state.application.selectHomeSection(section)
    }

    func handlePresentationLoaded(
        state: inout State,
        presentation: PaintDocumentPresentation
    ) {
        guard !state.canvas.isStrokeActive else { return }
        applyPresentation(presentation, state: &state)
        Self.startupLogger.debug("Full presentation applied")
    }

    func handleNewCanvasFromImageFailed(
        state: inout State,
        message: String
    ) {
        state.application.presentBanner(
            message.isEmpty ? state.application.appLanguage.localized("Could not create canvas from image") : message
        )
    }

    func handleBannerDismissed(state: inout State) {
        state.application.clearBanner()
    }

    func handleOpenDocumentFailed(
        state: inout State,
        message: String
    ) {
        state.application.finishHydration()
        state.application.presentBanner(
            message.isEmpty ? StudioStrings.openFailed(state.application.appLanguage) : message
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
