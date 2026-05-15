import Foundation
import PrimoDocumentDomain
import PrimoDocumentMutationContracts

public struct LayerPixelData: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let rgba: Data

    public init?(width: Int, height: Int, rgba: Data) {
        guard let geometry = PixelGeometry(width: width, height: height),
              rgba.count == geometry.rgbaByteCount else {
            return nil
        }
        self.width = width
        self.height = height
        self.rgba = rgba
    }
}

public struct LayerMaskData: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let bytes: Data

    public init?(width: Int, height: Int, bytes: Data) {
        guard let geometry = PixelGeometry(width: width, height: height),
              bytes.count == geometry.maskByteCount else {
            return nil
        }
        self.width = width
        self.height = height
        self.bytes = bytes
    }
}

public typealias ValidatedLayerProcessingRequest = LayerProcessingRequest

public enum LayerContentMutationCommand: Equatable, Sendable {
    case replacePixels(index: Int, pixelData: LayerPixelData)
    case setTextLayer(index: Int, textLayer: TextLayerData)
    case clear(index: Int)
    case applyProcessing(index: Int, request: LayerProcessingRequest)
    case replaceMask(index: Int, mask: LayerMaskData)
    case clearMask(index: Int)
    case applyMask(index: Int)
}

public enum ValidatedLayerContentMutationCommand: Equatable, Sendable {
    case replacePixels(index: EditableLayerIndex, pixelData: LayerPixelData)
    case setTextLayer(index: EditableLayerIndex, textLayer: TextLayerData)
    case clear(index: EditableLayerIndex)
    case applyProcessing(index: EditableLayerIndex, request: ValidatedLayerProcessingRequest)
    case replaceMask(index: EditableLayerIndex, mask: LayerMaskData)
    case clearMask(index: EditableLayerIndex)
    case applyMask(index: EditableLayerIndex)
}

public struct LayerContentMutationCommandValidator: Sendable {
    public init() {}

    public func validated(
        _ command: LayerContentMutationCommand,
        in context: DocumentLayerMutationContext
    ) -> Result<ValidatedLayerContentMutationCommand, DocumentLayerMutationFailure> {
        switch command {
        case let .replacePixels(index, pixelData):
            return editableLayer(index, in: context).map { .replacePixels(index: $0, pixelData: pixelData) }
        case let .setTextLayer(index, textLayer):
            return editableLayer(index, in: context).map { .setTextLayer(index: $0, textLayer: textLayer) }
        case let .clear(index):
            return editableLayer(index, in: context).map { .clear(index: $0) }
        case let .applyProcessing(index, request):
            return editableLayer(index, in: context).map { .applyProcessing(index: $0, request: request) }
        case let .replaceMask(index, mask):
            return editableLayer(index, in: context).map { .replaceMask(index: $0, mask: mask) }
        case let .clearMask(index):
            return editableLayer(index, in: context).map { .clearMask(index: $0) }
        case let .applyMask(index):
            return editableLayer(index, in: context).map { .applyMask(index: $0) }
        }
    }

    private func editableLayer(
        _ rawValue: Int,
        in context: DocumentLayerMutationContext
    ) -> Result<EditableLayerIndex, DocumentLayerMutationFailure> {
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
}
