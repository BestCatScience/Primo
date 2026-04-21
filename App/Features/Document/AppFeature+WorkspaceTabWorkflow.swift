import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoWorkspaceDomain

extension AppFeature {
    typealias WorkspaceProjectLoadIssue = PrimoWorkspaceDomain.WorkspaceProjectLoadIssue
    typealias WorkspaceProjectLoadFailureReason = PrimoWorkspaceDomain.WorkspaceProjectLoadFailureReason
    typealias WorkspaceProjectLoadOperation = PrimoWorkspaceDomain.WorkspaceProjectLoadOperation
    typealias WorkspaceImportedProjectLoadOperation = PrimoWorkspaceDomain.WorkspaceImportedProjectLoadOperation
    typealias WorkspaceProjectLoadRequest = PrimoWorkspaceDomain.WorkspaceProjectLoadRequest
    typealias WorkspaceProjectLoadResult = PrimoWorkspaceDomain.WorkspaceProjectLoadResult<LoadedPaintProject>
    typealias WorkspaceProjectLoadFailure = PrimoWorkspaceDomain.WorkspaceProjectLoadFailure
    typealias WorkspaceProjectPreparationUseCase = PrimoWorkspaceDomain.WorkspaceProjectPreparationUseCase
    typealias WorkspaceProjectLoadUseCase = PrimoWorkspaceDomain.WorkspaceProjectLoadUseCase<LoadedPaintProject>
    typealias WorkspaceProjectLoadCommand = PrimoWorkspaceDomain.WorkspaceProjectLoadCommand
    typealias WorkspaceProjectLoadingService = PrimoWorkspaceDomain.WorkspaceProjectLoadingService<LoadedPaintProject>

    var workspaceProjectPreparationUseCase: WorkspaceProjectPreparationUseCase {
        WorkspaceProjectPreparationUseCase(
            workspacePersistenceUseCase: workspacePersistenceUseCase
        )
    }

    var workspaceProjectLoadUseCase: WorkspaceProjectLoadUseCase {
        WorkspaceProjectLoadUseCase(
            projectLoader: workspaceProjectLoaderGateway,
            documentImport: documentImportGateway,
            cleanupService: workspaceDomainProjectCleanupService
        )
    }

    var workspaceProjectLoadingService: WorkspaceProjectLoadingService {
        WorkspaceProjectLoadingService(
            preparationUseCase: workspaceProjectPreparationUseCase,
            loadUseCase: workspaceProjectLoadUseCase
        )
    }

    var documentImportGateway: DocumentImportGateway {
        DocumentImportGateway(
            stageImportedDocument: { request in
                documentImportClient.stageImportedDocument(
                    ImportedDocumentStageRequest(sourceURL: request.sourceURL)
                )
            },
            discardStagedDocument: { stagedProjectURL in
                documentImportClient.discardStagedDocument(stagedProjectURL)
            }
        )
    }

    var workspaceProjectLoaderGateway: ProjectLoadingGateway<LoadedPaintProject> {
        ProjectLoadingGateway(
            loadProject: { url in
                try documentPersistenceGateway.loadProject(url)
            }
        )
    }

    var workspaceDomainProjectCleanupService: PrimoWorkspaceDomain.WorkspaceProjectCleanupService {
        PrimoWorkspaceDomain.WorkspaceProjectCleanupService(
            workspaceBackingStore: workspaceBackingStoreGateway,
            documentImport: documentImportGateway
        )
    }

    func beginWorkspaceProjectLoad(
        state: inout State,
        fileURL: URL,
        persistCurrentTab: Bool = true,
        removeWorkspaceItemOnSuccess: DocumentProjectPath? = nil,
        onSuccess: @escaping @Sendable (LoadedPaintProject, [WorkspaceProjectLoadIssue]) -> Action,
        onFailure: @escaping @Sendable (WorkspaceProjectLoadFailure) -> Action
    ) -> Effect<Action> {
        let prepareRequest: WorkspaceDocumentReplacementRequest?
        if persistCurrentTab && !state.application.showsHome {
            switch documentReplacementRequest(state: &state) {
            case let .success(request):
                prepareRequest = request
            case let .failure(failure):
                state.application.presentBanner(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: failure),
                        language: state.application.appLanguage
                    )
                )
                return .none
            }
        } else {
            prepareRequest = nil
        }
        state.application.beginHydration()
        let command = WorkspaceProjectLoadCommand(
            loadRequest: .project(
            WorkspaceProjectLoadOperation(
                fileURL: fileURL,
                removeWorkspaceItemOnSuccess: removeWorkspaceItemOnSuccess
            )
            ),
            prepareDocumentReplacementRequest: prepareRequest
        )
        return .run { [workspaceProjectLoadingService] send in
            switch workspaceProjectLoadingService.execute(command) {
            case let .success(.project(loaded, issues)):
                await send(onSuccess(loaded, issues))
            case .success(.imported):
                return
            case let .failure(failure):
                await send(onFailure(failure))
            }
        }
        .cancellable(id: CancelID.workspaceProjectLoad, cancelInFlight: true)
    }

    func beginImportedWorkspaceProjectLoad(
        state: inout State,
        sourceURL: URL,
        persistCurrentTab: Bool = true,
        onSuccess: @escaping @Sendable (LoadedPaintProject, String, [WorkspaceProjectLoadIssue]) -> Action,
        onFailure: @escaping @Sendable (WorkspaceProjectLoadFailure) -> Action
    ) -> Effect<Action> {
        let prepareRequest: WorkspaceDocumentReplacementRequest?
        if persistCurrentTab && !state.application.showsHome {
            switch documentReplacementRequest(state: &state) {
            case let .success(request):
                prepareRequest = request
            case let .failure(failure):
                state.application.presentBanner(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: failure),
                        language: state.application.appLanguage
                    )
                )
                return .none
            }
        } else {
            prepareRequest = nil
        }
        state.application.beginHydration()
        let command = WorkspaceProjectLoadCommand(
            loadRequest: .imported(
            WorkspaceImportedProjectLoadOperation(
                sourceURL: sourceURL
            )
            ),
            prepareDocumentReplacementRequest: prepareRequest
        )
        return .run { [workspaceProjectLoadingService] send in
            switch workspaceProjectLoadingService.execute(command) {
            case let .success(.imported(loaded, suggestedTitle, issues)):
                await send(onSuccess(loaded, suggestedTitle, issues))
            case .success(.project):
                return
            case let .failure(failure):
                await send(onFailure(failure))
            }
        }
        .cancellable(id: CancelID.workspaceProjectLoad, cancelInFlight: true)
    }
}
