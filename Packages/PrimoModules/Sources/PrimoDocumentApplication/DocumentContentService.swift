import Foundation
import PrimoDocumentMutationContracts
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
    package let documentMutationGateway: DocumentMutationGateway
    package let textLayerGateway: TextLayerGateway

    public init(
        documentQueryGateway: DocumentQueryGateway,
        documentRenderGateway: DocumentRenderGateway,
        documentMutationGateway: DocumentMutationGateway,
        textLayerGateway: TextLayerGateway
    ) {
        self.documentQueryGateway = documentQueryGateway
        self.documentRenderGateway = documentRenderGateway
        self.documentMutationGateway = documentMutationGateway
        self.textLayerGateway = textLayerGateway
    }

    public func setTextLayer(
        _ layerIndex: Int,
        _ textLayer: TextLayerData
    ) -> DocumentMutationResult {
        switch existingLayerIndex(layerIndex) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(index):
            return textLayerGateway.setTextLayer(index.rawValue, textLayer)
        }
    }

    public func pixelDataForLayer(_ layerIndex: Int) -> Data {
        documentRenderGateway.pixelDataForLayer(layerIndex)
    }

    public func replaceLayerPixels(
        _ layerIndex: Int,
        _ pixelData: Data
    ) -> DocumentMutationResult {
        switch existingLayerIndex(layerIndex) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(index):
            return documentMutationGateway.replaceLayerPixels(index.rawValue, pixelData)
        }
    }

    public func applyPixels(
        _ pixelData: Data,
        to target: LayerContentMutationTarget
    ) -> Result<AppliedLayerContentMutation, DocumentMutationFailure> {
        apply(target: target) { targetLayerIndex in
            switch documentMutationGateway.replaceLayerPixels(targetLayerIndex, pixelData) {
            case let .failure(failure):
                return .failure(failure)
            case .success:
                return documentMutationGateway.setActiveLayer(targetLayerIndex)
            }
        }
    }

    public func applyTextLayer(
        _ textLayer: TextLayerData,
        to target: LayerContentMutationTarget
    ) -> Result<AppliedLayerContentMutation, DocumentMutationFailure> {
        apply(target: target) { targetLayerIndex in
            switch textLayerGateway.setTextLayer(targetLayerIndex, textLayer) {
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

    private func resolve(
        _ target: LayerContentMutationTarget
    ) -> Result<(index: Int, createdNewLayer: Bool, originalActiveLayerIndex: Int), DocumentMutationFailure> {
        let originalActiveLayerIndex = documentQueryGateway.lightweightPresentation().activeLayerIndex
        switch target {
        case let .existingLayer(index):
            switch existingLayerIndex(index) {
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

    private func existingLayerIndex(_ rawValue: Int) -> Result<ExistingLayerIndex, DocumentMutationFailure> {
        let context = layerMutationContext()
        guard let index = context.existingLayerIndex(rawValue) else {
            return .failure(.invalidLayerIndex(rawValue))
        }
        return .success(index)
    }

    private func layerMutationContext() -> DocumentLayerMutationContext {
        let presentation = documentQueryGateway.lightweightPresentation()
        return DocumentLayerMutationContext(
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
