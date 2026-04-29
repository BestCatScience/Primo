import ComposableArchitecture
import Foundation
import PrimoAIImageApplication
import PrimoAIImageDomain

extension AIImageFeature {
    enum WorkspaceBottomPanelSection: Hashable, Equatable {
        case aiImage
        case history
        case output
    }

    struct ComposerState: Equatable {
        var prompt = ""
        var inputLayerIndex = 0
        var editScope: AIImageEditScope = .wholeLayer
        var outputMode: AIImageOutputMode = .replaceCurrentLayer
        var maskSettings = AIImageMaskSettings()
        var model: AIImageModel = .flashImage31Preview
    }

    struct ExecutionState: Equatable {
        var isGenerating = false
        var jobs: [AIImageJob] = []
        var history: [AIImageHistoryItem] = []
        var pendingDescriptor: AIImageEditDescriptor?
        var activeJobID: UUID?
    }

    struct PresentationState: Equatable {
        var isSheetPresented = false
        var isPaywallPresented = false
        var workspaceBottomPanelSection: WorkspaceBottomPanelSection = .aiImage
        var workspaceBottomPanelCollapsed = false
    }

    @ObservableState
    struct State: Equatable {
        var composer = ComposerState()
        var settings = AIImageSettings(accessMode: .appManaged)
        var commerce = AIImageCommerceSnapshot()
        var execution = ExecutionState()
        var presentation = PresentationState()

        var isGenerating: Bool {
            get { execution.isGenerating }
            set { execution.isGenerating = newValue }
        }

        var jobs: [AIImageJob] {
            get { execution.jobs }
            set { execution.jobs = newValue }
        }

        var history: [AIImageHistoryItem] {
            get { execution.history }
            set { execution.history = newValue }
        }

        var pendingRequest: AIImageEditDescriptor? {
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

        var openAIAPIKey: String {
            get { settings.openAIAPIKey }
            set { settings.openAIAPIKey = newValue }
        }

        var accessMode: AIImageAccessMode {
            get { settings.accessMode }
            set { settings.accessMode = newValue }
        }

        var generateDisabled: Bool {
            isGenerating ||
            composer.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            (accessMode == .appManaged && !appManagedProxyEndpointConfigured) ||
            (accessMode == .userAPIKey && composer.model.provider == .openAI && !composer.model.supportsOpenAIDirectImageEdit) ||
            (accessMode == .userAPIKey && selectedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }

        var appManagedProxyEndpointConfigured: Bool {
            ProxyEndpoint(commerce.proxyEndpoint) != nil
        }

        var selectedAPIKey: String {
            composer.model.provider == .openAI ? openAIAPIKey : apiKey
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
            composer.model = .flashImage31Preview
            workspaceBottomPanelSection = .aiImage
            workspaceBottomPanelCollapsed = false
        }

        mutating func applyHistoryItem(_ descriptor: AIImageEditDescriptor) {
            composer.prompt = descriptor.prompt.rawValue
            composer.inputLayerIndex = descriptor.inputLayerIndex
            composer.editScope = descriptor.editScope
            composer.outputMode = descriptor.outputMode
            composer.maskSettings = descriptor.maskSettings
            composer.model = descriptor.model
            accessMode = .appManaged
            fallBackToUserAPIKeyIfAppManagedUnavailable()
            workspaceBottomPanelSection = .aiImage
        }

        mutating func fallBackToUserAPIKeyIfAppManagedUnavailable() {
            if accessMode == .appManaged, !appManagedProxyEndpointConfigured {
                accessMode = .userAPIKey
            }
        }

        func buildDraft() -> AIImageDraft {
            AIImageDraft(
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
            using builder: AIImageCommandBuilder
        ) -> Result<SubmitAIImageEditCommand, AIImageCommandBuilderFailure> {
            builder.build(
                draft: buildDraft(),
                apiKey: apiKey,
                openAIAPIKey: openAIAPIKey,
                commerce: commerce
            )
        }

        func buildCommand(
            for descriptor: AIImageEditDescriptor,
            using builder: AIImageCommandBuilder
        ) -> Result<SubmitAIImageEditCommand, AIImageCommandBuilderFailure> {
            builder.build(
                draft: AIImageDraft(
                    prompt: descriptor.prompt.rawValue,
                    accessMode: descriptor.accessMode,
                    model: descriptor.model,
                    inputLayerIndex: descriptor.inputLayerIndex,
                    editScope: descriptor.editScope,
                    outputMode: descriptor.outputMode,
                    maskSettings: descriptor.maskSettings
                ),
                apiKey: apiKey,
                openAIAPIKey: openAIAPIKey,
                commerce: commerce
            )
        }

        func regenerationCommand(
            using builder: AIImageCommandBuilder
        ) -> Result<SubmitAIImageEditCommand, AIImageCommandBuilderFailure>? {
            guard let descriptor = regenerationRequest() else { return nil }
            return buildCommand(for: descriptor, using: builder)
        }

        func retryCommand(
            for jobID: UUID,
            using builder: AIImageCommandBuilder
        ) -> Result<SubmitAIImageEditCommand, AIImageCommandBuilderFailure>? {
            guard let descriptor = retryRequest(for: jobID) else { return nil }
            return buildCommand(for: descriptor, using: builder)
        }

        mutating func beginGeneration(
            descriptor: AIImageEditDescriptor,
            jobID: UUID,
            createdAt: Date
        ) {
            execution.isGenerating = true
            execution.pendingDescriptor = descriptor
            execution.activeJobID = jobID
            execution.jobs.insert(
                AIImageJob(
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

        func regenerationRequest() -> AIImageEditDescriptor? {
            execution.pendingDescriptor
        }

        func retryRequest(for jobID: UUID) -> AIImageEditDescriptor? {
            execution.jobs.first(where: { $0.id == jobID })?.descriptor
        }

        mutating func recordSucceededGeneration(
            preview: AIImagePreviewState,
            historyID: UUID,
            createdAt: Date
        ) {
            execution.isGenerating = false
            execution.history.insert(
                AIImageHistoryItem(
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

        mutating func completeAppliedEdit(request: AIImageEditDescriptor) {
            execution.pendingDescriptor = request
            execution.activeJobID = nil
        }

        mutating func markFailed(
            feedback: ApplicationFeature.Feedback,
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
            feedback: ApplicationFeature.Feedback,
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
