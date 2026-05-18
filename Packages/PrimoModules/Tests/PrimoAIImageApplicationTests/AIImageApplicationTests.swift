import Foundation
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoBrushRuntimeContracts
import PrimoDocumentDomain
import PrimoDocumentGPUContracts
import PrimoDocumentMutationContracts
import PrimoDocumentPersistenceContracts
import PrimoDocumentPresentationContracts
import PrimoDocumentRenderingContracts
import PrimoAIImageApplication
import PrimoAIImageDomain
import Testing

struct AIImageApplicationTests {
    @Test
    func commandBuilderBuildsUserKeyCommand() throws {
        let draft = AIImageDraft(
            prompt: "  refine shadows  ",
            accessMode: .userAPIKey,
            model: .flashImage31Preview,
            inputLayerIndex: 4,
            editScope: .selectedArea,
            outputMode: .newLayer,
            maskSettings: .init(expansion: 6, isInverted: true)
        )
        let snapshot = AIImageCommerceSnapshot(proxyEndpoint: "https://proxy.bestcatscience.com/edit")

        let result = AIImageCommandBuilder().build(
            draft: draft,
            apiKey: "  secret-key  ",
            openAIAPIKey: "",
            commerce: snapshot
        )

        let command = try result.get()
        #expect(command.descriptor.prompt.rawValue == "refine shadows")
        #expect(command.descriptor.inputLayerIndex == 4)
        #expect(command.descriptor.maskSettings.expansion == 6)
        #expect(command.descriptor.maskSettings.isInverted)
        #expect(command.executionConfig == .userAPIKey(apiKey: AIImageAPIKey("secret-key")!))
    }

    @Test
    func commandBuilderPromotesSettingsDraftToExecutionConfig() throws {
        let draft = AIImageDraft(
            prompt: "refine shadows",
            accessMode: .userAPIKey,
            model: .flashImage31Preview,
            inputLayerIndex: 4,
            editScope: .selectedArea,
            outputMode: .newLayer
        )
        let settings = AIImageSettingsDraft(
            accessMode: .userAPIKey,
            apiKey: "  secret-key  "
        )

        let result = AIImageCommandBuilder().build(
            draft: draft,
            settings: settings,
            commerce: AIImageCommerceSnapshot()
        )

        let command = try result.get()
        #expect(command.executionConfig == .userAPIKey(apiKey: AIImageAPIKey("secret-key")!))
    }

    @Test
    func commandBuilderBuildsOpenAIUserKeyCommand() throws {
        let draft = AIImageDraft(
            prompt: "  refine text  ",
            accessMode: .userAPIKey,
            model: AIImageModel.defaultOpenAIDirectEditModel,
            inputLayerIndex: 1,
            editScope: .wholeLayer,
            outputMode: .replaceCurrentLayer
        )

        let result = AIImageCommandBuilder().build(
            draft: draft,
            apiKey: "",
            openAIAPIKey: "  openai-key  ",
            commerce: AIImageCommerceSnapshot()
        )

        let command = try result.get()
        #expect(command.descriptor.model == AIImageModel.defaultOpenAIDirectEditModel)
        #expect(command.descriptor.model.provider == .openAI)
        #expect(command.executionConfig == .userAPIKey(apiKey: AIImageAPIKey("openai-key")!))
    }

    @Test
    func commandBuilderRequiresOpenAIKeyForDirectOpenAIModel() {
        let draft = AIImageDraft(
            prompt: "refine text",
            accessMode: .userAPIKey,
            model: AIImageModel.defaultOpenAIDirectEditModel,
            inputLayerIndex: 1,
            editScope: .wholeLayer,
            outputMode: .replaceCurrentLayer
        )

        let result = AIImageCommandBuilder().build(
            draft: draft,
            apiKey: "gemini-key",
            openAIAPIKey: "",
            commerce: AIImageCommerceSnapshot()
        )

        #expect(result == .failure(.apiKeyRequired))
    }

    @Test
    func commandBuilderRejectsOpenAIModelsOutsideDirectEditAllowlist() throws {
        let draft = AIImageDraft(
            prompt: "refine text",
            accessMode: .userAPIKey,
            model: .gptImage2,
            inputLayerIndex: 1,
            editScope: .wholeLayer,
            outputMode: .replaceCurrentLayer
        )

        let result = AIImageCommandBuilder().build(
            draft: draft,
            apiKey: "",
            openAIAPIKey: "openai-key",
            commerce: AIImageCommerceSnapshot()
        )

        #expect(result == .failure(.unsupportedDirectOpenAIModel))
    }

    @Test
    func commandBuilderUsesEntitlementJWSRatherThanClientActiveFlagForAppManagedCommand() throws {
        let draft = AIImageDraft(
            prompt: "refine shadows",
            accessMode: .appManaged,
            model: .flashImage31Preview,
            inputLayerIndex: 1,
            editScope: .wholeLayer,
            outputMode: .replaceCurrentLayer
        )
        let snapshot = AIImageCommerceSnapshot(
            isSubscriptionActive: false,
            latestEntitlementJWS: "signed-entitlement",
            proxyEndpoint: "https://proxy.bestcatscience.com/edit"
        )

        let result = AIImageCommandBuilder().build(
            draft: draft,
            apiKey: "",
            openAIAPIKey: "",
            commerce: snapshot
        )

        let command = try result.get()
        #expect(command.executionConfig == .appManaged(
            entitlement: AIImageEntitlementToken("signed-entitlement")!,
            endpoint: ProxyEndpoint("https://proxy.bestcatscience.com/edit")!
        ))
    }

    @Test
    func editUseCaseRetriesAcrossPromptsAndModels() async throws {
        let command = SubmitAIImageEditCommand(
            descriptor: AIImageEditDescriptor(
                prompt: NonEmptyPrompt("Retouch it")!,
                accessMode: .userAPIKey,
                model: .flashImage31Preview,
                inputLayerIndex: 0,
                editScope: .wholeLayer,
                outputMode: .replaceCurrentLayer
            ),
            executionConfig: .userAPIKey(apiKey: AIImageAPIKey("secret-key")!)
        )
        let request = AIImageEditExecutionRequest(
            inputPNGData: Data([0x00]),
            command: command
        )

        final class Recorder: @unchecked Sendable {
            var calls: [(String, AIImageModel)] = []
        }
        let recorder = Recorder()
        let remoteClient = AIImageRemoteEditClient { _, prompt, model in
            recorder.calls.append((prompt, model))
            if model == .proImagePreview {
                return .success(Data([0x01]))
            }
            return .failure(.apiError("service unavailable"))
        }

        let result = await AIImageEditUseCase.live(remoteClient: remoteClient).execute(request)
        let data = try result.get()
        #expect(data == Data([0x01]))
        #expect(recorder.calls.count >= 3)
        #expect(recorder.calls.contains { $0.1 == .proImagePreview })
    }

    @Test
    func previewPreparationServiceBuildsWholeLayerPreview() async throws {
        let command = SubmitAIImageEditCommand(
            descriptor: AIImageEditDescriptor(
                prompt: NonEmptyPrompt("Retouch it")!,
                accessMode: .userAPIKey,
                model: .flashImage31Preview,
                inputLayerIndex: 0,
                editScope: .wholeLayer,
                outputMode: .replaceCurrentLayer
            ),
            executionConfig: .userAPIKey(apiKey: AIImageAPIKey("secret-key")!)
        )
        let surface = DocumentCompositeSurface(
            unsafeUncheckedWidth: 2,
            height: 2,
            pixelData: Data([
            255, 0, 0, 255,
            0, 255, 0, 255,
            0, 0, 255, 255,
            255, 255, 255, 255,
            ])
        )
        let useCase = AIImageEditUseCase { request in
            .success(request.inputPNGData)
        }

        let result = await AIImagePreviewPreparationService(editUseCase: useCase).preparePreview(
            AIImagePreviewPreparationRequest(
                command: command,
                selectionRegion: nil,
                outputLayerIndex: 0,
                sourceSurface: surface
            )
        )

        let preview = try result.get()
        #expect(preview.outputLayerIndex == 0)
        #expect(preview.outputSurface.width == 2)
        #expect(preview.outputSurface.height == 2)
        #expect(preview.pixelData.count == surface.pixelData.count)
        #expect(preview.beforePreviewImageData != nil)
        #expect(preview.afterPreviewImageData != nil)
    }

    @Test
    func previewPreparationResamplesPortraitWholeLayerOutputToSourceSize() async throws {
        let command = SubmitAIImageEditCommand(
            descriptor: AIImageEditDescriptor(
                prompt: NonEmptyPrompt("Retouch portrait canvas")!,
                accessMode: .userAPIKey,
                model: .flashImage31Preview,
                inputLayerIndex: 0,
                editScope: .wholeLayer,
                outputMode: .replaceCurrentLayer
            ),
            executionConfig: .userAPIKey(apiKey: AIImageAPIKey("secret-key")!)
        )
        let sourceSurface = solidSurface(width: 1152, height: 1536)
        let remoteOutput = try #require(DocumentRasterImageService.pngData(
            from: solidSurface(width: 3, height: 4)
        ))
        let useCase = AIImageEditUseCase { _ in
            .success(remoteOutput)
        }

        let result = await AIImagePreviewPreparationService(editUseCase: useCase).preparePreview(
            AIImagePreviewPreparationRequest(
                command: command,
                selectionRegion: nil,
                outputLayerIndex: 0,
                sourceSurface: sourceSurface
            )
        )

        let preview = try result.get()
        #expect(preview.outputSurface.width == 1152)
        #expect(preview.outputSurface.height == 1536)
        #expect(preview.pixelData.count == sourceSurface.pixelData.count)
        #expect(preview.afterPreviewImageData != nil)
    }

    @Test
    func previewPreparationServiceBuildsSelectedAreaPreviewFromSurface() async throws {
        let command = SubmitAIImageEditCommand(
            descriptor: AIImageEditDescriptor(
                prompt: NonEmptyPrompt("Retouch selection")!,
                accessMode: .userAPIKey,
                model: .flashImage31Preview,
                inputLayerIndex: 0,
                editScope: .selectedArea,
                outputMode: .replaceCurrentLayer
            ),
            executionConfig: .userAPIKey(apiKey: AIImageAPIKey("secret-key")!)
        )
        let surface = DocumentCompositeSurface(
            unsafeUncheckedWidth: 4,
            height: 4,
            pixelData: Data(repeating: 0xFF, count: 4 * 4 * 4)
        )
        let useCase = AIImageEditUseCase { request in
            .success(request.inputPNGData)
        }

        let result = await AIImagePreviewPreparationService(editUseCase: useCase).preparePreview(
            AIImagePreviewPreparationRequest(
                command: command,
                selectionRegion: AIImageSelectionRegion(
                    selectionBounds: CGRect(x: 1, y: 1, width: 2, height: 2),
                    expandedMask: [
                        0, 0, 0, 0,
                        0, 255, 255, 0,
                        0, 255, 255, 0,
                        0, 0, 0, 0,
                    ]
                ),
                outputLayerIndex: 0,
                sourceSurface: surface
            )
        )

        let preview = try result.get()
        #expect(preview.outputSurface.width == 4)
        #expect(preview.outputSurface.height == 4)
        #expect(preview.beforePreviewImageData != nil)
        #expect(preview.afterPreviewImageData != nil)
    }

    @Test
    func previewPreparationResamplesWideSelectedAreaOutputToCropSize() async throws {
        let command = SubmitAIImageEditCommand(
            descriptor: AIImageEditDescriptor(
                prompt: NonEmptyPrompt("Retouch selection")!,
                accessMode: .userAPIKey,
                model: .flashImage31Preview,
                inputLayerIndex: 0,
                editScope: .selectedArea,
                outputMode: .replaceCurrentLayer
            ),
            executionConfig: .userAPIKey(apiKey: AIImageAPIKey("secret-key")!)
        )
        let sourceSurface = solidSurface(width: 320, height: 180)
        let remoteOutput = try #require(DocumentRasterImageService.pngData(
            from: solidSurface(width: 16, height: 9)
        ))
        let useCase = AIImageEditUseCase { _ in
            .success(remoteOutput)
        }

        let result = await AIImagePreviewPreparationService(editUseCase: useCase).preparePreview(
            AIImagePreviewPreparationRequest(
                command: command,
                selectionRegion: AIImageSelectionRegion(
                    selectionBounds: CGRect(x: 0, y: 0, width: 320, height: 180),
                    expandedMask: [UInt8](repeating: 255, count: 320 * 180)
                ),
                outputLayerIndex: 0,
                sourceSurface: sourceSurface
            )
        )

        let preview = try result.get()
        #expect(preview.outputSurface.width == 320)
        #expect(preview.outputSurface.height == 180)
        #expect(preview.pixelData.count == sourceSurface.pixelData.count)
        #expect(preview.beforePreviewImageData != nil)
        #expect(preview.afterPreviewImageData != nil)
    }

    private func solidSurface(width: Int, height: Int) -> DocumentCompositeSurface {
        DocumentCompositeSurface(
            unsafeUncheckedWidth: width,
            height: height,
            pixelData: Data(repeating: 0x7F, count: width * height * 4)
        )
    }
}
