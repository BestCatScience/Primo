import Foundation
import PrimoDocumentContracts
import PrimoNanoBananaApplication
import PrimoNanoBananaDomain
import Testing

struct NanoBananaApplicationTests {
    @Test
    func commandBuilderBuildsUserKeyCommand() throws {
        let draft = NanoBananaDraft(
            prompt: "  refine shadows  ",
            accessMode: .userAPIKey,
            model: .flashImage25,
            inputLayerIndex: 4,
            editScope: .selectedArea,
            outputMode: .newLayer,
            maskSettings: .init(expansion: 6, isInverted: true)
        )
        let snapshot = NanoBananaCommerceSnapshot(proxyEndpoint: "https://proxy.example.com/edit")

        let result = NanoBananaCommandBuilder().build(
            draft: draft,
            apiKey: "  secret-key  ",
            commerce: snapshot
        )

        let command = try #require(try result.get())
        #expect(command.descriptor.prompt.rawValue == "refine shadows")
        #expect(command.descriptor.inputLayerIndex == 4)
        #expect(command.descriptor.maskSettings.expansion == 6)
        #expect(command.descriptor.maskSettings.isInverted)
        #expect(command.executionConfig == .userAPIKey(apiKey: NanoBananaAPIKey("secret-key")!))
    }

    @Test
    func editUseCaseRetriesAcrossPromptsAndModels() async throws {
        let command = SubmitNanoBananaEditCommand(
            descriptor: NanoBananaEditDescriptor(
                prompt: NonEmptyPrompt("Retouch it")!,
                accessMode: .userAPIKey,
                model: .flashImage25,
                inputLayerIndex: 0,
                editScope: .wholeLayer,
                outputMode: .replaceCurrentLayer
            ),
            executionConfig: .userAPIKey(apiKey: NanoBananaAPIKey("secret-key")!)
        )
        let request = NanoBananaEditExecutionRequest(
            inputPNGData: Data([0x00]),
            command: command
        )

        final class Recorder: @unchecked Sendable {
            var calls: [(String, NanoBananaModel)] = []
        }
        let recorder = Recorder()
        let remoteClient = NanoBananaRemoteEditClient { _, prompt, model in
            recorder.calls.append((prompt, model))
            if model == .flashImage31Preview {
                return .success(Data([0x01]))
            }
            return .failure(.apiError("service unavailable"))
        }

        let result = await NanoBananaEditUseCase.live(remoteClient: remoteClient).execute(request)
        let data = try #require(try result.get())
        #expect(data == Data([0x01]))
        #expect(recorder.calls.count >= 3)
        #expect(recorder.calls.contains { $0.1 == .flashImage31Preview })
    }

    @Test
    func previewPreparationServiceBuildsWholeLayerPreview() async throws {
        let command = SubmitNanoBananaEditCommand(
            descriptor: NanoBananaEditDescriptor(
                prompt: NonEmptyPrompt("Retouch it")!,
                accessMode: .userAPIKey,
                model: .flashImage25,
                inputLayerIndex: 0,
                editScope: .wholeLayer,
                outputMode: .replaceCurrentLayer
            ),
            executionConfig: .userAPIKey(apiKey: NanoBananaAPIKey("secret-key")!)
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
        let useCase = NanoBananaEditUseCase { request in
            .success(request.inputPNGData)
        }

        let result = await NanoBananaPreviewPreparationService(editUseCase: useCase).preparePreview(
            NanoBananaPreviewPreparationRequest(
                command: command,
                selectionRegion: nil,
                outputLayerIndex: 0,
                sourceSurface: surface
            )
        )

        let preview = try #require(try result.get())
        #expect(preview.outputLayerIndex == 0)
        #expect(preview.outputSurface.width == 2)
        #expect(preview.outputSurface.height == 2)
        #expect(preview.pixelData.count == surface.pixelData.count)
        #expect(preview.beforePreviewImageData != nil)
        #expect(preview.afterPreviewImageData != nil)
    }

    @Test
    func previewPreparationServiceBuildsSelectedAreaPreviewFromSurface() async throws {
        let command = SubmitNanoBananaEditCommand(
            descriptor: NanoBananaEditDescriptor(
                prompt: NonEmptyPrompt("Retouch selection")!,
                accessMode: .userAPIKey,
                model: .flashImage25,
                inputLayerIndex: 0,
                editScope: .selectedArea,
                outputMode: .replaceCurrentLayer
            ),
            executionConfig: .userAPIKey(apiKey: NanoBananaAPIKey("secret-key")!)
        )
        let surface = DocumentCompositeSurface(
            width: 4,
            height: 4,
            pixelData: Data(repeating: 0xFF, count: 4 * 4 * 4)
        )
        let useCase = NanoBananaEditUseCase { request in
            .success(request.inputPNGData)
        }

        let result = await NanoBananaPreviewPreparationService(editUseCase: useCase).preparePreview(
            NanoBananaPreviewPreparationRequest(
                command: command,
                selectionRegion: NanoBananaSelectionRegion(
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

        let preview = try #require(try result.get())
        #expect(preview.outputSurface.width == 4)
        #expect(preview.outputSurface.height == 4)
        #expect(preview.beforePreviewImageData != nil)
        #expect(preview.afterPreviewImageData != nil)
    }
}
