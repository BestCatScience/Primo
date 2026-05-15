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

public struct LayerPixelReplacementCommand: Equatable, Sendable {
    public let index: EditableLayerIndex
    public let pixelData: LayerPixelData

    public init(index: EditableLayerIndex, pixelData: LayerPixelData) {
        self.index = index
        self.pixelData = pixelData
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

public struct ValidatedLayerProcessingRequest: Equatable, Sendable {
    public let rawValue: LayerProcessingRequest

    package init?(_ rawValue: LayerProcessingRequest) {
        guard Self.isValid(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    private static func isValid(_ request: LayerProcessingRequest) -> Bool {
        switch request {
        case let .transform(translation, scale, rotationDegrees, _):
            return translation.width.isFinite &&
                translation.height.isFinite &&
                scale.isFinite &&
                scale > 0 &&
                rotationDegrees.isFinite
        default:
            return true
        }
    }
}

// Content commands join the same authoritative validation path as structure
// and attribute commands: the use case emits revision-aware EditableLayerIndex
// values, and the live gateway rejects stale indexes before raw mutation.
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

public struct LayerContentMutationPlan: Equatable, Sendable {
    public init() {}
}

public protocol LayerContentGateway: Sendable {
    func replaceLayerPixels(index: EditableLayerIndex, pixelData: LayerPixelData) -> DocumentLayerMutationResult
    func setTextLayer(index: EditableLayerIndex, textLayer: TextLayerData) -> DocumentLayerMutationResult
    func clearLayer(index: EditableLayerIndex) -> DocumentLayerMutationResult
    func applyLayerProcessing(index: EditableLayerIndex, request: ValidatedLayerProcessingRequest) -> DocumentLayerMutationResult
    func replaceLayerMask(index: EditableLayerIndex, mask: LayerMaskData) -> DocumentLayerMutationResult
    func clearLayerMask(index: EditableLayerIndex) -> DocumentLayerMutationResult
    func applyLayerMask(index: EditableLayerIndex) -> DocumentLayerMutationResult
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
            return editableLayer(index, in: context).flatMap { index in
                guard let request = ValidatedLayerProcessingRequest(request) else {
                    return .failure(.invalidLayerProcessingRequest("transform"))
                }
                return .success(.applyProcessing(index: index, request: request))
            }
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

public struct LayerContentMutationUseCase: Sendable {
    private let validator: LayerContentMutationCommandValidator

    public init(validator: LayerContentMutationCommandValidator = .init()) {
        self.validator = validator
    }

    public func execute(
        _ command: LayerContentMutationCommand,
        in context: DocumentLayerMutationContext,
        gateway: any LayerContentGateway
    ) -> Result<LayerContentMutationPlan, DocumentLayerMutationFailure> {
        let validatedCommand: ValidatedLayerContentMutationCommand
        switch validator.validated(command, in: context) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(validated):
            validatedCommand = validated
        }

        switch validatedCommand {
        case let .replacePixels(index, pixelData):
            return gateway.replaceLayerPixels(index: index, pixelData: pixelData).map { LayerContentMutationPlan() }
        case let .setTextLayer(index, textLayer):
            return gateway.setTextLayer(index: index, textLayer: textLayer).map { LayerContentMutationPlan() }
        case let .clear(index):
            return gateway.clearLayer(index: index).map { LayerContentMutationPlan() }
        case let .applyProcessing(index, request):
            return gateway.applyLayerProcessing(index: index, request: request).map { LayerContentMutationPlan() }
        case let .replaceMask(index, mask):
            return gateway.replaceLayerMask(index: index, mask: mask).map { LayerContentMutationPlan() }
        case let .clearMask(index):
            return gateway.clearLayerMask(index: index).map { LayerContentMutationPlan() }
        case let .applyMask(index):
            return gateway.applyLayerMask(index: index).map { LayerContentMutationPlan() }
        }
    }
}
