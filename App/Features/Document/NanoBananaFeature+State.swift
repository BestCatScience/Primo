import ComposableArchitecture
import Foundation
import PrimoNanoBananaApplication
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
        var pendingRequest: NanoBananaEditDescriptor?
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

        mutating func applyHistoryItem(_ descriptor: NanoBananaEditDescriptor) {
            composer.prompt = descriptor.prompt.rawValue
            composer.inputLayerIndex = descriptor.inputLayerIndex
            composer.editScope = descriptor.editScope
            composer.outputMode = descriptor.outputMode
            composer.maskSettings = descriptor.maskSettings
            composer.model = descriptor.model
            accessMode = descriptor.accessMode
            workspaceBottomPanelSection = .nanoBanana
        }

        func buildDraft() -> NanoBananaDraft {
            NanoBananaDraft(
                prompt: composer.prompt,
                accessMode: accessMode,
                model: composer.model,
                inputLayerIndex: composer.inputLayerIndex,
                editScope: composer.editScope,
                outputMode: composer.outputMode,
                maskSettings: composer.maskSettings
            )
        }

        mutating func beginGeneration(
            descriptor: NanoBananaEditDescriptor,
            jobID: UUID,
            createdAt: Date
        ) {
            isGenerating = true
            pendingRequest = descriptor
            activeJobID = jobID
            jobs.insert(
                NanoBananaJob(
                    id: jobID,
                    descriptor: descriptor,
                    createdAt: createdAt,
                    status: .running,
                    message: nil
                ),
                at: 0
            )
            jobs = Array(jobs.prefix(12))
        }

        func regenerationRequest() -> NanoBananaEditDescriptor? {
            pendingRequest
        }

        func retryRequest(for jobID: UUID) -> NanoBananaEditDescriptor? {
            jobs.first(where: { $0.id == jobID })?.descriptor
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
                    descriptor: preview.descriptor,
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

        mutating func completeAppliedEdit(request: NanoBananaEditDescriptor) {
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
