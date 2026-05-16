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
    private let documentQueryGateway: DocumentQueryGateway
    private let documentEditingGateway: DocumentEditingGateway
    private let documentLayerEffectsGateway: DocumentLayerEffectsGateway

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

    public func createFolder(named name: String, afterLayerAt anchorLayerIndex: LayerAnchorIndex) -> DocumentIndexedMutationResult {
        createFolder(named: name, afterLayerAt: anchorLayerIndex.rawValue)
    }

    public func deleteFolder(_ folderID: ExistingFolderID) -> DocumentMutationResult {
        requireCurrent(folderID).flatMap { folderID in
            execute(.structure(.deleteFolder(folderID: folderID.rawValue)))
        }
    }

    public func deleteLayer(_ index: ExistingLayerIndex) -> DocumentMutationResult {
        requireCurrent(index).flatMap { index in
            execute(.structure(.deleteLayer(index: index.rawValue)))
        }
    }

    public func duplicateLayer(_ index: ExistingLayerIndex, named duplicateName: String) -> DocumentIndexedMutationResult {
        requireCurrent(index).flatMap { index in
            executeIndexed(.structure(.duplicateLayer(index: index.rawValue, name: duplicateName)))
        }
    }

    public func moveLayer(_ index: ExistingLayerIndex, to destinationIndex: ExistingLayerIndex) -> DocumentMutationResult {
        requireCurrent(index).flatMap { index in
            requireCurrent(destinationIndex).flatMap { destinationIndex in
                execute(.structure(.moveLayer(index: index.rawValue, destinationIndex: destinationIndex.rawValue)))
            }
        }
    }

    public func assignLayer(_ index: ExistingLayerIndex, toFolder folderID: ExistingFolderID?) -> DocumentMutationResult {
        requireCurrent(index).flatMap { index in
            requireCurrent(folderID).flatMap { folderID in
                execute(.structure(.assignLayerToFolder(index: index.rawValue, folderID: folderID?.rawValue)))
            }
        }
    }

    public func mergeLayerDown(_ index: ExistingLayerIndex) -> DocumentMutationResult {
        requireCurrent(index).flatMap { index in
            documentLayerEffectsGateway.mergeLayerDown(index.rawValue)
        }
    }

    public func setLayerVisibility(_ index: ExistingLayerIndex, visible: Bool) -> DocumentMutationResult {
        requireCurrent(index).flatMap { index in
            execute(.attribute(.setLayerVisibility(index: index.rawValue, isVisible: visible)))
        }
    }

    public func setActiveLayer(_ index: ExistingLayerIndex) -> DocumentMutationResult {
        requireCurrent(index).flatMap { index in
            execute(.attribute(.setActiveLayer(index: index.rawValue)))
        }
    }

    public func setLayerOpacity(_ index: ExistingLayerIndex, opacity: UnitInterval) -> DocumentMutationResult {
        requireCurrent(index).flatMap { index in
            execute(.attribute(.setLayerOpacity(index: index.rawValue, opacity: opacity.rawValue)))
        }
    }

    public func setLayerLocked(_ index: ExistingLayerIndex, isLocked: Bool) -> DocumentMutationResult {
        requireCurrent(index).flatMap { index in
            execute(.attribute(.setLayerLocked(index: index.rawValue, isLocked: isLocked)))
        }
    }

    public func setLayerAlphaLocked(_ index: ExistingLayerIndex, isAlphaLocked: Bool) -> DocumentMutationResult {
        requireCurrent(index).flatMap { index in
            execute(.attribute(.setLayerAlphaLocked(index: index.rawValue, isAlphaLocked: isAlphaLocked)))
        }
    }

    public func setLayerClipped(_ index: ExistingLayerIndex, isClipped: Bool) -> DocumentMutationResult {
        requireCurrent(index).flatMap { index in
            execute(.attribute(.setLayerClipped(index: index.rawValue, isClipped: isClipped)))
        }
    }

    public func setFolderExpanded(_ folderID: ExistingFolderID, isExpanded: Bool) -> DocumentMutationResult {
        requireCurrent(folderID).flatMap { folderID in
            execute(.attribute(.setFolderExpanded(folderID: folderID.rawValue, isExpanded: isExpanded)))
        }
    }

    public func setFolderVisibility(_ folderID: ExistingFolderID, visible: Bool) -> DocumentMutationResult {
        requireCurrent(folderID).flatMap { folderID in
            execute(.attribute(.setFolderVisibility(folderID: folderID.rawValue, isVisible: visible)))
        }
    }

    public func setFolderName(_ folderID: ExistingFolderID, name: String) -> DocumentMutationResult {
        requireCurrent(folderID).flatMap { folderID in
            execute(.attribute(.setFolderName(folderID: folderID.rawValue, name: name)))
        }
    }

    public func setLayerBlendMode(_ index: ExistingLayerIndex, blendMode: LayerBlendMode) -> DocumentMutationResult {
        requireCurrent(index).flatMap { index in
            execute(.attribute(.setLayerBlendMode(index: index.rawValue, blendMode: blendMode)))
        }
    }

    public func setLayerName(_ index: ExistingLayerIndex, name: String) -> DocumentMutationResult {
        requireCurrent(index).flatMap { index in
            execute(.attribute(.setLayerName(index: index.rawValue, name: name)))
        }
    }

    public func replaceLayerPixels(_ command: LayerPixelReplacementCommand) -> DocumentMutationResult {
        requireEditable(command.index).flatMap { index in
            validatePixelData(command.pixelData, operation: "replaceLayerPixels").flatMap { pixelData in
                executeContent(.replacePixels(index: index.rawValue, pixelData: pixelData))
            }
        }
    }

    public func applyLayerProcessing(_ index: EditableLayerIndex, request: LayerProcessingRequest) -> DocumentMutationResult {
        requireEditable(index).flatMap { index in
            validatedProcessingRequest(request).flatMap { _ in
                executeContent(.applyProcessing(index: index.rawValue, request: request))
            }
        }
    }

    public func setTextLayer(_ index: EditableLayerIndex, textLayer: TextLayerData) -> DocumentMutationResult {
        requireEditable(index).flatMap { index in
            executeContent(.setTextLayer(index: index.rawValue, textLayer: textLayer))
        }
    }

    public func clearLayer(_ index: EditableLayerIndex) -> DocumentMutationResult {
        requireEditable(index).flatMap { index in
            executeContent(.clear(index: index.rawValue))
        }
    }

    public func replaceLayerMask(_ index: EditableLayerIndex, mask: LayerMaskData) -> DocumentMutationResult {
        requireEditable(index).flatMap { index in
            validateMaskData(mask, operation: "replaceLayerMask").flatMap { mask in
                executeContent(.replaceMask(index: index.rawValue, mask: mask))
            }
        }
    }

    public func clearLayerMask(_ index: EditableLayerIndex) -> DocumentMutationResult {
        requireEditable(index).flatMap { index in
            executeContent(.clearMask(index: index.rawValue))
        }
    }

    public func applyLayerMask(_ index: EditableLayerIndex) -> DocumentMutationResult {
        requireEditable(index).flatMap { index in
            executeContent(.applyMask(index: index.rawValue))
        }
    }

    package func createFolder(named name: String, afterLayerAt activeLayerIndex: Int?) -> DocumentIndexedMutationResult {
        executeIndexed(.structure(.createFolder(name: name, anchorLayerIndex: activeLayerIndex)))
    }

    package func deleteFolder(_ folderID: Int) -> DocumentMutationResult {
        execute(.structure(.deleteFolder(folderID: folderID)))
    }

    package func deleteLayer(_ index: Int) -> DocumentMutationResult {
        execute(.structure(.deleteLayer(index: index)))
    }

    package func duplicateLayer(_ index: Int, named duplicateName: String) -> DocumentIndexedMutationResult {
        executeIndexed(.structure(.duplicateLayer(index: index, name: duplicateName)))
    }

    package func moveLayer(_ index: Int, to destinationIndex: Int) -> DocumentMutationResult {
        execute(.structure(.moveLayer(index: index, destinationIndex: destinationIndex)))
    }

    package func assignLayer(_ index: Int, toFolder folderID: Int?) -> DocumentMutationResult {
        execute(.structure(.assignLayerToFolder(index: index, folderID: folderID)))
    }

    package func mergeLayerDown(_ index: Int) -> DocumentMutationResult {
        documentLayerEffectsGateway.mergeLayerDown(index)
    }

    package func setLayerVisibility(_ index: Int, visible: Bool) -> DocumentMutationResult {
        execute(.attribute(.setLayerVisibility(index: index, isVisible: visible)))
    }

    package func setActiveLayer(_ index: Int) -> DocumentMutationResult {
        execute(.attribute(.setActiveLayer(index: index)))
    }

    package func setLayerOpacity(_ index: Int, opacity: Double) -> DocumentMutationResult {
        execute(.attribute(.setLayerOpacity(index: index, opacity: opacity)))
    }

    package func setLayerLocked(_ index: Int, isLocked: Bool) -> DocumentMutationResult {
        execute(.attribute(.setLayerLocked(index: index, isLocked: isLocked)))
    }

    package func setLayerAlphaLocked(_ index: Int, isAlphaLocked: Bool) -> DocumentMutationResult {
        execute(.attribute(.setLayerAlphaLocked(index: index, isAlphaLocked: isAlphaLocked)))
    }

    package func setLayerClipped(_ index: Int, isClipped: Bool) -> DocumentMutationResult {
        execute(.attribute(.setLayerClipped(index: index, isClipped: isClipped)))
    }

    package func setFolderExpanded(_ folderID: Int, isExpanded: Bool) -> DocumentMutationResult {
        execute(.attribute(.setFolderExpanded(folderID: folderID, isExpanded: isExpanded)))
    }

    package func setFolderVisibility(_ folderID: Int, visible: Bool) -> DocumentMutationResult {
        execute(.attribute(.setFolderVisibility(folderID: folderID, isVisible: visible)))
    }

    package func setFolderName(_ folderID: Int, name: String) -> DocumentMutationResult {
        execute(.attribute(.setFolderName(folderID: folderID, name: name)))
    }

    package func setLayerBlendMode(_ index: Int, blendMode: LayerBlendMode) -> DocumentMutationResult {
        execute(.attribute(.setLayerBlendMode(index: index, blendMode: blendMode)))
    }

    package func setLayerName(_ index: Int, name: String) -> DocumentMutationResult {
        execute(.attribute(.setLayerName(index: index, name: name)))
    }

    package func replaceLayerPixels(_ index: Int, pixelData: LayerPixelData) -> DocumentMutationResult {
        executeContent(.replacePixels(index: index, pixelData: pixelData))
    }

    package func replaceLayerPixels(_ index: Int, pixelData: Data) -> DocumentMutationResult {
        let geometry: PixelGeometry
        switch documentQueryGateway.lightweightPresentation() {
        case let .failure(failure):
            return .failure(failure)
        case let .success(presentation):
            geometry = presentation.geometry
        }
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

    package func applyLayerProcessing(_ index: Int, request: LayerProcessingRequest) -> DocumentMutationResult {
        let geometry: PixelGeometry
        switch documentQueryGateway.lightweightPresentation() {
        case let .failure(failure):
            return .failure(failure)
        case let .success(presentation):
            geometry = presentation.geometry
        }
        guard ValidatedLayerProcessingRequest(request, canvasGeometry: geometry) != nil else {
            return .failure(.invalidLayerProcessingRequest(
                ValidatedLayerProcessingRequest.validationFailure(for: request, canvasGeometry: geometry) ?? "unknown"
            ))
        }
        return executeContent(.applyProcessing(index: index, request: request))
    }

    package func setTextLayer(_ index: Int, textLayer: TextLayerData) -> DocumentMutationResult {
        executeContent(.setTextLayer(index: index, textLayer: textLayer))
    }

    package func clearLayer(_ index: Int) -> DocumentMutationResult {
        executeContent(.clear(index: index))
    }

    package func replaceLayerMask(_ index: Int, maskData: Data) -> DocumentMutationResult {
        let geometry: PixelGeometry
        switch documentQueryGateway.lightweightPresentation() {
        case let .failure(failure):
            return .failure(failure)
        case let .success(presentation):
            geometry = presentation.geometry
        }
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

    package func clearLayerMask(_ index: Int) -> DocumentMutationResult {
        executeContent(.clearMask(index: index))
    }

    package func applyLayerMask(_ index: Int) -> DocumentMutationResult {
        executeContent(.applyMask(index: index))
    }

    private func requireCurrent(_ index: ExistingLayerIndex) -> Result<ExistingLayerIndex, DocumentMutationFailure> {
        currentMutationContext().flatMap { context in
            guard index.revision == context.revision else {
                return .failure(
                    .staleLayerIndex(
                        index: index.rawValue,
                        validationRevision: index.revision,
                        currentRevision: context.revision
                    )
                )
            }
            guard let currentIndex = context.existingLayerIndex(index.rawValue) else {
                return .failure(.invalidLayerIndex(index.rawValue))
            }
            return .success(currentIndex)
        }
    }

    private func requireCurrent(_ folderID: ExistingFolderID) -> Result<ExistingFolderID, DocumentMutationFailure> {
        currentMutationContext().flatMap { context in
            guard folderID.revision == context.revision else {
                return .failure(
                    .staleFolderID(
                        folderID: folderID.rawValue,
                        validationRevision: folderID.revision,
                        currentRevision: context.revision
                    )
                )
            }
            guard let currentFolderID = context.existingFolderID(folderID.rawValue) else {
                return .failure(.invalidFolderID(folderID.rawValue))
            }
            return .success(currentFolderID)
        }
    }

    private func requireCurrent(_ folderID: ExistingFolderID?) -> Result<ExistingFolderID?, DocumentMutationFailure> {
        guard let folderID else { return .success(nil) }
        return requireCurrent(folderID).map(Optional.some)
    }

    private func requireEditable(_ index: EditableLayerIndex) -> Result<EditableLayerIndex, DocumentMutationFailure> {
        currentMutationContext().flatMap { context in
            guard index.revision == context.revision else {
                return .failure(
                    .staleLayerIndex(
                        index: index.rawValue,
                        validationRevision: index.revision,
                        currentRevision: context.revision
                    )
                )
            }
            guard let currentIndex = context.editableLayerIndex(index.rawValue) else {
                if (0..<context.layerCount).contains(index.rawValue), context.isLayerLocked(index.rawValue) {
                    return .failure(.layerLocked(index.rawValue))
                }
                return .failure(.invalidLayerIndex(index.rawValue))
            }
            return .success(currentIndex)
        }
    }

    private func validatePixelData(
        _ pixelData: LayerPixelData,
        operation: String
    ) -> Result<LayerPixelData, DocumentMutationFailure> {
        currentCanvasGeometry().flatMap { geometry in
            guard pixelData.width == geometry.width, pixelData.height == geometry.height else {
                return .failure(
                    .gpu(
                        .invalidPayloadSize(
                            operation: operation,
                            expected: geometry.rgbaByteCount,
                            actual: pixelData.rgba.count
                        )
                    )
                )
            }
            return .success(pixelData)
        }
    }

    private func validateMaskData(
        _ mask: LayerMaskData,
        operation: String
    ) -> Result<LayerMaskData, DocumentMutationFailure> {
        currentCanvasGeometry().flatMap { geometry in
            guard mask.width == geometry.width, mask.height == geometry.height else {
                return .failure(
                    .gpu(
                        .invalidPayloadSize(
                            operation: operation,
                            expected: geometry.maskByteCount,
                            actual: mask.bytes.count
                        )
                    )
                )
            }
            return .success(mask)
        }
    }

    private func validatedProcessingRequest(
        _ request: LayerProcessingRequest
    ) -> Result<ValidatedLayerProcessingRequest, DocumentMutationFailure> {
        currentCanvasGeometry().flatMap { geometry in
            guard let validatedRequest = ValidatedLayerProcessingRequest(request, canvasGeometry: geometry) else {
                return .failure(.invalidLayerProcessingRequest(
                    ValidatedLayerProcessingRequest.validationFailure(for: request, canvasGeometry: geometry) ?? "unknown"
                ))
            }
            return .success(validatedRequest)
        }
    }

    private func currentCanvasGeometry() -> Result<PixelGeometry, DocumentMutationFailure> {
        switch documentQueryGateway.lightweightPresentation() {
        case let .failure(failure):
            return .failure(failure)
        case let .success(presentation):
            return .success(presentation.geometry)
        }
    }

    private func currentMutationContext() -> Result<DocumentLayerMutationContext, DocumentMutationFailure> {
        switch documentQueryGateway.lightweightPresentation() {
        case let .failure(failure):
            return .failure(failure)
        case let .success(presentation):
            return .success(DocumentLayerMutationContext(
                revision: presentation.revision,
                layerCount: presentation.layerRows.count,
                folderIDs: Set(
                    presentation.layerSidebarRows.compactMap { row in
                        guard case let .folder(folder) = row else { return nil }
                        return folder.id
                    }
                ),
                canvasGeometry: presentation.geometry,
                isLayerLocked: { index in
                    presentation.layerRows.first(where: { $0.index == index })?.isLocked ?? false
                }
            ))
        }
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
