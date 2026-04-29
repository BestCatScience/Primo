import Foundation
import PrimoAIImageDomain

extension AIImageFeature {
    enum Action: Equatable {
        case task
        case settingsLoaded(AIImageSettings)
        case commerceUpdated(AIImageCommerceSnapshot)
        case prepareComposer(activeLayerIndex: Int, hasSelection: Bool)
        case promptChanged(String)
        case inputLayerIndexChanged(Int)
        case editScopeChanged(AIImageEditScope)
        case outputModeChanged(AIImageOutputMode)
        case maskExpansionChanged(Int)
        case maskInversionChanged(Bool)
        case modelChanged(AIImageModel)
        case accessModeChanged(AIImageAccessMode)
        case apiKeyChanged(String)
        case openAIAPIKeyChanged(String)
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
        case historyItemSelected(AIImageEditDescriptor)
        case generationStarted(DocumentFeature.AIImageGenerationStart)
        case generationApplied(DocumentFeature.AIImageAppliedEdit)
        case generationFailedFeedback(ApplicationFeature.Feedback, AppLanguage)
        case generationSucceeded(AIImagePreviewState)
        case generationFailed(ApplicationFeature.Feedback)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case requestEdit(SubmitAIImageEditCommand)
        case cancelEdit
    }
}
