import Foundation
import PrimoBrushRuntimeContracts
import PrimoDocumentApplication
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts

struct ValidatedDocumentLayerMutationCommand: Equatable, Sendable {
    let command: DocumentMutationCommand
    let layerIndex: Int

    init(command: DocumentMutationCommand, layerIndex: Int) {
        self.command = command
        self.layerIndex = layerIndex
    }
}

struct ValidatedLayerContentReplacementCommand: Equatable, Sendable {
    let layer: ValidatedDocumentLayerMutationCommand
    let pixelData: Data
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
        return .success(
            ValidatedDocumentLayerMutationCommand(
                command: command,
                layerIndex: index
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
