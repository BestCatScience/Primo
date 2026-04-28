import ComposableArchitecture
import Foundation
import PrimoDocumentContracts
import PrimoDocumentDomain

extension DocumentFeatureRuntimeReducer {
    func handleOpenImportedDocumentRequest(
        state: inout State,
        sourceURL: URL
    ) -> Effect<Action> {
        let language = state.application.appLanguage
        return beginImportedWorkspaceProjectLoad(
            state: &state,
            sourceURL: sourceURL,
            onSuccess: { Action.workspace(.openImportedDocumentLoaded($0, $1, $2)) },
            onFailure: {
                Action.workspace(.openDocumentFailed(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: $0, context: .importDocument),
                        language: language
                    )
                ))
            }
        )
    }

    func handleOpenImportedDocumentLoaded(
        state: inout State,
        loaded: LoadedPaintProject,
        suggestedTitle: String,
        issues: [WorkspaceProjectLoadIssue]
    ) -> Effect<Action> {
        let trimmedTitle = suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty
            ? (state.application.appLanguage == .japanese ? "読み込み済みドキュメント" : "Imported Document")
            : trimmedTitle
        return applyLoadedWorkspaceProject(
            loaded,
            using: LoadedWorkspaceProjectPlan(
                destination: .newTab(
                    title: resolvedTitle,
                    sourceProjectURL: nil
                ),
                successEffects: .init(
                    completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
                )
            ),
            presentation: LoadedWorkspacePresentation(
                issues: issues,
                completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
            ),
            state: &state
        )
    }

    func handleSavedProjectMove(
        state: inout State,
        url: DocumentProjectPath,
        relativeFolderPath: RelativeProjectFolderPath?
    ) -> Effect<Action> {
        let request = WorkspaceCatalogRequest.moveSavedProject(
            WorkspaceSavedProjectMoveRequest(
                sourceURL: url,
                relativeFolderPath: relativeFolderPath,
                openTabID: state.workspace.tabID(forSourceProjectURL: url)
            )
        )
        return .send(.workspace(.catalogRequested(request)))
    }

    func handleOpenDocumentSelection(
        state: inout State,
        url: DocumentProjectPath,
        removesStagedWorkspaceItem: Bool
    ) -> Effect<Action> {
        if let existingTabID = state.workspace.tabID(forSourceProjectURL: url) {
            state.application.showWorkspace()
            state.application.completeWorkspaceProjectLoad()
            return .send(.workspace(.tabSelected(existingTabID)))
        }
        let language = state.application.appLanguage
        return beginWorkspaceProjectLoad(
            state: &state,
            fileURL: url.fileURL,
            removeWorkspaceItemOnSuccess: removesStagedWorkspaceItem ? url : nil,
            onSuccess: { Action.workspace(.openDocumentLoaded($0, url, $1)) },
            onFailure: {
                Action.workspace(.openDocumentFailed(
                    workspaceFeedbackMapper.message(
                        for: workspaceFeedbackMapper.feedback(for: $0, context: .openDocument),
                        language: language
                    )
                ))
            }
        )
    }

    func handleOpenDocumentLoaded(
        state: inout State,
        loaded: LoadedPaintProject,
        sourceURL: DocumentProjectPath,
        issues: [WorkspaceProjectLoadIssue]
    ) -> Effect<Action> {
        if let existingTabID = state.workspace.tabID(forSourceProjectURL: sourceURL) {
            state.application.completeWorkspaceProjectLoad(
                message: workspaceFeedbackMapper.bannerMessage(
                    for: issues,
                    language: state.application.appLanguage
                )
            )
            return .send(.workspace(.tabSelected(existingTabID)))
        }
        return applyLoadedWorkspaceProject(
            loaded,
            using: LoadedWorkspaceProjectPlan(
                destination: .newTab(
                    title: sourceURL.displayName,
                    sourceProjectURL: sourceURL
                ),
                successEffects: .init(
                    completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
                )
            ),
            presentation: LoadedWorkspacePresentation(
                issues: issues,
                completion: .openedDocument(layerCount: loaded.presentation.layerRows.count)
            ),
            state: &state
        )
    }
}
