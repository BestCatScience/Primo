import ComposableArchitecture
import PrimoNanoBananaApplication

extension NanoBananaFeature {
    func coreReduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .task:
            return .merge(
                .run { [nanoBananaSettingsClient] send in
                    await send(.settingsLoaded(nanoBananaSettingsClient.load()))
                },
                .run { [nanoBananaCommerceClient] send in
                    await send(.commerceUpdated(await nanoBananaCommerceClient.prepare()))
                }
            )

        case let .settingsLoaded(settings):
            var sanitizedSettings = settings
            if sanitizedSettings.accessMode == .appManaged {
                sanitizedSettings.accessMode = .userAPIKey
            }
            state.settings = sanitizedSettings
            return .none

        case let .commerceUpdated(snapshot):
            state.commerce = snapshot
            return .none

        case let .prepareComposer(activeLayerIndex, hasSelection):
            state.prepareComposer(activeLayerIndex: activeLayerIndex, hasSelection: hasSelection)
            return .none

        case let .promptChanged(prompt):
            state.composer.prompt = prompt
            return .none

        case let .inputLayerIndexChanged(index):
            state.composer.inputLayerIndex = index
            return .none

        case let .editScopeChanged(scope):
            state.composer.editScope = scope
            return .none

        case let .outputModeChanged(mode):
            state.composer.outputMode = mode
            return .none

        case let .maskExpansionChanged(expansion):
            state.composer.maskSettings.expansion = expansion
            return .none

        case let .maskInversionChanged(isInverted):
            state.composer.maskSettings.isInverted = isInverted
            return .none

        case let .modelChanged(model):
            state.composer.model = model
            return .none

        case let .accessModeChanged(accessMode):
            state.accessMode = accessMode == .appManaged ? .userAPIKey : accessMode
            let updatedSettings = state.settings
            return .run { [nanoBananaSettingsClient] _ in
                nanoBananaSettingsClient.persist(updatedSettings)
            }

        case let .apiKeyChanged(apiKey):
            state.apiKey = apiKey
            let updatedSettings = state.settings
            return .run { [nanoBananaSettingsClient] _ in
                nanoBananaSettingsClient.persist(updatedSettings)
            }

        case let .sheetPresentationChanged(isPresented):
            state.isSheetPresented = isPresented
            return .none

        case let .paywallPresentationChanged(isPresented):
            state.isPaywallPresented = isPresented
            return .none

        case let .workspaceBottomPanelSectionChanged(section):
            state.workspaceBottomPanelSection = section
            return .none

        case let .workspaceBottomPanelCollapsedChanged(isCollapsed):
            state.workspaceBottomPanelCollapsed = isCollapsed
            return .none

        case let .generateButtonTapped(closeSheet):
            if state.accessMode == .appManaged, !state.commerce.isSubscriptionActive {
                state.isPaywallPresented = true
                return .none
            }
            if closeSheet {
                state.isSheetPresented = false
            }
            switch state.buildCommand(using: nanoBananaCommandBuilder) {
            case let .success(command):
                return .send(.delegate(.requestEdit(command)))
            case .failure(.promptRequired):
                return .none
            case .failure(.apiKeyRequired):
                return .none
            case .failure(.endpointRequired):
                return .none
            case .failure(.entitlementRequired):
                if state.accessMode == .appManaged {
                    state.isPaywallPresented = true
                }
                return .none
            }

        case .cancelGenerationTapped:
            return .send(.delegate(.cancelEdit))

        case let .retryJobTapped(jobID):
            guard let commandResult = state.retryCommand(for: jobID, using: nanoBananaCommandBuilder) else {
                return .none
            }
            switch commandResult {
            case let .success(command):
                return .send(.delegate(.requestEdit(command)))
            case .failure:
                return .none
            }

        case .regenerateTapped:
            guard let commandResult = state.regenerationCommand(using: nanoBananaCommandBuilder) else {
                return .none
            }
            switch commandResult {
            case let .success(command):
                return .send(.delegate(.requestEdit(command)))
            case .failure:
                return .none
            }

        case .purchasePrimaryProductTapped:
            return .run { [nanoBananaCommerceClient] send in
                await send(.commerceUpdated(await nanoBananaCommerceClient.purchasePrimaryProduct()))
            }

        case .restorePurchasesTapped:
            return .run { [nanoBananaCommerceClient] send in
                await send(.commerceUpdated(await nanoBananaCommerceClient.restorePurchases()))
            }

        case .purchaseErrorDismissed:
            return .run { [nanoBananaCommerceClient] send in
                await send(.commerceUpdated(await nanoBananaCommerceClient.clearPurchaseError()))
            }

        case let .historyItemSelected(descriptor):
            state.applyHistoryItem(descriptor)
            return .none

        case let .generationStarted(start):
            state.beginGeneration(
                descriptor: start.descriptor,
                jobID: start.jobID,
                createdAt: start.createdAt
            )
            return .none

        case let .generationApplied(applied):
            state.recordSucceededGeneration(
                preview: applied.preview,
                historyID: applied.historyID,
                createdAt: applied.createdAt
            )
            state.completeAppliedEdit(request: applied.preview.descriptor)
            return .none

        case let .generationFailedFeedback(feedback, language):
            if feedback == .nanoBananaGenerationCanceled {
                state.markCanceled(feedback: feedback, language: language)
            } else {
                state.markFailed(feedback: feedback, language: language)
            }
            return .none

        case .generationSucceeded, .generationFailed:
            return .none

        case .delegate:
            return .none
        }
    }
}
