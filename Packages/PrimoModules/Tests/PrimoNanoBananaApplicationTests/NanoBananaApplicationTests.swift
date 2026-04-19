import Foundation
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
}
