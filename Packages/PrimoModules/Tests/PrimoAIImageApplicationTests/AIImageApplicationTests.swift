import Foundation
import PrimoDocumentContracts
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
        let snapshot = AIImageCommerceSnapshot(proxyEndpoint: "https://proxy.example.com/edit")

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
    func commandBuilderBuildsOpenAIUserKeyCommand() throws {
        let draft = AIImageDraft(
            prompt: "  refine text  ",
            accessMode: .userAPIKey,
            model: .gptImage2,
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
        #expect(command.descriptor.model == .gptImage2)
        #expect(command.descriptor.model.provider == .openAI)
        #expect(command.executionConfig == .userAPIKey(apiKey: AIImageAPIKey("openai-key")!))
    }

    @Test
    func commandBuilderRequiresOpenAIKeyForGPTImage2() {
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
            apiKey: "gemini-key",
            openAIAPIKey: "",
            commerce: AIImageCommerceSnapshot()
        )

        #expect(result == .failure(.apiKeyRequired))
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
            width: 2,
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
            width: 4,
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
}
