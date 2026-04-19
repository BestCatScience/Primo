import ComposableArchitecture
import Foundation
import PrimoNanoBananaDomain

extension NanoBananaFeature {
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
}
