import Foundation
import PrimoBrushDomain
import PrimoDocumentMutationContracts
import PrimoDocumentDomain
import PrimoDocumentRenderingContracts

public enum DocumentCanvasMutationIntent<Selection: Equatable & Sendable>: Equatable, Sendable {
    case none
    case clearSelection
    case finalizeLayer(DocumentLayerMutationFinalization)
    case resetTransientEditingState
}

public enum DocumentPresentationRefreshIntent: Equatable, Sendable {
    case none
    case current
    case dirty
}

public struct DocumentLayerMutationFinalization: Equatable, Sendable {
    public let index: Int
    public var incrementsRevision: Bool
    public var clearsSelection: Bool

    public init(index: Int, incrementsRevision: Bool = false, clearsSelection: Bool = true) {
        self.index = index
        self.incrementsRevision = incrementsRevision
        self.clearsSelection = clearsSelection
    }
}

public enum DocumentMutationFeedbackIntent<Feedback: Equatable & Sendable>: Equatable, Sendable {
    case none
    case success(Feedback)
    case failure(DocumentMutationFailure, defaultFeedback: Feedback?)
}

public struct DocumentMutationWorkflowOutcome<Selection: Equatable & Sendable, Feedback: Equatable & Sendable>: Equatable, Sendable {
    public var canvasMutation: DocumentCanvasMutationIntent<Selection>
    public var refresh: DocumentPresentationRefreshIntent
    public var feedback: DocumentMutationFeedbackIntent<Feedback>
    public var updatesWorkspaceArtifacts: Bool

    public init(
        canvasMutation: DocumentCanvasMutationIntent<Selection> = .none,
        refresh: DocumentPresentationRefreshIntent = .dirty,
        feedback: DocumentMutationFeedbackIntent<Feedback> = .none,
        updatesWorkspaceArtifacts: Bool = true
    ) {
        self.canvasMutation = canvasMutation
        self.refresh = refresh
        self.feedback = feedback
        self.updatesWorkspaceArtifacts = updatesWorkspaceArtifacts
    }

    public static var dirty: Self { Self() }
    public static var currentPresentation: Self { Self(refresh: .current) }
}

public struct DocumentMutationWorkflowService: Sendable {
    package let documentQueryGateway: DocumentQueryGateway
    public let documentEditingGateway: DocumentEditingGateway
    public let documentLayerEffectsGateway: DocumentLayerEffectsGateway

    public init(
        documentQueryGateway: DocumentQueryGateway,
        documentEditingGateway: DocumentEditingGateway,
        documentLayerEffectsGateway: DocumentLayerEffectsGateway
    ) {
        self.documentQueryGateway = documentQueryGateway
        self.documentEditingGateway = documentEditingGateway
        self.documentLayerEffectsGateway = documentLayerEffectsGateway
    }

    public func addLayer(named name: String) -> DocumentIndexedMutationResult {
        executeIndexed(.structure(.addLayer(name: name)))
    }

    public func createFolder(named name: String, afterLayerAt activeLayerIndex: Int) -> DocumentIndexedMutationResult {
        executeIndexed(.structure(.createFolder(name: name, anchorLayerIndex: activeLayerIndex)))
    }

    public func deleteFolder(_ folderID: Int) -> DocumentMutationResult {
        execute(.structure(.deleteFolder(folderID: folderID)))
    }

    public func deleteLayer(_ index: Int) -> DocumentMutationResult {
        execute(.structure(.deleteLayer(index: index)))
    }

    public func duplicateLayer(_ index: Int, named duplicateName: String) -> DocumentIndexedMutationResult {
        executeIndexed(.structure(.duplicateLayer(index: index, name: duplicateName)))
    }

    public func moveLayer(_ index: Int, to destinationIndex: Int) -> DocumentMutationResult {
        execute(.structure(.moveLayer(index: index, destinationIndex: destinationIndex)))
    }

    public func assignLayer(_ index: Int, toFolder folderID: Int?) -> DocumentMutationResult {
        execute(.structure(.assignLayerToFolder(index: index, folderID: folderID)))
    }

    public func mergeLayerDown(_ index: Int) -> DocumentMutationResult {
        documentLayerEffectsGateway.mergeLayerDown(index)
    }

    public func setLayerVisibility(_ index: Int, visible: Bool) -> DocumentMutationResult {
        execute(.attribute(.setLayerVisibility(index: index, isVisible: visible)))
    }

    public func setActiveLayer(_ index: Int) -> DocumentMutationResult {
        execute(.attribute(.setActiveLayer(index: index)))
    }

    public func setLayerOpacity(_ index: Int, opacity: Double) -> DocumentMutationResult {
        execute(.attribute(.setLayerOpacity(index: index, opacity: opacity)))
    }

    public func setLayerLocked(_ index: Int, isLocked: Bool) -> DocumentMutationResult {
        execute(.attribute(.setLayerLocked(index: index, isLocked: isLocked)))
    }

    public func setLayerAlphaLocked(_ index: Int, isAlphaLocked: Bool) -> DocumentMutationResult {
        execute(.attribute(.setLayerAlphaLocked(index: index, isAlphaLocked: isAlphaLocked)))
    }

    public func setLayerClipped(_ index: Int, isClipped: Bool) -> DocumentMutationResult {
        execute(.attribute(.setLayerClipped(index: index, isClipped: isClipped)))
    }

    public func setFolderExpanded(_ folderID: Int, isExpanded: Bool) -> DocumentMutationResult {
        execute(.attribute(.setFolderExpanded(folderID: folderID, isExpanded: isExpanded)))
    }

    public func setFolderVisibility(_ folderID: Int, visible: Bool) -> DocumentMutationResult {
        execute(.attribute(.setFolderVisibility(folderID: folderID, isVisible: visible)))
    }

    public func setFolderName(_ folderID: Int, name: String) -> DocumentMutationResult {
        execute(.attribute(.setFolderName(folderID: folderID, name: name)))
    }

    public func setLayerBlendMode(_ index: Int, blendMode: LayerBlendMode) -> DocumentMutationResult {
        execute(.attribute(.setLayerBlendMode(index: index, blendMode: blendMode)))
    }

    public func setLayerName(_ index: Int, name: String) -> DocumentMutationResult {
        execute(.attribute(.setLayerName(index: index, name: name)))
    }

    public func replaceLayerPixels(_ index: Int, pixelData: Data) -> DocumentMutationResult {
        let geometry = documentQueryGateway.lightweightPresentation().geometry
        guard let payload = LayerPixelData(width: geometry.width, height: geometry.height, rgba: pixelData) else {
            return .failure(
                .gpu(
                    .invalidPayloadSize(
                        operation: "replaceLayerPixels",
                        expected: geometry.rgbaByteCount,
                        actual: pixelData.count
                    )
                )
            )
        }
        return executeContent(.replacePixels(index: index, pixelData: payload))
    }

    public func applyLayerProcessing(_ index: Int, request: LayerProcessingRequest) -> DocumentMutationResult {
        executeContent(.applyProcessing(index: index, request: request))
    }

    public func setTextLayer(_ index: Int, textLayer: TextLayerData) -> DocumentMutationResult {
        executeContent(.setTextLayer(index: index, textLayer: textLayer))
    }

    public func clearLayer(_ index: Int) -> DocumentMutationResult {
        executeContent(.clear(index: index))
    }

    public func replaceLayerMask(_ index: Int, maskData: Data) -> DocumentMutationResult {
        let geometry = documentQueryGateway.lightweightPresentation().geometry
        guard let payload = LayerMaskData(width: geometry.width, height: geometry.height, bytes: maskData) else {
            return .failure(
                .gpu(
                    .invalidPayloadSize(
                        operation: "replaceLayerMask",
                        expected: geometry.maskByteCount,
                        actual: maskData.count
                    )
                )
            )
        }
        return executeContent(.replaceMask(index: index, mask: payload))
    }

    public func clearLayerMask(_ index: Int) -> DocumentMutationResult {
        executeContent(.clearMask(index: index))
    }

    public func applyLayerMask(_ index: Int) -> DocumentMutationResult {
        executeContent(.applyMask(index: index))
    }

    private func execute(_ request: DocumentEditingRequest) -> DocumentMutationResult {
        documentEditingGateway.execute(request).map { _ in () }
    }

    private func executeIndexed(_ request: DocumentEditingRequest) -> DocumentIndexedMutationResult {
        documentEditingGateway.execute(request).flatMap { result in
            guard case let .structure(plan) = result, let index = plan.resultingIndex else {
                return .failure(.bridgeMutationFailed("documentEditingGateway"))
            }
            return .success(index)
        }
    }

    private func executeContent(_ command: LayerContentMutationCommand) -> DocumentMutationResult {
        execute(.content(command))
    }
}
