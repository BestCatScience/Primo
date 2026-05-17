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

public struct CanvasBoundedTransformRequest: Equatable, Sendable {
    public let translation: FiniteTranslation
    public let scale: TransformScale
    public let rotationDegrees: RotationDegrees
    public let selection: CanvasSelection?

    public init?(
        translation: FiniteTranslation,
        scale: TransformScale,
        rotationDegrees: RotationDegrees,
        selection: CanvasSelection?,
        canvasGeometry: PixelGeometry?
    ) {
        guard Self.isValid(selection: selection, canvasGeometry: canvasGeometry) else {
            return nil
        }
        self.translation = translation
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.selection = selection
    }

    public init?(
        _ request: LayerTransformProcessingRequest,
        canvasGeometry: PixelGeometry?
    ) {
        self.init(
            translation: request.translation,
            scale: request.scale,
            rotationDegrees: request.rotationDegrees,
            selection: request.selection,
            canvasGeometry: canvasGeometry
        )
    }

    public var rawValue: LayerTransformProcessingRequest {
        LayerTransformProcessingRequest(
            translation: translation,
            scale: scale,
            rotationDegrees: rotationDegrees,
            selection: selection
        )
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

public enum ValidatedLayerProcessingRequest: Equatable, Sendable {
    case gradientMap(GradientMapPreset)
    case gradientMapSettings(GradientMapSettings)
    case hueSaturationBrightness(HueSaturationBrightnessSettings)
    case brightnessContrast(BrightnessContrastSettings)
    case levels(LevelsAdjustmentSettings)
    case toneCurve(ToneCurveSettings)
    case colorBalance(ColorBalanceSettings)
    case threshold(ThresholdSettings)
    case posterize(PosterizeSettings)
    case luminanceToAlpha
    case transform(CanvasBoundedTransformRequest)

    public var rawValue: LayerProcessingRequest {
        switch self {
        case let .gradientMap(preset):
            return .gradientMap(preset)
        case let .gradientMapSettings(settings):
            return .gradientMapSettings(settings)
        case let .hueSaturationBrightness(settings):
            return .hueSaturationBrightness(settings)
        case let .brightnessContrast(settings):
            return .brightnessContrast(settings)
        case let .levels(settings):
            return .levels(settings)
        case let .toneCurve(settings):
            return .toneCurve(settings)
        case let .colorBalance(settings):
            return .colorBalance(settings)
        case let .threshold(settings):
            return .threshold(settings)
        case let .posterize(settings):
            return .posterize(settings)
        case .luminanceToAlpha:
            return .luminanceToAlpha
        case let .transform(command):
            return .transform(command.rawValue)
        }
    }

    package init?(_ rawValue: LayerProcessingRequest, canvasGeometry: PixelGeometry? = nil) {
        switch rawValue {
        case let .gradientMap(preset):
            self = .gradientMap(preset)
        case let .gradientMapSettings(settings):
            self = .gradientMapSettings(settings)
        case let .hueSaturationBrightness(settings):
            self = .hueSaturationBrightness(settings)
        case let .brightnessContrast(settings):
            self = .brightnessContrast(settings)
        case let .levels(settings):
            self = .levels(settings)
        case let .toneCurve(settings):
            self = .toneCurve(settings)
        case let .colorBalance(settings):
            self = .colorBalance(settings)
        case let .threshold(settings):
            self = .threshold(settings)
        case let .posterize(settings):
            self = .posterize(settings)
        case .luminanceToAlpha:
            self = .luminanceToAlpha
        case let .transform(request):
            guard let boundedRequest = CanvasBoundedTransformRequest(
                request,
                canvasGeometry: canvasGeometry
            ) else {
                return nil
            }
            self = .transform(boundedRequest)
        }
    }

    package static func validationFailure(
        for request: LayerProcessingRequest,
        canvasGeometry: PixelGeometry? = nil
    ) -> String? {
        switch request {
        case let .transform(request):
            guard CanvasBoundedTransformRequest(
                request,
                canvasGeometry: canvasGeometry
            ) != nil else {
                return "transform"
            }
            return nil
        default:
            return nil
        }
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
