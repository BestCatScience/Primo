import Foundation
import PrimoCoreTypes
import PrimoNanoBananaApplication
import PrimoNanoBananaDomain
import PrimoNanoBananaInfrastructure
import Testing

struct NanoBananaRemoteEditClientTests {
    @Test
    func gptImage2UsesOpenAIImageEditMultipartRequest() async throws {
        final class Recorder: @unchecked Sendable {
            var request: URLRequest?
            var body: Data?
        }
        let recorder = Recorder()
        let outputData = Data([0x01, 0x02, 0x03])
        let httpClient = HTTPClient { request in
            recorder.request = request
            recorder.body = request.httpBody
            let responseData = """
            {
              "created": 0,
              "data": [
                {
                  "b64_json": "\(outputData.base64EncodedString())"
                }
              ],
              "output_format": "png"
            }
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (responseData, response)
        }
        let client = NanoBananaRemoteEditClient.live(httpClient: httpClient)
        let command = SubmitNanoBananaEditCommand(
            descriptor: NanoBananaEditDescriptor(
                prompt: NonEmptyPrompt("Improve lettering")!,
                accessMode: .userAPIKey,
                model: .gptImage2,
                inputLayerIndex: 0,
                editScope: .wholeLayer,
                outputMode: .replaceCurrentLayer
            ),
            executionConfig: .userAPIKey(apiKey: NanoBananaAPIKey("openai-key")!)
        )

        let result = await client.execute(
            NanoBananaEditExecutionRequest(inputPNGData: Data([0x89, 0x50, 0x4E, 0x47]), command: command),
            "Edit the supplied image",
            .gptImage2
        )

        let data = try result.get()
        #expect(data == outputData)
        let request = try #require(recorder.request)
        #expect(request.url?.absoluteString == "https://api.openai.com/v1/images/edits")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer openai-key")
        #expect(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data; boundary=") == true)
        let body = String(decoding: try #require(recorder.body), as: UTF8.self)
        #expect(body.contains("name=\"model\""))
        #expect(body.contains("gpt-image-2"))
        #expect(body.contains("name=\"prompt\""))
        #expect(body.contains("Edit the supplied image"))
        #expect(body.contains("name=\"output_format\""))
        #expect(body.contains("png"))
        #expect(body.contains("name=\"image[]\"; filename=\"input.png\""))
        #expect(body.contains("Content-Type: image/png"))
    }

    @Test
    func gptImage2MapsOpenAIErrorEnvelope() async throws {
        let httpClient = HTTPClient { request in
            let responseData = """
            {
              "error": {
                "message": "invalid api key"
              }
            }
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (responseData, response)
        }
        let client = NanoBananaRemoteEditClient.live(httpClient: httpClient)
        let command = SubmitNanoBananaEditCommand(
            descriptor: NanoBananaEditDescriptor(
                prompt: NonEmptyPrompt("Improve lettering")!,
                accessMode: .userAPIKey,
                model: .gptImage2,
                inputLayerIndex: 0,
                editScope: .wholeLayer,
                outputMode: .replaceCurrentLayer
            ),
            executionConfig: .userAPIKey(apiKey: NanoBananaAPIKey("openai-key")!)
        )

        let result = await client.execute(
            NanoBananaEditExecutionRequest(inputPNGData: Data([0x89, 0x50, 0x4E, 0x47]), command: command),
            "Edit the supplied image",
            .gptImage2
        )

        #expect(result == .failure(.apiError("invalid api key")))
    }
}
