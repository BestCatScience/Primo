import CoreGraphics
import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentPresentationContracts
import PrimoAIImageDomain

public enum AIImageCommandBuilderFailure: Error, Equatable, Sendable {
    case promptRequired
    case apiKeyRequired
    case endpointRequired
    case entitlementRequired
    case unsupportedDirectOpenAIModel
}

public struct AIImageCommandBuilder: Sendable {
    public init() {}

    public func build(
        draft: AIImageDraft,
        settings: AIImageSettingsDraft,
        commerce: AIImageCommerceSnapshot
    ) -> Result<SubmitAIImageEditCommand, AIImageCommandBuilderFailure> {
        build(
            draft: draft,
            apiKey: settings.apiKey,
            openAIAPIKey: settings.openAIAPIKey,
            commerce: commerce
        )
    }

    public func build(
        draft: AIImageDraft,
        apiKey: String,
        openAIAPIKey: String,
        commerce: AIImageCommerceSnapshot
    ) -> Result<SubmitAIImageEditCommand, AIImageCommandBuilderFailure> {
        let trimmedPrompt = draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let prompt = NonEmptyPrompt(trimmedPrompt) else {
            return .failure(.promptRequired)
        }

        let descriptor = AIImageEditDescriptor(
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
            let selectedAPIKey = draft.model.provider == .openAI ? openAIAPIKey : apiKey
            if draft.model.provider == .openAI, !draft.model.supportsOpenAIDirectImageEdit {
                return .failure(.unsupportedDirectOpenAIModel)
            }
            guard let validAPIKey = AIImageAPIKey(selectedAPIKey) else {
                return .failure(.apiKeyRequired)
            }
            return .success(
                SubmitAIImageEditCommand(
                    descriptor: descriptor,
                    executionConfig: .userAPIKey(apiKey: validAPIKey)
                )
            )

        case .appManaged:
            guard let endpoint = ProxyEndpoint(commerce.proxyEndpoint) else {
                return .failure(.endpointRequired)
            }
            guard let entitlement = AIImageEntitlementToken(commerce.latestEntitlementJWS) else {
                return .failure(.entitlementRequired)
            }
            return .success(
                SubmitAIImageEditCommand(
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

public struct AIImageEditExecutionRequest: Equatable, Sendable {
    public let inputPNGData: Data
    public let command: SubmitAIImageEditCommand

    public init(inputPNGData: Data, command: SubmitAIImageEditCommand) {
        self.inputPNGData = inputPNGData
        self.command = command
    }
}

public struct AIImageSelectionRegion: Equatable, Sendable {
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

public struct AIImagePreviewPreparationRequest: Equatable, Sendable {
    public let command: SubmitAIImageEditCommand
    public let selectionRegion: AIImageSelectionRegion?
    public let outputLayerIndex: Int
    public let sourceSurface: DocumentCompositeSurface

    public init(
        command: SubmitAIImageEditCommand,
        selectionRegion: AIImageSelectionRegion?,
        outputLayerIndex: Int,
        sourceSurface: DocumentCompositeSurface
    ) {
        self.command = command
        self.selectionRegion = selectionRegion
        self.outputLayerIndex = outputLayerIndex
        self.sourceSurface = sourceSurface
    }
}

public enum AIImagePreviewPreparationFailure: Error, Equatable, Sendable {
    case unsupportedImage
    case editFailed(AIImageEditFailure)
}

public struct AIImageRemoteEditClient: Sendable {
    public let execute: @Sendable (AIImageEditExecutionRequest, String, AIImageModel) async -> Result<Data, AIImageEditFailure>

    public init(
        execute: @escaping @Sendable (AIImageEditExecutionRequest, String, AIImageModel) async -> Result<Data, AIImageEditFailure>
    ) {
        self.execute = execute
    }
}

public struct AIImageEditUseCase: Sendable {
    public let execute: @Sendable (AIImageEditExecutionRequest) async -> Result<Data, AIImageEditFailure>

    public init(
        execute: @escaping @Sendable (AIImageEditExecutionRequest) async -> Result<Data, AIImageEditFailure>
    ) {
        self.execute = execute
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public static func live(remoteClient: AIImageRemoteEditClient) -> AIImageEditUseCase {
        AIImageEditUseCase { request in
            let primaryPrompt = enforcedImageEditingPrompt(from: request.command.descriptor.prompt.rawValue)
            let retryPrompt = strictRetryImageEditingPrompt(from: request.command.descriptor.prompt.rawValue)
            var lastError: AIImageEditFailure?

            let candidateModels = retryModels(startingWith: request.command.descriptor.model)
            for round in 0..<3 {
                if round > 0 {
                    let delayNanoseconds = UInt64((0.8 + Double(round) * 0.9) * 1_000_000_000)
                    do {
                        try await Task.sleep(nanoseconds: delayNanoseconds)
                    } catch is CancellationError {
                        return .failure(.transport("AI image editing generation was canceled."))
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
            return .failure(.missingImageData("AI image editing did not return decodable image bytes."))
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

    private static func retryModels(startingWith initialModel: AIImageModel) -> [AIImageModel] {
        guard initialModel.provider == .gemini else {
            return [initialModel]
        }
        return [initialModel] + AIImageModel.allCases.filter {
            $0 != initialModel && $0.provider == initialModel.provider
        }
    }

    private static func shouldRetryWithAnotherModel(after error: AIImageEditFailure) -> Bool {
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
public struct AIImagePreviewPreparationService: Sendable {
    public let editUseCase: AIImageEditUseCase

    public init(editUseCase: AIImageEditUseCase) {
        self.editUseCase = editUseCase
    }

    public func preparePreview(
        _ request: AIImagePreviewPreparationRequest
    ) async -> Result<AIImagePreviewState, AIImagePreviewPreparationFailure> {
        let blankSurface = DocumentCompositeSurface(
            unsafeUncheckedWidth: request.sourceSurface.width,
            height: request.sourceSurface.height,
            pixelData: Data(repeating: 0, count: request.sourceSurface.width * request.sourceSurface.height * 4)
        )
        let beforeSurface = request.command.descriptor.outputMode == .replaceCurrentLayer
            ? request.sourceSurface
            : blankSurface
        let beforePreviewImageData = DocumentRasterImageService.pngData(from: beforeSurface)

        let finalSurface: DocumentCompositeSurface?
        switch request.command.descriptor.editScope {
        case .wholeLayer:
            guard let inputPNGData = DocumentRasterImageService.pngData(from: request.sourceSurface) else {
                finalSurface = nil
                break
            }

            switch await executeEdit(
                request.command,
                inputPNGData: inputPNGData,
                cropScoped: false
            ) {
            case let .success(imageData):
                finalSurface = decodedSurface(
                    from: imageData,
                    fallbackSize: (request.sourceSurface.width, request.sourceSurface.height)
                )
            case let .failure(failure):
                return .failure(.editFailed(failure))
            }

        case .selectedArea:
            guard
                let selectionRegion = request.selectionRegion,
                let crop = DocumentRasterImageService.inpaintCrop(
                    source: request.sourceSurface.pixelData,
                    canvasWidth: request.sourceSurface.width,
                    canvasHeight: request.sourceSurface.height,
                    selectionBounds: selectionRegion.selectionBounds,
                    expandedMask: selectionRegion.expandedMask
                ),
                let cropPNGData = DocumentRasterImageService.pngData(
                    from: DocumentCompositeSurface(
                        unsafeUncheckedWidth: crop.width,
                        height: crop.height,
                        pixelData: crop.pixelData
                    )
                )
            else {
                finalSurface = nil
                break
            }

            switch await executeEdit(
                request.command,
                inputPNGData: cropPNGData,
                cropScoped: true
            ) {
            case let .success(imageData):
                guard let editedCropSurface = decodedSurface(
                    from: imageData,
                    fallbackSize: (crop.width, crop.height)
                ) else {
                    finalSurface = nil
                    break
                }

                let baseLayerSurface = request.command.descriptor.outputMode == .replaceCurrentLayer
                    ? request.sourceSurface
                    : blankSurface
                guard let applied = DocumentRasterImageService.applyingInpaintCrop(
                    editedCropSurface.pixelData,
                    to: baseLayerSurface.pixelData,
                    canvasWidth: request.sourceSurface.width,
                    canvasHeight: request.sourceSurface.height,
                    crop: crop
                ) else {
                    finalSurface = nil
                    break
                }
                finalSurface = DocumentCompositeSurface(
                    unsafeUncheckedWidth: request.sourceSurface.width,
                    height: request.sourceSurface.height,
                    pixelData: applied
                )
            case let .failure(failure):
                return .failure(.editFailed(failure))
            }
        }

        guard let finalSurface else {
            return .failure(.unsupportedImage)
        }

        return .success(
            AIImagePreviewState(
                descriptor: request.command.descriptor,
                outputLayerIndex: request.outputLayerIndex,
                outputSurface: finalSurface,
                beforePreviewImageData: beforePreviewImageData,
                afterPreviewImageData: DocumentRasterImageService.pngData(from: finalSurface)
            )
        )
    }

    private func decodedSurface(
        from encodedData: Data,
        fallbackSize: (width: Int, height: Int)
    ) -> DocumentCompositeSurface? {
        guard let decoded = DocumentRasterImageService.decodedImage(fromEncodedData: encodedData) else {
            return nil
        }
        if decoded.width == fallbackSize.width, decoded.height == fallbackSize.height {
            return DocumentCompositeSurface(
                validatingWidth: decoded.width,
                height: decoded.height,
                pixelData: decoded.pixelData
            )
        }
        guard let resampledPixelData = DocumentRasterImageService.rawLayerPixelData(
            fromPNGData: encodedData,
            width: fallbackSize.width,
            height: fallbackSize.height
        ) else {
            return nil
        }
        return DocumentCompositeSurface(
            unsafeUncheckedWidth: fallbackSize.width,
            height: fallbackSize.height,
            pixelData: resampledPixelData
        )
    }

    private func executeEdit(
        _ command: SubmitAIImageEditCommand,
        inputPNGData: Data,
        cropScoped: Bool
    ) async -> Result<Data, AIImageEditFailure> {
        var adjustedCommand = command
        if cropScoped {
            let prompt = "Only edit the selected region. Keep everything outside the selected region unchanged.\n\n\(adjustedCommand.descriptor.prompt.rawValue)"
            guard let adjustedPrompt = NonEmptyPrompt(prompt) else {
                return .failure(.transport("Selected-area prompt normalization failed."))
            }
            adjustedCommand.descriptor.prompt = adjustedPrompt
        }

        return await editUseCase.execute(
            AIImageEditExecutionRequest(
                inputPNGData: inputPNGData,
                command: adjustedCommand
            )
        )
    }
}
