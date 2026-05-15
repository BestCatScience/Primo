import Foundation
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoDocumentDomain

public enum LayerContentMutationTarget: Equatable, Sendable {
    case existingLayer(index: Int)
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

    public init(
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

    public func setTextLayer(
        _ layerIndex: Int,
        _ textLayer: TextLayerData
    ) -> DocumentMutationResult {
        executeContent(.setTextLayer(index: layerIndex, textLayer: textLayer))
    }

    public func pixelDataForLayer(_ layerIndex: Int) -> Result<Data, DocumentMutationFailure> {
        documentRenderGateway.pixelDataForLayer(layerIndex)
    }

    public func replaceLayerPixels(
        _ layerIndex: Int,
        _ pixelData: Data
    ) -> DocumentMutationResult {
        switch editableLayerIndex(layerIndex) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(index):
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
            return executeContent(.replacePixels(index: index.rawValue, pixelData: payload))
        }
    }

    public func replaceLayerPixels(
        _ command: LayerPixelReplacementCommand
    ) -> DocumentMutationResult {
        let presentation = documentQueryGateway.lightweightPresentation()
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
        _ pixelData: Data,
        to target: LayerContentMutationTarget
    ) -> Result<AppliedLayerContentMutation, DocumentMutationFailure> {
        let resolvedTarget: (index: Int, createdNewLayer: Bool, originalActiveLayerIndex: Int)
        switch resolve(target) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(target):
            resolvedTarget = target
        }

        let geometry = documentQueryGateway.lightweightPresentation().geometry
        guard let payload = LayerPixelData(width: geometry.width, height: geometry.height, rgba: pixelData) else {
            if let rollbackFailure = rollbackResolvedTargetIfNeeded(resolvedTarget) {
                return .failure(
                    .transactionFailure(
                        primary: .gpu(
                            .invalidPayloadSize(
                                operation: "applyPixels",
                                expected: geometry.rgbaByteCount,
                                actual: pixelData.count
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
                        actual: pixelData.count
                    )
                )
            )
        }

        switch executeContent(.replacePixels(index: resolvedTarget.index, pixelData: payload)) {
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
        let originalActiveLayerIndex = documentQueryGateway.lightweightPresentation().activeLayerIndex
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
                return .success((index, true, originalActiveLayerIndex))
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
                rollbackFailure = failure
            }
        }
        switch documentMutationGateway.setActiveLayer(resolvedTarget.originalActiveLayerIndex) {
        case .success:
            break
        case let .failure(failure):
            if let rollbackFailure {
                return .transactionFailure(
                    primary: rollbackFailure,
                    rollback: failure
                )
            }
            return failure
        }
        return rollbackFailure
    }

    private func editableLayerIndex(_ rawValue: Int) -> Result<EditableLayerIndex, DocumentMutationFailure> {
        let context = layerMutationContext()
        guard let index = EditableLayerIndex.validated(
            rawValue,
            revision: context.revision,
            layerCount: context.layerCount,
            isLayerLocked: context.isLayerLocked
        ) else {
            if (0..<context.layerCount).contains(rawValue), context.isLayerLocked(rawValue) {
                return .failure(.layerLocked(rawValue))
            }
            return .failure(.invalidLayerIndex(rawValue))
        }
        return .success(index)
    }

    private func layerMutationContext() -> DocumentLayerMutationContext {
        let presentation = documentQueryGateway.lightweightPresentation()
        return DocumentLayerMutationContext(
            revision: presentation.revision,
            layerCount: presentation.layerRows.count,
            folderIDs: Set(
                presentation.layerSidebarRows.compactMap { row in
                    guard case let .folder(folder) = row else { return nil }
                    return folder.id
                }
            ),
            isLayerLocked: { index in
                presentation.layerRows.first(where: { $0.index == index })?.isLocked ?? false
            }
        )
    }
}
