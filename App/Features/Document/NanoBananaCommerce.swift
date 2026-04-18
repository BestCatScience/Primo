import ComposableArchitecture
import Foundation
import StoreKit

struct NanoBananaSettings: Equatable, Sendable {
    var accessMode: NanoBananaAccessMode = .userAPIKey
    var apiKey = ""
}

struct NanoBananaSettingsClient: Sendable {
    var load: @Sendable () -> NanoBananaSettings
    var persist: @Sendable (NanoBananaSettings) -> Void

    static let accessModeStorageKey = "primo.nanobanana.accessMode"
    static let apiKeyStorageKey = "primo.nanobanana.apiKey"

    static func live(keyValueStoreClient: KeyValueStoreClient) -> NanoBananaSettingsClient {
        NanoBananaSettingsClient(
            load: {
                let rawAccessMode = keyValueStoreClient.stringForKey(Self.accessModeStorageKey)
                let accessMode = rawAccessMode.flatMap(NanoBananaAccessMode.init(rawValue:)) ?? .userAPIKey
                let apiKey = keyValueStoreClient.stringForKey(Self.apiKeyStorageKey) ?? ""
                return NanoBananaSettings(
                    accessMode: accessMode,
                    apiKey: apiKey
                )
            },
            persist: { settings in
                keyValueStoreClient.setString(settings.accessMode.rawValue, Self.accessModeStorageKey)
                keyValueStoreClient.setString(settings.apiKey, Self.apiKeyStorageKey)
            }
        )
    }
}

private enum NanoBananaSettingsClientKey: DependencyKey {
    static var liveValue: NanoBananaSettingsClient {
        @Dependency(\.keyValueStoreClient) var keyValueStoreClient
        return NanoBananaSettingsClient.live(keyValueStoreClient: keyValueStoreClient)
    }
}

struct NanoBananaCommerceSnapshot: Equatable, Sendable {
    struct ProductSummary: Equatable, Sendable {
        var id: String
        var displayName: String
        var displayPrice: String
    }

    var primaryProduct: ProductSummary?
    var isLoading = false
    var isSubscriptionActive = false
    var latestEntitlementJWS = ""
    var purchaseErrorMessage: String?
    var manageSubscriptionsURL: URL? = URL(string: "https://apps.apple.com/account/subscriptions")
    var proxyEndpoint = ""
}

struct NanoBananaCommerceClient: Sendable {
    var prepare: @Sendable () async -> NanoBananaCommerceSnapshot
    var purchasePrimaryProduct: @Sendable () async -> NanoBananaCommerceSnapshot
    var restorePurchases: @Sendable () async -> NanoBananaCommerceSnapshot
    var clearPurchaseError: @Sendable () async -> NanoBananaCommerceSnapshot

    static func live() -> NanoBananaCommerceClient {
        let store = NanoBananaCommerceStore()
        return NanoBananaCommerceClient(
            prepare: {
                await store.prepare()
            },
            purchasePrimaryProduct: {
                await store.purchasePrimaryProduct()
            },
            restorePurchases: {
                await store.restorePurchases()
            },
            clearPurchaseError: {
                await store.clearPurchaseError()
            }
        )
    }
}

private enum NanoBananaCommerceClientKey: DependencyKey {
    static let liveValue = NanoBananaCommerceClient.live()
}

extension DependencyValues {
    var nanoBananaSettingsClient: NanoBananaSettingsClient {
        get { self[NanoBananaSettingsClientKey.self] }
        set { self[NanoBananaSettingsClientKey.self] = newValue }
    }

    var nanoBananaCommerceClient: NanoBananaCommerceClient {
        get { self[NanoBananaCommerceClientKey.self] }
        set { self[NanoBananaCommerceClientKey.self] = newValue }
    }
}

private actor NanoBananaCommerceStore {
    static let monthlyProductID = "com.bestcatscience.primo.nanobanana.monthly"

    private var products: [Product] = []
    private var isLoading = false
    private var isSubscriptionActive = false
    private var latestEntitlementJWS = ""
    private var purchaseErrorMessage: String?
    private var transactionUpdatesTask: Task<Void, Never>?
    private let proxyEndpoint: String

    init(bundle: Bundle = .main) {
        self.proxyEndpoint = (bundle.object(forInfoDictionaryKey: "NanoBananaProxyEndpoint") as? String) ?? ""
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func prepare() async -> NanoBananaCommerceSnapshot {
        startObservingTransactionsIfNeeded()
        if products.isEmpty {
            await loadProducts()
        }
        await refreshEntitlements()
        return snapshot()
    }

    func purchasePrimaryProduct() async -> NanoBananaCommerceSnapshot {
        guard let product = products.first else {
            purchaseErrorMessage = "Subscription product is unavailable."
            return snapshot()
        }

        isLoading = true
        purchaseErrorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    purchaseErrorMessage = "Purchase verification failed."
                    return snapshot()
                }
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }

        return snapshot()
    }

    func restorePurchases() async -> NanoBananaCommerceSnapshot {
        isLoading = true
        purchaseErrorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }

        return snapshot()
    }

    func clearPurchaseError() -> NanoBananaCommerceSnapshot {
        purchaseErrorMessage = nil
        return snapshot()
    }

    private func loadProducts() async {
        isLoading = true
        purchaseErrorMessage = nil
        defer { isLoading = false }

        do {
            products = try await Product.products(for: [Self.monthlyProductID])
                .sorted { $0.displayName < $1.displayName }
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        var active = false
        var latestJWS = ""

        for await result in Transaction.currentEntitlements {
            let entitlementJWS = result.jwsRepresentation
            guard case let .verified(transaction) = result else { continue }
            guard transaction.productID == Self.monthlyProductID else { continue }
            guard transaction.revocationDate == nil else { continue }

            active = true
            latestJWS = entitlementJWS
        }

        isSubscriptionActive = active
        latestEntitlementJWS = latestJWS
    }

    private func startObservingTransactionsIfNeeded() {
        guard transactionUpdatesTask == nil else { return }
        transactionUpdatesTask = Task { [self] in
            for await result in Transaction.updates {
                if case let .verified(transaction) = result {
                    await transaction.finish()
                }
                await refreshEntitlements()
            }
        }
    }

    private func snapshot() -> NanoBananaCommerceSnapshot {
        NanoBananaCommerceSnapshot(
            primaryProduct: products.first.map {
                NanoBananaCommerceSnapshot.ProductSummary(
                    id: $0.id,
                    displayName: $0.displayName,
                    displayPrice: $0.displayPrice
                )
            },
            isLoading: isLoading,
            isSubscriptionActive: isSubscriptionActive,
            latestEntitlementJWS: latestEntitlementJWS,
            purchaseErrorMessage: purchaseErrorMessage,
            manageSubscriptionsURL: URL(string: "https://apps.apple.com/account/subscriptions"),
            proxyEndpoint: proxyEndpoint
        )
    }
}

@Reducer
struct NanoBananaFeature {
    enum WorkspaceBottomPanelSection: Hashable, Equatable {
        case nanoBanana
        case history
        case output
    }

    struct ComposerState: Equatable {
        var prompt = ""
        var inputLayerIndex = 0
        var editScope: NanoBananaEditScope = .wholeLayer
        var outputMode: NanoBananaOutputMode = .replaceCurrentLayer
        var maskSettings = NanoBananaMaskSettings()
        var model: NanoBananaModel = .flashImage25
    }

    @ObservableState
    struct State: Equatable {
        var composer = ComposerState()
        var settings = NanoBananaSettings()
        var commerce = NanoBananaCommerceSnapshot()
        var isGenerating = false
        var jobs: [NanoBananaJob] = []
        var history: [NanoBananaHistoryItem] = []
        var pendingRequest: NanoBananaGenerationRequest?
        var activeJobID: UUID?
        var isSheetPresented = false
        var isPaywallPresented = false
        var workspaceBottomPanelSection: WorkspaceBottomPanelSection = .nanoBanana
        var workspaceBottomPanelCollapsed = false

        var progress: Double? {
            guard isGenerating else { return nil }
            return 0.6
        }

        var apiKey: String {
            get { settings.apiKey }
            set { settings.apiKey = newValue }
        }

        var accessMode: NanoBananaAccessMode {
            get { settings.accessMode }
            set { settings.accessMode = newValue }
        }

        var generateDisabled: Bool {
            isGenerating ||
            composer.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            (
                accessMode == .userAPIKey
                ? apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                : commerce.proxyEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }

        mutating func prepareComposer(
            activeLayerIndex: Int,
            hasSelection: Bool
        ) {
            composer.prompt = ""
            composer.inputLayerIndex = activeLayerIndex
            composer.editScope = hasSelection ? .selectedArea : .wholeLayer
            composer.outputMode = .replaceCurrentLayer
            composer.maskSettings = .init()
            composer.model = .flashImage25
            workspaceBottomPanelSection = .nanoBanana
            workspaceBottomPanelCollapsed = false
        }

        mutating func applyHistoryItem(_ request: NanoBananaGenerationRequest) {
            composer.prompt = request.prompt
            composer.inputLayerIndex = request.inputLayerIndex
            composer.editScope = request.editScope
            composer.outputMode = request.outputMode
            composer.maskSettings = request.maskSettings
            composer.model = request.model
            workspaceBottomPanelSection = .nanoBanana
        }

        func buildGenerationRequest() -> NanoBananaGenerationRequest {
            NanoBananaGenerationRequest(
                prompt: composer.prompt,
                config: NanoBananaRequestConfig(
                    accessMode: accessMode,
                    credential: accessMode == .userAPIKey ? apiKey : commerce.latestEntitlementJWS,
                    endpoint: commerce.proxyEndpoint
                ),
                model: composer.model,
                inputLayerIndex: composer.inputLayerIndex,
                editScope: composer.editScope,
                outputMode: composer.outputMode,
                maskSettings: composer.maskSettings
            )
        }

        mutating func beginGeneration(
            request: NanoBananaGenerationRequest,
            jobID: UUID,
            createdAt: Date
        ) {
            isGenerating = true
            pendingRequest = request
            activeJobID = jobID
            jobs.insert(
                NanoBananaJob(
                    id: jobID,
                    request: request,
                    createdAt: createdAt,
                    status: .running,
                    message: nil
                ),
                at: 0
            )
            jobs = Array(jobs.prefix(12))
        }

        func regenerationRequest() -> NanoBananaGenerationRequest? {
            pendingRequest
        }

        func retryRequest(for jobID: UUID) -> NanoBananaGenerationRequest? {
            jobs.first(where: { $0.id == jobID })?.request
        }

        mutating func recordSucceededGeneration(
            preview: NanoBananaPreviewState,
            historyID: UUID,
            createdAt: Date
        ) {
            isGenerating = false
            history.insert(
                NanoBananaHistoryItem(
                    id: historyID,
                    request: preview.request,
                    createdAt: createdAt,
                    previewImageData: preview.afterPreviewImageData
                ),
                at: 0
            )
            history = Array(history.prefix(12))
            if let activeJobID,
               let jobIndex = jobs.firstIndex(where: { $0.id == activeJobID }) {
                jobs[jobIndex].status = .succeeded
                jobs[jobIndex].message = nil
            }
        }

        mutating func completeAppliedEdit(request: NanoBananaGenerationRequest) {
            pendingRequest = request
            activeJobID = nil
        }

        mutating func markFailed(
            feedback: AppFeature.ApplicationFeedback,
            language: AppLanguage
        ) {
            let message = feedback.message(for: language)
            isGenerating = false
            if let activeJobID,
               let jobIndex = jobs.firstIndex(where: { $0.id == activeJobID }) {
                jobs[jobIndex].status = .failed
                jobs[jobIndex].message = message
            }
        }

        mutating func markCanceled(
            feedback: AppFeature.ApplicationFeedback,
            language: AppLanguage
        ) {
            let message = feedback.message(for: language)
            isGenerating = false
            if let activeJobID,
               let jobIndex = jobs.firstIndex(where: { $0.id == activeJobID }) {
                jobs[jobIndex].status = .canceled
                jobs[jobIndex].message = message
            }
        }
    }

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
        case historyItemSelected(NanoBananaGenerationRequest)
        case generationSucceeded(NanoBananaPreviewState)
        case generationFailed(AppFeature.ApplicationFeedback)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case requestEdit(NanoBananaGenerationRequest)
        case cancelEdit
    }

    @Dependency(\.nanoBananaSettingsClient) var nanoBananaSettingsClient
    @Dependency(\.nanoBananaCommerceClient) var nanoBananaCommerceClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
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
                return .send(
                    .delegate(
                        .requestEdit(
                            state.buildGenerationRequest()
                        )
                    )
                )

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
}
