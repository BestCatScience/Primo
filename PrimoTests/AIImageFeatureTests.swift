import ComposableArchitecture
@testable import Primo
import PrimoAIImageApplication
import PrimoAIImageDomain
import PrimoAIImageInfrastructure
import XCTest

@MainActor
final class AIImageFeatureTests: XCTestCase {
    func testTaskLoadsSettingsAndCommerceSnapshot() async {
        let snapshot = AIImageCommerceSnapshot(
            primaryProduct: .init(
                id: "monthly",
                displayName: "Monthly",
                displayPrice: "$4.99"
            ),
            isSubscriptionActive: true,
            latestEntitlementJWS: "signed-jws",
            proxyEndpoint: "https://proxy.bestcatscience.com/edit"
        )

        let store = TestStore(initialState: AIImageFeature.State()) {
            AIImageFeature()
        } withDependencies: {
            $0.aiImageSettingsClient = AIImageSettingsClient(
                load: { AIImageSettings(accessMode: .appManaged, apiKey: "persisted-key") },
                persist: { _ in }
            )
            $0.aiImageCommerceClient = AIImageCommerceClient(
                prepare: { snapshot },
                purchasePrimaryProduct: { snapshot },
                restorePurchases: { snapshot },
                clearPurchaseError: { snapshot }
            )
            $0.aiImageCommandBuilder = AIImageCommandBuilder()
        }

        await store.send(.task)
        await store.receive(.settingsLoaded(AIImageSettings(accessMode: .appManaged, apiKey: "persisted-key"))) {
            $0.settings = AIImageSettings(accessMode: .appManaged, apiKey: "persisted-key")
        }
        await store.receive(.commerceUpdated(snapshot)) {
            $0.commerce = snapshot
        }
    }

    func testTaskFallsBackToUserAPIKeyWhenProxyEndpointIsMissing() async {
        let snapshot = AIImageCommerceSnapshot(
            isSubscriptionActive: true,
            latestEntitlementJWS: "signed-jws",
            proxyEndpoint: ""
        )

        let store = TestStore(initialState: AIImageFeature.State()) {
            AIImageFeature()
        } withDependencies: {
            $0.aiImageSettingsClient = AIImageSettingsClient(
                load: { AIImageSettings(accessMode: .appManaged, apiKey: "persisted-key") },
                persist: { _ in }
            )
            $0.aiImageCommerceClient = AIImageCommerceClient(
                prepare: { snapshot },
                purchasePrimaryProduct: { snapshot },
                restorePurchases: { snapshot },
                clearPurchaseError: { snapshot }
            )
        }

        await store.send(.task)
        await store.receive(.settingsLoaded(AIImageSettings(accessMode: .appManaged, apiKey: "persisted-key"))) {
            $0.settings = AIImageSettings(accessMode: .appManaged, apiKey: "persisted-key")
        }
        await store.receive(.commerceUpdated(snapshot)) {
            $0.commerce = snapshot
            $0.accessMode = .userAPIKey
        }
    }

    func testAccessModeChangedFallsBackWhenProxyEndpointIsMissing() async {
        var initialState = AIImageFeature.State(
            settings: AIImageSettings(accessMode: .userAPIKey, apiKey: "user-key"),
            commerce: AIImageCommerceSnapshot(proxyEndpoint: "")
        )
        initialState.composer.prompt = "Enhance linework"

        let store = TestStore(initialState: initialState) {
            AIImageFeature()
        } withDependencies: {
            $0.aiImageSettingsClient = AIImageSettingsClient(
                load: { AIImageSettings() },
                persist: { settings in
                    XCTAssertEqual(settings.accessMode, .userAPIKey)
                }
            )
        }

        await store.send(.accessModeChanged(.appManaged))
    }

    func testAccessModeChangedAllowsAppManagedWhenProxyEndpointIsConfigured() async {
        var initialState = AIImageFeature.State(
            settings: AIImageSettings(accessMode: .userAPIKey, apiKey: "user-key"),
            commerce: AIImageCommerceSnapshot(proxyEndpoint: "https://proxy.bestcatscience.com/edit")
        )
        initialState.composer.prompt = "Enhance linework"

        let store = TestStore(initialState: initialState) {
            AIImageFeature()
        } withDependencies: {
            $0.aiImageSettingsClient = AIImageSettingsClient(
                load: { AIImageSettings() },
                persist: { settings in
                    XCTAssertEqual(settings.accessMode, .appManaged)
                }
            )
        }

        await store.send(.accessModeChanged(.appManaged)) {
            $0.accessMode = .appManaged
        }
    }

    func testGenerateShowsPaywallWhenAppManagedIsInactive() async {
        var initialState = AIImageFeature.State()
        initialState.settings = AIImageSettings(accessMode: .appManaged, apiKey: "")
        initialState.commerce = AIImageCommerceSnapshot(
            isSubscriptionActive: false,
            proxyEndpoint: "https://proxy.bestcatscience.com/edit"
        )

        let store = TestStore(initialState: initialState) {
            AIImageFeature()
        }

        store.exhaustivity = .off

        await store.send(.generateButtonTapped(closeSheet: false)) {
            $0.isPaywallPresented = true
        }
    }

    func testGenerateDelegatesRequestWhenConfigured() async {
        var initialState = AIImageFeature.State(
            settings: AIImageSettings(accessMode: .userAPIKey, apiKey: "user-key"),
            commerce: AIImageCommerceSnapshot(proxyEndpoint: "https://proxy.bestcatscience.com/edit")
        )
        initialState.composer.prompt = "Enhance linework"
        initialState.composer.inputLayerIndex = 3
        initialState.composer.editScope = .selectedArea
        initialState.composer.outputMode = .newLayer
        initialState.composer.maskSettings = .init(expansion: 8, isInverted: true)
        initialState.composer.model = .flashImage31Preview
        initialState.isSheetPresented = true

        let expectedRequest = SubmitAIImageEditCommand(
            descriptor: AIImageEditDescriptor(
                prompt: NonEmptyPrompt("Enhance linework")!,
                accessMode: .userAPIKey,
                model: .flashImage31Preview,
                inputLayerIndex: 3,
                editScope: .selectedArea,
                outputMode: .newLayer,
                maskSettings: .init(expansion: 8, isInverted: true)
            ),
            executionConfig: .userAPIKey(apiKey: AIImageAPIKey("user-key")!)
        )

        let store = TestStore(initialState: initialState) {
            AIImageFeature()
        } withDependencies: {
            $0.aiImageCommandBuilder = AIImageCommandBuilder()
        }

        await store.send(.generateButtonTapped(closeSheet: true)) {
            $0.isSheetPresented = false
        }
        await store.receive(.delegate(.requestEdit(expectedRequest)))
    }

    func testAIImageGenerateDelegatesOpenAIRequestWithOpenAIKey() async {
        var initialState = AIImageFeature.State(
            settings: AIImageSettings(
                accessMode: .userAPIKey,
                apiKey: "gemini-key",
                openAIAPIKey: "openai-key"
            ),
            commerce: AIImageCommerceSnapshot(proxyEndpoint: "https://proxy.bestcatscience.com/edit")
        )
        initialState.composer.prompt = "Improve lettering"
        initialState.composer.model = AIImageModel.defaultOpenAIDirectEditModel

        let expectedRequest = SubmitAIImageEditCommand(
            descriptor: AIImageEditDescriptor(
                prompt: NonEmptyPrompt("Improve lettering")!,
                accessMode: .userAPIKey,
                model: AIImageModel.defaultOpenAIDirectEditModel,
                inputLayerIndex: 0,
                editScope: .wholeLayer,
                outputMode: .replaceCurrentLayer
            ),
            executionConfig: .userAPIKey(apiKey: AIImageAPIKey("openai-key")!)
        )

        let store = TestStore(initialState: initialState) {
            AIImageFeature()
        } withDependencies: {
            $0.aiImageCommandBuilder = AIImageCommandBuilder()
        }

        await store.send(.generateButtonTapped(closeSheet: false))
        await store.receive(.delegate(.requestEdit(expectedRequest)))
    }

    func testGenerateDisabledUsesSelectedProviderAPIKey() {
        var state = AIImageFeature.State(
            settings: AIImageSettings(
                accessMode: .userAPIKey,
                apiKey: "gemini-key",
                openAIAPIKey: ""
            )
        )
        state.composer.prompt = "Improve lettering"
        state.composer.model = AIImageModel.defaultOpenAIDirectEditModel
        XCTAssertTrue(state.generateDisabled)

        state.openAIAPIKey = "openai-key"
        XCTAssertFalse(state.generateDisabled)
    }

    func testGenerateAllowsConfiguredGPTImage2ForDirectOpenAI() {
        var state = AIImageFeature.State(
            settings: AIImageSettings(
                accessMode: .userAPIKey,
                openAIAPIKey: "openai-key"
            )
        )
        state.composer.prompt = "Improve lettering"
        state.composer.model = .gptImage2

        XCTAssertFalse(state.generateDisabled)
    }

    func testRetryRegenerateAndCancelDelegateActions() async {
        let descriptor = AIImageEditDescriptor(
            prompt: NonEmptyPrompt("Retry me")!,
            accessMode: .userAPIKey,
            model: .flashImage31Preview,
            inputLayerIndex: 0,
            editScope: .wholeLayer,
            outputMode: .replaceCurrentLayer
        )
        let request = SubmitAIImageEditCommand(
            descriptor: descriptor,
            executionConfig: .userAPIKey(apiKey: AIImageAPIKey("user-key")!)
        )
        let jobID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_234)

        var initialState = AIImageFeature.State()
        initialState.settings = AIImageSettings(accessMode: .userAPIKey, apiKey: "user-key")
        initialState.jobs = [
            AIImageJob(
                id: jobID,
                descriptor: descriptor,
                createdAt: createdAt,
                status: .failed,
                message: "failed"
            )
        ]
        initialState.pendingRequest = descriptor

        let store = TestStore(initialState: initialState) {
            AIImageFeature()
        } withDependencies: {
            $0.aiImageCommandBuilder = AIImageCommandBuilder()
        }

        await store.send(.retryJobTapped(jobID))
        await store.receive(.delegate(.requestEdit(request)))

        await store.send(.regenerateTapped)
        await store.receive(.delegate(.requestEdit(request)))

        await store.send(.cancelGenerationTapped)
        await store.receive(.delegate(.cancelEdit))
    }
}
