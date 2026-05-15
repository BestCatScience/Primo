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
    let layerIndex: EditableLayerIndex

    init(command: DocumentMutationCommand, layerIndex: EditableLayerIndex) {
        self.command = command
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
        if let issue = validator.validate(command, in: validationContext(for: state)) {
            return .failure(issue.documentMutationFailure)
        }
        guard let layerIndex = EditableLayerIndex.validated(
            index,
            layerCount: state.layerSidebar.layers.count,
            isLayerLocked: { candidate in
                state.layerSidebar.layers.first(where: { $0.index == candidate })?.isLocked ?? false
            }
        ) else {
            return .failure(.invalidLayerIndex(index))
        }
        return .success(
            ValidatedDocumentLayerMutationCommand(
                command: command,
                layerIndex: layerIndex
            )
        )
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
