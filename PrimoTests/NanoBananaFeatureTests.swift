import ComposableArchitecture
@testable import Primo
import PrimoNanoBananaApplication
import PrimoNanoBananaDomain
import PrimoNanoBananaInfrastructure
import XCTest

@MainActor
final class NanoBananaFeatureTests: XCTestCase {
    func testTaskLoadsSettingsAndCommerceSnapshot() async {
        let snapshot = NanoBananaCommerceSnapshot(
            primaryProduct: .init(
                id: "monthly",
                displayName: "Monthly",
                displayPrice: "$4.99"
            ),
            isSubscriptionActive: true,
            latestEntitlementJWS: "signed-jws",
            proxyEndpoint: "https://proxy.example.com/edit"
        )

        let store = TestStore(initialState: NanoBananaFeature.State()) {
            NanoBananaFeature()
        } withDependencies: {
            $0.nanoBananaSettingsClient = NanoBananaSettingsClient(
                load: { NanoBananaSettings(accessMode: .appManaged, apiKey: "persisted-key") },
                persist: { _ in }
            )
            $0.nanoBananaCommerceClient = NanoBananaCommerceClient(
                prepare: { snapshot },
                purchasePrimaryProduct: { snapshot },
                restorePurchases: { snapshot },
                clearPurchaseError: { snapshot }
            )
            $0.nanoBananaCommandBuilder = NanoBananaCommandBuilder()
        }

        await store.send(.task)
        await store.receive(.settingsLoaded(NanoBananaSettings(accessMode: .appManaged, apiKey: "persisted-key"))) {
            $0.settings = NanoBananaSettings(accessMode: .appManaged, apiKey: "persisted-key")
        }
        await store.receive(.commerceUpdated(snapshot)) {
            $0.commerce = snapshot
        }
    }

    func testGenerateShowsPaywallWhenAppManagedIsInactive() async {
        var initialState = NanoBananaFeature.State()
        initialState.settings = NanoBananaSettings(accessMode: .appManaged, apiKey: "")
        initialState.commerce = NanoBananaCommerceSnapshot(
            isSubscriptionActive: false,
            proxyEndpoint: "https://proxy.example.com/edit"
        )

        let store = TestStore(initialState: initialState) {
            NanoBananaFeature()
        }

        store.exhaustivity = .off

        await store.send(.generateButtonTapped(closeSheet: false)) {
            $0.isPaywallPresented = true
        }
    }

    func testGenerateDelegatesRequestWhenConfigured() async {
        var initialState = NanoBananaFeature.State(
            settings: NanoBananaSettings(accessMode: .userAPIKey, apiKey: "user-key"),
            commerce: NanoBananaCommerceSnapshot(proxyEndpoint: "https://proxy.example.com/edit")
        )
        initialState.composer.prompt = "Enhance linework"
        initialState.composer.inputLayerIndex = 3
        initialState.composer.editScope = .selectedArea
        initialState.composer.outputMode = .newLayer
        initialState.composer.maskSettings = .init(expansion: 8, isInverted: true)
        initialState.composer.model = .flashImage31Preview
        initialState.isSheetPresented = true

        let expectedRequest = SubmitNanoBananaEditCommand(
            descriptor: NanoBananaEditDescriptor(
                prompt: NonEmptyPrompt("Enhance linework")!,
                accessMode: .userAPIKey,
                model: .flashImage31Preview,
                inputLayerIndex: 3,
                editScope: .selectedArea,
                outputMode: .newLayer,
                maskSettings: .init(expansion: 8, isInverted: true)
            ),
            executionConfig: .userAPIKey(apiKey: NanoBananaAPIKey("user-key")!)
        )

        let store = TestStore(initialState: initialState) {
            NanoBananaFeature()
        } withDependencies: {
            $0.nanoBananaCommandBuilder = NanoBananaCommandBuilder()
        }

        await store.send(.generateButtonTapped(closeSheet: true)) {
            $0.isSheetPresented = false
        }
        await store.receive(.delegate(.requestEdit(expectedRequest)))
    }

    func testGenerateDelegatesGPTImage2RequestWithOpenAIKey() async {
        var initialState = NanoBananaFeature.State(
            settings: NanoBananaSettings(
                accessMode: .userAPIKey,
                apiKey: "gemini-key",
                openAIAPIKey: "openai-key"
            ),
            commerce: NanoBananaCommerceSnapshot(proxyEndpoint: "https://proxy.example.com/edit")
        )
        initialState.composer.prompt = "Improve lettering"
        initialState.composer.model = .gptImage2

        let expectedRequest = SubmitNanoBananaEditCommand(
            descriptor: NanoBananaEditDescriptor(
                prompt: NonEmptyPrompt("Improve lettering")!,
                accessMode: .userAPIKey,
                model: .gptImage2,
                inputLayerIndex: 0,
                editScope: .wholeLayer,
                outputMode: .replaceCurrentLayer
            ),
            executionConfig: .userAPIKey(apiKey: NanoBananaAPIKey("openai-key")!)
        )

        let store = TestStore(initialState: initialState) {
            NanoBananaFeature()
        } withDependencies: {
            $0.nanoBananaCommandBuilder = NanoBananaCommandBuilder()
        }

        await store.send(.generateButtonTapped(closeSheet: false))
        await store.receive(.delegate(.requestEdit(expectedRequest)))
    }

    func testGenerateDisabledUsesSelectedProviderAPIKey() {
        var state = NanoBananaFeature.State(
            settings: NanoBananaSettings(
                accessMode: .userAPIKey,
                apiKey: "gemini-key",
                openAIAPIKey: ""
            )
        )
        state.composer.prompt = "Improve lettering"
        state.composer.model = .gptImage2
        XCTAssertTrue(state.generateDisabled)

        state.openAIAPIKey = "openai-key"
        XCTAssertFalse(state.generateDisabled)
    }

    func testRetryRegenerateAndCancelDelegateActions() async {
        let descriptor = NanoBananaEditDescriptor(
            prompt: NonEmptyPrompt("Retry me")!,
            accessMode: .userAPIKey,
            model: .flashImage31Preview,
            inputLayerIndex: 0,
            editScope: .wholeLayer,
            outputMode: .replaceCurrentLayer
        )
        let request = SubmitNanoBananaEditCommand(
            descriptor: descriptor,
            executionConfig: .userAPIKey(apiKey: NanoBananaAPIKey("user-key")!)
        )
        let jobID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_234)

        var initialState = NanoBananaFeature.State()
        initialState.settings = NanoBananaSettings(accessMode: .userAPIKey, apiKey: "user-key")
        initialState.jobs = [
            NanoBananaJob(
                id: jobID,
                descriptor: descriptor,
                createdAt: createdAt,
                status: .failed,
                message: "failed"
            )
        ]
        initialState.pendingRequest = descriptor

        let store = TestStore(initialState: initialState) {
            NanoBananaFeature()
        } withDependencies: {
            $0.nanoBananaCommandBuilder = NanoBananaCommandBuilder()
        }

        await store.send(.retryJobTapped(jobID))
        await store.receive(.delegate(.requestEdit(request)))

        await store.send(.regenerateTapped)
        await store.receive(.delegate(.requestEdit(request)))

        await store.send(.cancelGenerationTapped)
        await store.receive(.delegate(.cancelEdit))
    }
}
