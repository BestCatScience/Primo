import ComposableArchitecture

extension NanoBananaFeature {
    func reduce(
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
            state.settings = settings
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
            state.accessMode = accessMode
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
            return .send(.delegate(.requestEdit(state.buildGenerationRequest())))

        case .cancelGenerationTapped:
            return .send(.delegate(.cancelEdit))

        case let .retryJobTapped(jobID):
            guard let request = state.retryRequest(for: jobID) else {
                return .none
            }
            return .send(.delegate(.requestEdit(request)))

        case .regenerateTapped:
            guard let request = state.regenerationRequest() else {
                return .none
            }
            return .send(.delegate(.requestEdit(request)))

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

        case let .historyItemSelected(request):
            state.applyHistoryItem(request)
            return .none

        case .generationSucceeded, .generationFailed:
            return .none

        case .delegate:
            return .none
        }
    }
}
