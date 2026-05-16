import Foundation
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain

public enum LayerContentMutationTarget: Equatable, Sendable {
    case existingLayer(index: EditableLayerIndex)
    case newLayer(name: String)
}

public struct AppliedLayerContentMutation: Equatable, Sendable {
    public let targetLayerIndex: Int

    public init(targetLayerIndex: Int) {
        self.targetLayerIndex = targetLayerIndex
    }
}

public struct SelectionTransformCommit: Equatable, Sendable {
    public enum Payload: Equatable, Sendable {
        case text(layerIndex: Int, textLayer: TextLayerData)
        case pixels(layerIndex: Int, pixelData: Data, selection: CanvasSelection?)
    }

    public let payload: Payload

    public init(payload: Payload) {
        self.payload = payload
    }
}

public struct DocumentContentService: Sendable {
    package let documentQueryGateway: DocumentQueryGateway
    package let documentRenderGateway: DocumentRenderGateway
    package let documentEditingGateway: DocumentEditingGateway
    package let documentMutationGateway: DocumentMutationGateway

    package init(
        documentQueryGateway: DocumentQueryGateway,
        documentRenderGateway: DocumentRenderGateway,
        documentEditingGateway: DocumentEditingGateway,
        documentMutationGateway: DocumentMutationGateway
    ) {
        self.documentQueryGateway = documentQueryGateway
        self.documentRenderGateway = documentRenderGateway
        self.documentEditingGateway = documentEditingGateway
        self.documentMutationGateway = documentMutationGateway
    }

    package func setTextLayer(
        _ layerIndex: Int,
        _ textLayer: TextLayerData
    ) -> DocumentMutationResult {
        executeContent(.setTextLayer(index: layerIndex, textLayer: textLayer))
    }

    public func pixelDataForLayer(_ layerIndex: ExistingLayerIndex) -> Result<LayerPixelData, DocumentMutationFailure> {
        let presentation: PaintDocumentPresentation
        switch documentQueryGateway.lightweightPresentation() {
        case let .failure(failure):
            return .failure(failure)
        case let .success(currentPresentation):
            presentation = currentPresentation
        }
        guard layerIndex.revision == presentation.revision else {
            return .failure(
                .staleLayerIndex(
                    index: layerIndex.rawValue,
                    validationRevision: layerIndex.revision,
                    currentRevision: presentation.revision
                )
            )
        }
        return documentRenderGateway.pixelDataForLayer(layerIndex.rawValue).flatMap { data in
            guard let payload = LayerPixelData(
                width: presentation.geometry.width,
                height: presentation.geometry.height,
                rgba: data
            ) else {
                return .failure(
                    .gpu(
                        .invalidPayloadSize(
                            operation: "pixelDataForLayer",
                            expected: presentation.geometry.rgbaByteCount,
                            actual: data.count
                        )
                    )
                )
            }
            return .success(payload)
        }
    }

    package func pixelDataForLayer(_ layerIndex: Int) -> Result<Data, DocumentMutationFailure> {
        documentRenderGateway.pixelDataForLayer(layerIndex)
    }

    package func replaceLayerPixels(
        _ layerIndex: Int,
        _ pixelData: Data
    ) -> DocumentMutationResult {
        switch editableLayerIndex(layerIndex) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(index):
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
            return executeContent(.replacePixels(index: index.rawValue, pixelData: payload))
        }
    }

    public func replaceLayerPixels(
        _ command: LayerPixelReplacementCommand
    ) -> DocumentMutationResult {
        let presentation: PaintDocumentPresentation
        switch documentQueryGateway.lightweightPresentation() {
        case let .failure(failure):
            return .failure(failure)
        case let .success(currentPresentation):
            presentation = currentPresentation
        }
        let index = command.index
        guard index.revision == presentation.revision else {
            return .failure(
                .staleLayerIndex(
                    index: index.rawValue,
                    validationRevision: index.revision,
                    currentRevision: presentation.revision
                )
            )
        }
        guard (0..<presentation.layerRows.count).contains(index.rawValue) else {
            return .failure(.invalidLayerIndex(index.rawValue))
        }
        if presentation.layerRows.first(where: { $0.index == index.rawValue })?.isLocked == true {
            return .failure(.layerLocked(index.rawValue))
        }
        let geometry = presentation.geometry
        guard command.pixelData.width == geometry.width,
              command.pixelData.height == geometry.height else {
            return .failure(
                .gpu(
                    .invalidPayloadSize(
                        operation: "replaceLayerPixels",
                        expected: geometry.rgbaByteCount,
                        actual: command.pixelData.rgba.count
                    )
                )
            )
        }
        return executeContent(.replacePixels(index: index.rawValue, pixelData: command.pixelData))
    }

    public func applyPixels(
        _ pixelData: LayerPixelData,
        to target: LayerContentMutationTarget
    ) -> Result<AppliedLayerContentMutation, DocumentMutationFailure> {
        let geometry: PixelGeometry
        switch documentQueryGateway.lightweightPresentation() {
        case let .failure(failure):
            return .failure(failure)
        case let .success(presentation):
            geometry = presentation.geometry
        }

        let resolvedTarget: (index: Int, createdNewLayer: Bool, originalActiveLayerIndex: Int)
        switch resolve(target) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(target):
            resolvedTarget = target
        }

        guard pixelData.width == geometry.width,
              pixelData.height == geometry.height else {
            if let rollbackFailure = rollbackResolvedTargetIfNeeded(resolvedTarget) {
                return .failure(
                    .transactionFailure(
                        primary: .gpu(
                            .invalidPayloadSize(
                                operation: "applyPixels",
                                expected: geometry.rgbaByteCount,
                                actual: pixelData.rgba.count
                            )
                        ),
                        rollback: rollbackFailure
                    )
                )
            }
            return .failure(
                .gpu(
                    .invalidPayloadSize(
                        operation: "applyPixels",
                        expected: geometry.rgbaByteCount,
                        actual: pixelData.rgba.count
                    )
                )
            )
        }

        switch executeContent(.replacePixels(index: resolvedTarget.index, pixelData: pixelData)) {
        case let .failure(failure):
            if let rollbackFailure = rollbackResolvedTargetIfNeeded(resolvedTarget) {
                return .failure(
                    .transactionFailure(
                        primary: failure,
                        rollback: rollbackFailure
                    )
                )
            }
            return .failure(failure)
        case .success:
            switch documentMutationGateway.setActiveLayer(resolvedTarget.index) {
            case let .failure(failure):
                if let rollbackFailure = rollbackResolvedTargetIfNeeded(resolvedTarget) {
                    return .failure(
                        .transactionFailure(
                            primary: failure,
                            rollback: rollbackFailure
                        )
                    )
                }
                return .failure(failure)
            case .success:
                return .success(AppliedLayerContentMutation(targetLayerIndex: resolvedTarget.index))
            }
        }
    }

    package func applyPixels(
        _ pixelData: Data,
        to target: LayerContentMutationTarget
    ) -> Result<AppliedLayerContentMutation, DocumentMutationFailure> {
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
                        operation: "applyPixels",
                        expected: geometry.rgbaByteCount,
                        actual: pixelData.count
                    )
                )
            )
        }
        return applyPixels(payload, to: target)
    }

    public func applyTextLayer(
        _ textLayer: TextLayerData,
        to target: LayerContentMutationTarget
    ) -> Result<AppliedLayerContentMutation, DocumentMutationFailure> {
        apply(target: target) { targetLayerIndex in
            switch executeContent(.setTextLayer(index: targetLayerIndex, textLayer: textLayer)) {
            case let .failure(failure):
                return .failure(failure)
            case .success:
                return documentMutationGateway.setActiveLayer(targetLayerIndex)
            }
        }
    }

    private func apply(
        target: LayerContentMutationTarget,
        mutation: (Int) -> DocumentMutationResult
    ) -> Result<AppliedLayerContentMutation, DocumentMutationFailure> {
        let resolvedTarget: (index: Int, createdNewLayer: Bool, originalActiveLayerIndex: Int)
        switch resolve(target) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(target):
            resolvedTarget = target
        }
        switch mutation(resolvedTarget.index) {
        case let .failure(failure):
            if let rollbackFailure = rollbackResolvedTargetIfNeeded(resolvedTarget) {
                return .failure(
                    .transactionFailure(
                        primary: failure,
                        rollback: rollbackFailure
                    )
                )
            }
            return .failure(failure)
        case .success:
            return .success(
                AppliedLayerContentMutation(
                    targetLayerIndex: resolvedTarget.index
                )
            )
        }
    }

    private func executeContent(_ command: LayerContentMutationCommand) -> DocumentMutationResult {
        documentEditingGateway.execute(.content(command)).map { _ in () }
    }

    private func resolve(
        _ target: LayerContentMutationTarget
    ) -> Result<(index: Int, createdNewLayer: Bool, originalActiveLayerIndex: Int), DocumentMutationFailure> {
        let originalActiveLayerIndex: Int
        switch documentQueryGateway.lightweightPresentation() {
        case let .failure(failure):
            return .failure(failure)
        case let .success(presentation):
            originalActiveLayerIndex = presentation.activeLayerIndex
        }
        switch target {
        case let .existingLayer(index):
            switch editableLayerIndex(index) {
            case let .failure(failure):
                return .failure(failure)
            case let .success(index):
                return .success((index.rawValue, false, originalActiveLayerIndex))
            }
        case let .newLayer(name):
            switch documentMutationGateway.addLayer(name) {
            case let .success(index):
                return .success((index.rawValue, true, originalActiveLayerIndex))
            case let .failure(failure):
                return .failure(failure)
            }
        }
    }

    private func rollbackResolvedTargetIfNeeded(
        _ resolvedTarget: (index: Int, createdNewLayer: Bool, originalActiveLayerIndex: Int)
    ) -> DocumentMutationFailure? {
        var rollbackFailure: DocumentMutationFailure?
        if resolvedTarget.createdNewLayer, resolvedTarget.index >= 0 {
            switch documentMutationGateway.deleteLayer(resolvedTarget.index) {
            case .success:
                break
            case let .failure(failure):
                rollbackFailure = .rollbackFailed(operation: "deleteResolvedNewLayer", underlying: failure)
            }
        }
        switch documentMutationGateway.setActiveLayer(resolvedTarget.originalActiveLayerIndex) {
        case .success:
            break
        case let .failure(failure):
            let activeLayerRollbackFailure = DocumentMutationFailure.rollbackFailed(
                operation: "restoreOriginalActiveLayer",
                underlying: failure
            )
            if let rollbackFailure {
                return .transactionFailure(
                    primary: rollbackFailure,
                    rollback: activeLayerRollbackFailure
                )
            }
            return activeLayerRollbackFailure
        }
        return rollbackFailure
    }

    private func editableLayerIndex(_ rawValue: Int) -> Result<EditableLayerIndex, DocumentMutationFailure> {
        let context: DocumentLayerMutationContext
        switch layerMutationContext() {
        case let .failure(failure):
            return .failure(failure)
        case let .success(mutationContext):
            context = mutationContext
        }
        guard let index = context.editableLayerIndex(rawValue) else {
            if context.containsLayerIndex(rawValue), context.isLayerLocked(rawValue) {
                return .failure(.layerLocked(rawValue))
            }
            return .failure(.invalidLayerIndex(rawValue))
        }
        return .success(index)
    }

    private func editableLayerIndex(_ index: EditableLayerIndex) -> Result<EditableLayerIndex, DocumentMutationFailure> {
        let context: DocumentLayerMutationContext
        switch layerMutationContext() {
        case let .failure(failure):
            return .failure(failure)
        case let .success(mutationContext):
            context = mutationContext
        }
        guard index.revision == context.revision else {
            return .failure(
                .staleLayerIndex(
                    index: index.rawValue,
                    validationRevision: index.revision,
                    currentRevision: context.revision
                )
            )
        }
        guard let validated = context.editableLayerIndex(index.rawValue) else {
            if context.containsLayerIndex(index.rawValue), context.isLayerLocked(index.rawValue) {
                return .failure(.layerLocked(index.rawValue))
            }
            return .failure(.invalidLayerIndex(index.rawValue))
        }
        return .success(validated)
    }

    private func layerMutationContext() -> Result<DocumentLayerMutationContext, DocumentMutationFailure> {
        let presentation: PaintDocumentPresentation
        switch documentQueryGateway.lightweightPresentation() {
        case let .failure(failure):
            return .failure(failure)
        case let .success(currentPresentation):
            presentation = currentPresentation
        }
        return .success(DocumentLayerMutationContext(
            revision: presentation.revision,
            layerIndexes: presentation.layerRows.map(\.index),
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
