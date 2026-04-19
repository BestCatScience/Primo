import CoreGraphics
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoNanoBananaDomain

public enum NanoBananaCommandBuilderFailure: Error, Equatable, Sendable {
    case promptRequired
    case apiKeyRequired
    case endpointRequired
    case entitlementRequired
}

public struct NanoBananaCommandBuilder: Sendable {
    public init() {}

    public func build(
        draft: NanoBananaDraft,
        apiKey: String,
        commerce: NanoBananaCommerceSnapshot
    ) -> Result<SubmitNanoBananaEditCommand, NanoBananaCommandBuilderFailure> {
        let trimmedPrompt = draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let prompt = NonEmptyPrompt(trimmedPrompt) else {
            return .failure(.promptRequired)
        }

        let descriptor = NanoBananaEditDescriptor(
            prompt: prompt,
            accessMode: draft.accessMode,
            model: draft.model,
            inputLayerIndex: draft.inputLayerIndex,
            editScope: draft.editScope,
            outputMode: draft.outputMode,
            maskSettings: draft.maskSettings
        )

        switch draft.accessMode {
        case .userAPIKey:
            guard let validAPIKey = NanoBananaAPIKey(apiKey) else {
                return .failure(.apiKeyRequired)
            }
            return .success(
                SubmitNanoBananaEditCommand(
                    descriptor: descriptor,
                    executionConfig: .userAPIKey(apiKey: validAPIKey)
                )
            )

        case .appManaged:
            guard let endpoint = ProxyEndpoint(commerce.proxyEndpoint) else {
                return .failure(.endpointRequired)
            }
            guard let entitlement = NanoBananaEntitlementToken(commerce.latestEntitlementJWS) else {
                return .failure(.entitlementRequired)
            }
            return .success(
                SubmitNanoBananaEditCommand(
                    descriptor: descriptor,
                    executionConfig: .appManaged(
                        entitlement: entitlement,
                        endpoint: endpoint
                    )
                )
            )
        }
    }
}

public struct NanoBananaEditExecutionRequest: Equatable, Sendable {
    public let inputPNGData: Data
    public let command: SubmitNanoBananaEditCommand

    public init(inputPNGData: Data, command: SubmitNanoBananaEditCommand) {
        self.inputPNGData = inputPNGData
        self.command = command
    }
}

public struct NanoBananaSelectionRegion: Equatable, Sendable {
    public let selectionBounds: CGRect
    public let expandedMask: [UInt8]

    public init(
        selectionBounds: CGRect,
        expandedMask: [UInt8]
    ) {
        self.selectionBounds = selectionBounds
        self.expandedMask = expandedMask
    }
}

public struct NanoBananaPreviewPreparationRequest: Equatable, Sendable {
    public let command: SubmitNanoBananaEditCommand
    public let selectionRegion: NanoBananaSelectionRegion?
    public let outputLayerIndex: Int
    public let canvasWidth: Int
    public let canvasHeight: Int
    public let sourceLayerPixelData: Data

    public init(
        command: SubmitNanoBananaEditCommand,
        selectionRegion: NanoBananaSelectionRegion?,
        outputLayerIndex: Int,
        canvasWidth: Int,
        canvasHeight: Int,
        sourceLayerPixelData: Data
    ) {
        self.command = command
        self.selectionRegion = selectionRegion
        self.outputLayerIndex = outputLayerIndex
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.sourceLayerPixelData = sourceLayerPixelData
    }
}

public enum NanoBananaPreviewPreparationFailure: Error, Equatable, Sendable {
    case unsupportedImage
    case editFailed(NanoBananaEditFailure)
}

public struct NanoBananaRemoteEditClient: Sendable {
    public var execute: @Sendable (NanoBananaEditExecutionRequest, String, NanoBananaModel) async -> Result<Data, NanoBananaEditFailure>

    public init(
        execute: @escaping @Sendable (NanoBananaEditExecutionRequest, String, NanoBananaModel) async -> Result<Data, NanoBananaEditFailure>
    ) {
        self.execute = execute
    }
}

public struct NanoBananaEditUseCase: Sendable {
    public var execute: @Sendable (NanoBananaEditExecutionRequest) async -> Result<Data, NanoBananaEditFailure>

    public init(
        execute: @escaping @Sendable (NanoBananaEditExecutionRequest) async -> Result<Data, NanoBananaEditFailure>
    ) {
        self.execute = execute
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public static func live(remoteClient: NanoBananaRemoteEditClient) -> NanoBananaEditUseCase {
        NanoBananaEditUseCase { request in
            let primaryPrompt = enforcedImageEditingPrompt(from: request.command.descriptor.prompt.rawValue)
            let retryPrompt = strictRetryImageEditingPrompt(from: request.command.descriptor.prompt.rawValue)
            var lastError: NanoBananaEditFailure?

            let candidateModels = retryModels(startingWith: request.command.descriptor.model)
            for round in 0..<3 {
                if round > 0 {
                    let delayNanoseconds = UInt64((0.8 + Double(round) * 0.9) * 1_000_000_000)
                    do {
                        try await Task.sleep(nanoseconds: delayNanoseconds)
                    } catch is CancellationError {
                        return .failure(.transport("Nano Banana generation was canceled."))
                    } catch {
                        return .failure(.transport(error.localizedDescription))
                    }
                }

                for candidateModel in candidateModels {
                    let primaryResult = await remoteClient.execute(request, primaryPrompt, candidateModel)
                    if case let .success(imageData) = primaryResult {
                        return .success(imageData)
                    }
                    if case let .failure(failure) = primaryResult {
                        lastError = failure
                        guard shouldRetryWithAnotherModel(after: failure) else {
                            return .failure(failure)
                        }
                    }

                    let retryResult = await remoteClient.execute(request, retryPrompt, candidateModel)
                    if case let .success(imageData) = retryResult {
                        return .success(imageData)
                    }
                    if case let .failure(failure) = retryResult {
                        lastError = failure
                        guard shouldRetryWithAnotherModel(after: failure) else {
                            return .failure(failure)
                        }
                    }
                }
            }

            if let lastError {
                return .failure(lastError)
            }
            return .failure(.missingImageData("Nano Banana did not return decodable image bytes."))
        }
    }

    private static func enforcedImageEditingPrompt(from prompt: String) -> String {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        Edit the supplied input image according to the user's request.
        Always return exactly one edited image as the result.
        Do not return text, markdown, explanations, captions, JSON, or analysis.
        Preserve the original composition unless the user explicitly asks to change it.
        If the request is ambiguous, make a reasonable visual edit and still return an image.

        User request:
        \(trimmedPrompt)
        """
    }

    private static func strictRetryImageEditingPrompt(from prompt: String) -> String {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        This is an image-to-image editing task.
        You must output exactly one edited image and no text whatsoever.
        Return no explanation, no markdown, no code block, no JSON, and no refusal text unless safety policy blocks image output.
        If the request can be fulfilled safely, edit the provided image directly and return only the edited image.
        Keep the canvas size and framing the same unless the user explicitly requested otherwise.

        User request:
        \(trimmedPrompt)
        """
    }

    private static func retryModels(startingWith initialModel: NanoBananaModel) -> [NanoBananaModel] {
        [initialModel] + NanoBananaModel.allCases.filter { $0 != initialModel }
    }

    private static func shouldRetryWithAnotherModel(after error: NanoBananaEditFailure) -> Bool {
        switch error {
        case let .apiError(message):
            let normalized = message.lowercased()
            return normalized.contains("high demand")
                || normalized.contains("please try again later")
                || normalized.contains("service unavailable")
                || normalized.contains("unavailable")
        default:
            return false
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct NanoBananaPreviewPreparationService: Sendable {
    public let editUseCase: NanoBananaEditUseCase

    public init(editUseCase: NanoBananaEditUseCase) {
        self.editUseCase = editUseCase
    }

    public func preparePreview(
        _ request: NanoBananaPreviewPreparationRequest
    ) async -> Result<NanoBananaPreviewState, NanoBananaPreviewPreparationFailure> {
        let beforePreviewImageData = DocumentRasterImageService.pngData(
            fromLayerPixelData: request.command.descriptor.outputMode == .replaceCurrentLayer
                ? request.sourceLayerPixelData
                : Data(repeating: 0, count: request.canvasWidth * request.canvasHeight * 4),
            width: request.canvasWidth,
            height: request.canvasHeight
        )

        let finalPixelData: Data?
        switch request.command.descriptor.editScope {
        case .wholeLayer:
            guard let inputPNGData = DocumentRasterImageService.pngData(
                fromLayerPixelData: request.sourceLayerPixelData,
                width: request.canvasWidth,
                height: request.canvasHeight
            ) else {
                finalPixelData = nil
                break
            }

            switch await executeEdit(
                request.command,
                inputPNGData: inputPNGData,
                cropScoped: false
            ) {
            case let .success(imageData):
                finalPixelData = DocumentRasterImageService.rawLayerPixelData(
                    fromPNGData: imageData,
                    width: request.canvasWidth,
                    height: request.canvasHeight
                )
            case let .failure(failure):
                return .failure(.editFailed(failure))
            }

        case .selectedArea:
            guard
                let selectionRegion = request.selectionRegion,
                let crop = DocumentRasterImageService.inpaintCrop(
                    source: request.sourceLayerPixelData,
                    canvasWidth: request.canvasWidth,
                    canvasHeight: request.canvasHeight,
                    selectionBounds: selectionRegion.selectionBounds,
                    expandedMask: selectionRegion.expandedMask
                ),
                let cropPNGData = DocumentRasterImageService.pngData(
                    fromLayerPixelData: crop.pixelData,
                    width: crop.width,
                    height: crop.height
                )
            else {
                finalPixelData = nil
                break
            }

            switch await executeEdit(
                request.command,
                inputPNGData: cropPNGData,
                cropScoped: true
            ) {
            case let .success(imageData):
                guard let editedCropPixelData = DocumentRasterImageService.rawLayerPixelData(
                    fromPNGData: imageData,
                    width: crop.width,
                    height: crop.height
                ) else {
                    finalPixelData = nil
                    break
                }

                let baseLayerPixelData = request.command.descriptor.outputMode == .replaceCurrentLayer
                    ? request.sourceLayerPixelData
                    : Data(repeating: 0, count: request.canvasWidth * request.canvasHeight * 4)
                finalPixelData = DocumentRasterImageService.applyingInpaintCrop(
                    editedCropPixelData,
                    to: baseLayerPixelData,
                    canvasWidth: request.canvasWidth,
                    canvasHeight: request.canvasHeight,
                    crop: crop
                )
            case let .failure(failure):
                return .failure(.editFailed(failure))
            }
        }

        guard let finalPixelData else {
            return .failure(.unsupportedImage)
        }

        return .success(
            NanoBananaPreviewState(
                descriptor: request.command.descriptor,
                outputLayerIndex: request.outputLayerIndex,
                pixelData: finalPixelData,
                beforePreviewImageData: beforePreviewImageData,
                afterPreviewImageData: DocumentRasterImageService.pngData(
                    fromLayerPixelData: finalPixelData,
                    width: request.canvasWidth,
                    height: request.canvasHeight
                )
            )
        )
    }

    private func executeEdit(
        _ command: SubmitNanoBananaEditCommand,
        inputPNGData: Data,
        cropScoped: Bool
    ) async -> Result<Data, NanoBananaEditFailure> {
        var adjustedCommand = command
        if cropScoped {
            let prompt = "Only edit the selected region. Keep everything outside the selected region unchanged.\n\n\(adjustedCommand.descriptor.prompt.rawValue)"
            guard let adjustedPrompt = NonEmptyPrompt(prompt) else {
                return .failure(.transport("Selected-area prompt normalization failed."))
            }
            adjustedCommand.descriptor.prompt = adjustedPrompt
        }

        return await editUseCase.execute(
            NanoBananaEditExecutionRequest(
                inputPNGData: inputPNGData,
                command: adjustedCommand
            )
        )
    }
}
