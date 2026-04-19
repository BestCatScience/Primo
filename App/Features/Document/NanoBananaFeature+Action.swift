import Foundation
import PrimoNanoBananaDomain

extension NanoBananaFeature {
    enum Action: Equatable {
        case task
        case settingsLoaded(NanoBananaSettings)
        case commerceUpdated(NanoBananaCommerceSnapshot)
        case prepareComposer(activeLayerIndex: Int, hasSelection: Bool)
        case promptChanged(String)
        case inputLayerIndexChanged(Int)
        case editScopeChanged(NanoBananaEditScope)
        case outputModeChanged(NanoBananaOutputMode)
        case maskExpansionChanged(Int)
        case maskInversionChanged(Bool)
        case modelChanged(NanoBananaModel)
        case accessModeChanged(NanoBananaAccessMode)
        case apiKeyChanged(String)
        case sheetPresentationChanged(Bool)
        case paywallPresentationChanged(Bool)
        case workspaceBottomPanelSectionChanged(WorkspaceBottomPanelSection)
        case workspaceBottomPanelCollapsedChanged(Bool)
        case generateButtonTapped(closeSheet: Bool)
        case cancelGenerationTapped
        case retryJobTapped(UUID)
        case regenerateTapped
        case purchasePrimaryProductTapped
        case restorePurchasesTapped
        case purchaseErrorDismissed
        case historyItemSelected(NanoBananaEditDescriptor)
        case generationSucceeded(NanoBananaPreviewState)
        case generationFailed(AppFeature.ApplicationFeedback)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case requestEdit(SubmitNanoBananaEditCommand)
        case cancelEdit
    }
}
