import Foundation
import PrimoDocumentDomain
import PrimoDocumentMutationContracts
import PrimoDocumentPresentationContracts

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

    package init?(_ rawValue: LayerProcessingRequest, canvasGeometry: PixelGeometry? = nil) {
        guard Self.validationFailure(for: rawValue, canvasGeometry: canvasGeometry) == nil else { return nil }
        self.rawValue = rawValue
    }

    package static func validationFailure(
        for request: LayerProcessingRequest,
        canvasGeometry: PixelGeometry? = nil
    ) -> String? {
        switch request {
        case let .transform(request):
            guard let boundedRequest = CanvasBoundedTransformRequest(
                request,
                canvasGeometry: canvasGeometry
            ) else {
                return "transform"
            }
            _ = boundedRequest
            return nil
        default:
            return nil
        }
    }
}

public struct CanvasBoundedTransformRequest: Equatable, Sendable {
    public let translation: FiniteTranslation
    public let scale: TransformScale
    public let rotationDegrees: RotationDegrees
    public let selection: CanvasSelection?

    package init?(
        _ request: LayerTransformProcessingRequest,
        canvasGeometry: PixelGeometry?
    ) {
        guard Self.isValid(selection: request.selection, canvasGeometry: canvasGeometry) else {
            return nil
        }
        self.translation = request.translation
        self.scale = request.scale
        self.rotationDegrees = request.rotationDegrees
        self.selection = request.selection
    }

    private static func isValid(selection: CanvasSelection?, canvasGeometry: PixelGeometry?) -> Bool {
        guard let selection else { return true }
        guard let canvasGeometry else { return false }
        guard let selectionGeometry = PixelGeometry(width: selection.maskWidth, height: selection.maskHeight),
              selection.maskData.count == selectionGeometry.maskByteCount else {
            return false
        }
        return selection.bounds.isFiniteAndCanvasBounded(
            width: canvasGeometry.width,
            height: canvasGeometry.height
        )
    }
}

private extension CGRect {
    func isFiniteAndCanvasBounded(width: Int, height: Int) -> Bool {
        guard origin.x.isFinite,
              origin.y.isFinite,
              size.width.isFinite,
              size.height.isFinite,
              !isNull,
              !isEmpty else {
            return false
        }
        return minX >= 0 &&
            minY >= 0 &&
            maxX <= CGFloat(width) &&
            maxY <= CGFloat(height)
    }
}

// Content commands join the same authoritative validation path as structure
// and attribute commands: the use case emits revision-aware EditableLayerIndex
// values, and the live gateway rejects stale indexes before raw mutation.
package enum UncheckedLayerContentMutationCommand: Equatable, Sendable {
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

public protocol LayerContentGateway: Sendable {
    func replaceLayerPixels(index: EditableLayerIndex, pixelData: LayerPixelData) -> DocumentLayerMutationResult
    func setTextLayer(index: EditableLayerIndex, textLayer: TextLayerData) -> DocumentLayerMutationResult
    func clearLayer(index: EditableLayerIndex) -> DocumentLayerMutationResult
    func applyLayerProcessing(index: EditableLayerIndex, request: ValidatedLayerProcessingRequest) -> DocumentLayerMutationResult
    func replaceLayerMask(index: EditableLayerIndex, mask: LayerMaskData) -> DocumentLayerMutationResult
    func clearLayerMask(index: EditableLayerIndex) -> DocumentLayerMutationResult
    func applyLayerMask(index: EditableLayerIndex) -> DocumentLayerMutationResult
}

package struct LayerContentMutationCommandValidator: Sendable {
    package init() {}

    package func validated(
        _ command: UncheckedLayerContentMutationCommand,
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
                guard let request = ValidatedLayerProcessingRequest(
                    request,
                    canvasGeometry: context.canvasGeometry
                ) else {
                    return .failure(.invalidLayerProcessingRequest(
                        ValidatedLayerProcessingRequest.validationFailure(
                            for: request,
                            canvasGeometry: context.canvasGeometry
                        ) ?? "unknown"
                    ))
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
        guard let index = context.editableLayerIndex(rawValue) else {
            if context.containsLayerIndex(rawValue), context.isLayerLocked(rawValue) {
                return .failure(.layerLocked(rawValue))
            }
            return .failure(.invalidLayerIndex(rawValue))
        }
        return .success(index)
    }
}

package struct LayerContentMutationUseCase: Sendable {
    private let validator: LayerContentMutationCommandValidator

    package init(validator: LayerContentMutationCommandValidator = .init()) {
        self.validator = validator
    }

    package func execute(
        _ command: UncheckedLayerContentMutationCommand,
        in context: DocumentLayerMutationContext,
        gateway: any LayerContentGateway
    ) -> DocumentLayerMutationResult {
        let validatedCommand: ValidatedLayerContentMutationCommand
        switch validator.validated(command, in: context) {
        case let .failure(failure):
            return .failure(failure)
        case let .success(validated):
            validatedCommand = validated
        }

        switch validatedCommand {
        case let .replacePixels(index, pixelData):
            return gateway.replaceLayerPixels(index: index, pixelData: pixelData)
        case let .setTextLayer(index, textLayer):
            return gateway.setTextLayer(index: index, textLayer: textLayer)
        case let .clear(index):
            return gateway.clearLayer(index: index)
        case let .applyProcessing(index, request):
            return gateway.applyLayerProcessing(index: index, request: request)
        case let .replaceMask(index, mask):
            return gateway.replaceLayerMask(index: index, mask: mask)
        case let .clearMask(index):
            return gateway.clearLayerMask(index: index)
        case let .applyMask(index):
            return gateway.applyLayerMask(index: index)
        }
    }
}
