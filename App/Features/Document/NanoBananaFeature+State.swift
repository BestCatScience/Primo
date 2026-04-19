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

    struct ExecutionState: Equatable {
        var isGenerating = false
        var jobs: [NanoBananaJob] = []
        var history: [NanoBananaHistoryItem] = []
        var pendingDescriptor: NanoBananaEditDescriptor?
        var activeJobID: UUID?
    }

    struct PresentationState: Equatable {
        var isSheetPresented = false
        var isPaywallPresented = false
        var workspaceBottomPanelSection: WorkspaceBottomPanelSection = .nanoBanana
        var workspaceBottomPanelCollapsed = false
    }

    @ObservableState
    struct State: Equatable {
        var composer = ComposerState()
        var settings = NanoBananaSettings()
        var commerce = NanoBananaCommerceSnapshot()
        var execution = ExecutionState()
        var presentation = PresentationState()

        var isGenerating: Bool {
            get { execution.isGenerating }
            set { execution.isGenerating = newValue }
        }

        var jobs: [NanoBananaJob] {
            get { execution.jobs }
            set { execution.jobs = newValue }
        }

        var history: [NanoBananaHistoryItem] {
            get { execution.history }
            set { execution.history = newValue }
        }

        var pendingRequest: NanoBananaEditDescriptor? {
            get { execution.pendingDescriptor }
            set { execution.pendingDescriptor = newValue }
        }

        var activeJobID: UUID? {
            get { execution.activeJobID }
            set { execution.activeJobID = newValue }
        }

        var isSheetPresented: Bool {
            get { presentation.isSheetPresented }
            set { presentation.isSheetPresented = newValue }
        }

        var isPaywallPresented: Bool {
            get { presentation.isPaywallPresented }
            set { presentation.isPaywallPresented = newValue }
        }

        var workspaceBottomPanelSection: WorkspaceBottomPanelSection {
            get { presentation.workspaceBottomPanelSection }
            set { presentation.workspaceBottomPanelSection = newValue }
        }

        var workspaceBottomPanelCollapsed: Bool {
            get { presentation.workspaceBottomPanelCollapsed }
            set { presentation.workspaceBottomPanelCollapsed = newValue }
        }

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

        func buildCommand(
            using builder: NanoBananaCommandBuilder
        ) -> Result<SubmitNanoBananaEditCommand, NanoBananaCommandBuilderFailure> {
            builder.build(
                draft: buildDraft(),
                apiKey: apiKey,
                commerce: commerce
            )
        }

        func buildCommand(
            for descriptor: NanoBananaEditDescriptor,
            using builder: NanoBananaCommandBuilder
        ) -> Result<SubmitNanoBananaEditCommand, NanoBananaCommandBuilderFailure> {
            builder.build(
                draft: NanoBananaDraft(
                    prompt: descriptor.prompt.rawValue,
                    accessMode: descriptor.accessMode,
                    model: descriptor.model,
                    inputLayerIndex: descriptor.inputLayerIndex,
                    editScope: descriptor.editScope,
                    outputMode: descriptor.outputMode,
                    maskSettings: descriptor.maskSettings
                ),
                apiKey: apiKey,
                commerce: commerce
            )
        }

        func regenerationCommand(
            using builder: NanoBananaCommandBuilder
        ) -> Result<SubmitNanoBananaEditCommand, NanoBananaCommandBuilderFailure>? {
            guard let descriptor = regenerationRequest() else { return nil }
            return buildCommand(for: descriptor, using: builder)
        }

        func retryCommand(
            for jobID: UUID,
            using builder: NanoBananaCommandBuilder
        ) -> Result<SubmitNanoBananaEditCommand, NanoBananaCommandBuilderFailure>? {
            guard let descriptor = retryRequest(for: jobID) else { return nil }
            return buildCommand(for: descriptor, using: builder)
        }

        mutating func beginGeneration(
            descriptor: NanoBananaEditDescriptor,
            jobID: UUID,
            createdAt: Date
        ) {
            execution.isGenerating = true
            execution.pendingDescriptor = descriptor
            execution.activeJobID = jobID
            execution.jobs.insert(
                NanoBananaJob(
                    id: jobID,
                    descriptor: descriptor,
                    createdAt: createdAt,
                    status: .running,
                    message: nil
                ),
                at: 0
            )
            execution.jobs = Array(execution.jobs.prefix(12))
        }

        func regenerationRequest() -> NanoBananaEditDescriptor? {
            execution.pendingDescriptor
        }

        func retryRequest(for jobID: UUID) -> NanoBananaEditDescriptor? {
            execution.jobs.first(where: { $0.id == jobID })?.descriptor
        }

        mutating func recordSucceededGeneration(
            preview: NanoBananaPreviewState,
            historyID: UUID,
            createdAt: Date
        ) {
            execution.isGenerating = false
            execution.history.insert(
                NanoBananaHistoryItem(
                    id: historyID,
                    descriptor: preview.descriptor,
                    createdAt: createdAt,
                    previewImageData: preview.afterPreviewImageData
                ),
                at: 0
            )
            execution.history = Array(execution.history.prefix(12))
            if let activeJobID = execution.activeJobID,
               let jobIndex = execution.jobs.firstIndex(where: { $0.id == activeJobID }) {
                execution.jobs[jobIndex].status = .succeeded
                execution.jobs[jobIndex].message = nil
            }
        }

        mutating func completeAppliedEdit(request: NanoBananaEditDescriptor) {
            execution.pendingDescriptor = request
            execution.activeJobID = nil
        }

        mutating func markFailed(
            feedback: AppFeature.ApplicationFeedback,
            language: AppLanguage
        ) {
            let message = feedback.message(for: language)
            execution.isGenerating = false
            if let activeJobID = execution.activeJobID,
               let jobIndex = execution.jobs.firstIndex(where: { $0.id == activeJobID }) {
                execution.jobs[jobIndex].status = .failed
                execution.jobs[jobIndex].message = message
            }
        }

        mutating func markCanceled(
            feedback: AppFeature.ApplicationFeedback,
            language: AppLanguage
        ) {
            let message = feedback.message(for: language)
            execution.isGenerating = false
            if let activeJobID = execution.activeJobID,
               let jobIndex = execution.jobs.firstIndex(where: { $0.id == activeJobID }) {
                execution.jobs[jobIndex].status = .canceled
                execution.jobs[jobIndex].message = message
            }
        }
    }
}
