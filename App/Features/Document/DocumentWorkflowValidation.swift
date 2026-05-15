import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts

// App workflow validation is a preflight / fast feedback layer built from
// DocumentEditingState. The UI snapshot can be stale, so this capability is
// not the final contract; application and runtime validation must re-check it.
struct ValidatedDocumentLayerMutationCommand: Equatable, Sendable {
    let command: DocumentMutationCommand
    let existingLayerIndex: ExistingLayerIndex
    let layerIndex: EditableLayerIndex

    init(command: DocumentMutationCommand, existingLayerIndex: ExistingLayerIndex, layerIndex: EditableLayerIndex) {
        self.command = command
        self.existingLayerIndex = existingLayerIndex
        self.layerIndex = layerIndex
    }
}

struct ValidatedLayerContentReplacementCommand: Equatable, Sendable {
    let layer: ValidatedDocumentLayerMutationCommand
    let pixelData: LayerPixelData
}

struct ValidatedBlurStrokeMutationCommand: Equatable, Sendable {
    let layer: ValidatedDocumentLayerMutationCommand
    let samples: [StylusSample]
    let brush: BrushRuntimeSettings
    let clearSelectionAfterBlur: Bool
}

struct ValidatedFillMutationCommand: Equatable, Sendable {
    let layer: ValidatedDocumentLayerMutationCommand
    let sample: StylusSample
    let brush: BrushRuntimeSettings
}

struct DocumentWorkflowCommandValidator: Sendable {
    private let validator = DocumentMutationValidator()

    func editableLayerCommand(
        index: Int,
        in state: DocumentEditingState
    ) -> Result<ValidatedDocumentLayerMutationCommand, DocumentMutationFailure> {
        let command = DocumentMutationCommand.layer(index: index, requiresUnlocked: true)
        let validationContext = validationContext(for: state)
        if let issue = validator.validate(command, in: validationContext) {
            return .failure(issue.documentMutationFailure)
        }
        let layerMutationContext = layerMutationContext(for: state)
        guard let existingLayerIndex = layerMutationContext.existingLayerIndex(index) else {
            return .failure(.invalidLayerIndex(index))
        }
        guard let layerIndex = layerMutationContext.editableLayerIndex(index) else {
            return .failure(.invalidLayerIndex(index))
        }
        return .success(
            ValidatedDocumentLayerMutationCommand(
                command: command,
                existingLayerIndex: existingLayerIndex,
                layerIndex: layerIndex
            )
        )
    }

    func existingLayerIndex(
        _ index: Int,
        in state: DocumentEditingState
    ) -> Result<ExistingLayerIndex, DocumentMutationFailure> {
        let command = DocumentMutationCommand.layer(index: index)
        if let issue = validator.validate(command, in: validationContext(for: state)) {
            return .failure(issue.documentMutationFailure)
        }
        guard let layerIndex = layerMutationContext(for: state).existingLayerIndex(index) else {
            return .failure(.invalidLayerIndex(index))
        }
        return .success(layerIndex)
    }

    func editableLayerIndex(
        _ index: Int,
        in state: DocumentEditingState
    ) -> Result<EditableLayerIndex, DocumentMutationFailure> {
        editableLayerCommand(index: index, in: state).map(\.layerIndex)
    }

    func existingFolderID(
        _ folderID: Int,
        in state: DocumentEditingState
    ) -> Result<ExistingFolderID, DocumentMutationFailure> {
        let command = DocumentMutationCommand.folder(folderID: folderID)
        if let issue = validator.validate(command, in: validationContext(for: state)) {
            return .failure(issue.documentMutationFailure)
        }
        guard let typedFolderID = layerMutationContext(for: state).existingFolderID(folderID) else {
            return .failure(.invalidFolderID(folderID))
        }
        return .success(typedFolderID)
    }

    func existingFolderID(
        _ folderID: Int?,
        in state: DocumentEditingState
    ) -> Result<ExistingFolderID?, DocumentMutationFailure> {
        guard let folderID else { return .success(nil) }
        return existingFolderID(folderID, in: state).map(Optional.some)
    }

    func layerAnchorIndex(
        _ index: Int,
        in state: DocumentEditingState
    ) -> Result<LayerAnchorIndex, DocumentMutationFailure> {
        let command = DocumentMutationCommand.layerAnchor(index: index)
        if let issue = validator.validate(command, in: validationContext(for: state)) {
            return .failure(issue.documentMutationFailure)
        }
        guard let anchorIndex = layerMutationContext(for: state).anchorLayerIndex(index) else {
            return .failure(.invalidLayerIndex(index))
        }
        return .success(anchorIndex)
    }

    func unitInterval(
        _ opacity: Double
    ) -> Result<UnitInterval, DocumentMutationFailure> {
        guard let opacity = UnitInterval(opacity) else {
            return .failure(.invalidOpacity(opacity))
        }
        return .success(opacity)
    }

    func blurStrokeCommand(
        samples: [StylusSample],
        brush: BrushRuntimeSettings,
        clearSelectionAfterBlur: Bool,
        in state: DocumentEditingState
    ) -> Result<ValidatedBlurStrokeMutationCommand, DocumentMutationFailure> {
        guard !samples.isEmpty else {
            return .failure(.emptyInput)
        }
        return editableLayerCommand(index: state.canvas.activeLayerIndex, in: state).map { layer in
            ValidatedBlurStrokeMutationCommand(
                layer: layer,
                samples: samples,
                brush: brush,
                clearSelectionAfterBlur: clearSelectionAfterBlur
            )
        }
    }

    func fillCommand(
        sample: StylusSample,
        brush: BrushRuntimeSettings,
        in state: DocumentEditingState
    ) -> Result<ValidatedFillMutationCommand, DocumentMutationFailure> {
        editableLayerCommand(index: state.canvas.activeLayerIndex, in: state).map { layer in
            ValidatedFillMutationCommand(
                layer: layer,
                sample: sample,
                brush: brush
            )
        }
    }

    private func validationContext(for state: DocumentEditingState) -> DocumentMutationValidationContext {
        let lockedLayerIndexes = Set(
            state.layerSidebar.layers
                .filter(\.isLocked)
                .map(\.index)
        )
        return DocumentMutationValidationContext(
            layerCount: state.layerSidebar.layers.count,
            folderIDs: Set(
                state.layerSidebar.rows.compactMap { row in
                    if case let .folder(folder) = row {
                        return folder.id
                    }
                    return nil
                }
            ),
            isLayerLocked: { index in
                lockedLayerIndexes.contains(index)
            }
        )
    }

    private func layerMutationContext(for state: DocumentEditingState) -> DocumentLayerMutationContext {
        let lockedLayerIndexes = Set(
            state.layerSidebar.layers
                .filter(\.isLocked)
                .map(\.index)
        )
        return DocumentLayerMutationContext(
            layerCount: state.layerSidebar.layers.count,
            folderIDs: Set(
                state.layerSidebar.rows.compactMap { row in
                    if case let .folder(folder) = row {
                        return folder.id
                    }
                    return nil
                }
            ),
            isLayerLocked: { index in
                lockedLayerIndexes.contains(index)
            }
        )
    }
}

private extension DocumentMutationValidationIssue {
    var documentMutationFailure: DocumentMutationFailure {
        switch self {
        case let .invalidLayerIndex(index):
            return .invalidLayerIndex(index)
        case let .invalidFolderID(folderID):
            return .invalidFolderID(folderID)
        case let .layerLocked(index):
            return .layerLocked(index)
        }
    }
}
