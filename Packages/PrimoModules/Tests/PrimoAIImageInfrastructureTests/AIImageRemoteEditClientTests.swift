import Foundation
import PrimoCoreTypes
import PrimoDocumentApplication
import PrimoDocumentContracts
import PrimoAIImageApplication
import PrimoAIImageDomain
import PrimoAIImageInfrastructure
import Testing

struct AIImageRemoteEditClientTests {
    @Test
    func openAIDirectEditModelUsesOpenAIImageEditMultipartRequest() async throws {
        final class Recorder: @unchecked Sendable {
            var request: URLRequest?
            var body: Data?
        }
        let recorder = Recorder()
        let outputData = try #require(DocumentRasterImageService.pngData(from: solidSurface(width: 1, height: 1)))
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
        let client = AIImageRemoteEditClient.infrastructureLive(httpClient: httpClient)
        let command = SubmitAIImageEditCommand(
            descriptor: AIImageEditDescriptor(
                prompt: NonEmptyPrompt("Improve lettering")!,
                accessMode: .userAPIKey,
                model: AIImageModel.defaultOpenAIDirectEditModel,
                inputLayerIndex: 0,
                editScope: .wholeLayer,
                outputMode: .replaceCurrentLayer
            ),
            executionConfig: .userAPIKey(apiKey: AIImageAPIKey("openai-key")!)
        )

        let result = await client.execute(
            AIImageEditExecutionRequest(inputPNGData: Data([0x89, 0x50, 0x4E, 0x47]), command: command),
            "Edit the supplied image",
            AIImageModel.defaultOpenAIDirectEditModel
        )

        let data = try result.get()
        #expect(data == outputData)
        let request = try #require(recorder.request)
        #expect(request.url?.absoluteString == "https://api.openai.com/v1/images/edits")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer openai-key")
        #expect(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data; boundary=") == true)
        let body = String(decoding: try #require(recorder.body), as: UTF8.self)
        #expect(body.contains("name=\"model\""))
        #expect(body.contains(AIImageModel.defaultOpenAIDirectEditModel.rawValue))
        #expect(AIImageModel.openAIDirectEditModels.contains(command.descriptor.model))
        #expect(body.contains("name=\"prompt\""))
        #expect(body.contains("Edit the supplied image"))
        #expect(body.contains("name=\"output_format\""))
        #expect(body.contains("png"))
        #expect(body.contains("name=\"image[]\"; filename=\"input.png\""))
        #expect(body.contains("Content-Type: image/png"))
    }

    @Test
    func openAIDirectEditModelMapsOpenAIErrorEnvelope() async throws {
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
        let client = AIImageRemoteEditClient.infrastructureLive(httpClient: httpClient)
        let command = SubmitAIImageEditCommand(
            descriptor: AIImageEditDescriptor(
                prompt: NonEmptyPrompt("Improve lettering")!,
                accessMode: .userAPIKey,
                model: AIImageModel.defaultOpenAIDirectEditModel,
                inputLayerIndex: 0,
                editScope: .wholeLayer,
                outputMode: .replaceCurrentLayer
            ),
            executionConfig: .userAPIKey(apiKey: AIImageAPIKey("openai-key")!)
        )

        let result = await client.execute(
            AIImageEditExecutionRequest(inputPNGData: Data([0x89, 0x50, 0x4E, 0x47]), command: command),
            "Edit the supplied image",
            AIImageModel.defaultOpenAIDirectEditModel
        )

        #expect(result == .failure(.apiError("invalid api key")))
    }

    @Test
    func unsupportedOpenAIModelDoesNotUseDirectOpenAIEditPath() async throws {
        let httpClient = HTTPClient { request in
            Issue.record("Unsupported direct OpenAI model should fail before sending \(request)")
            throw AIImageEditFailure.invalidEndpoint
        }
        let client = AIImageRemoteEditClient.infrastructureLive(httpClient: httpClient)
        let command = SubmitAIImageEditCommand(
            descriptor: AIImageEditDescriptor(
                prompt: NonEmptyPrompt("Improve lettering")!,
                accessMode: .userAPIKey,
                model: .gptImage2,
                inputLayerIndex: 0,
                editScope: .wholeLayer,
                outputMode: .replaceCurrentLayer
            ),
            executionConfig: .userAPIKey(apiKey: AIImageAPIKey("openai-key")!)
        )

        let result = await client.execute(
            AIImageEditExecutionRequest(inputPNGData: Data([0x89, 0x50, 0x4E, 0x47]), command: command),
            "Edit the supplied image",
            .gptImage2
        )

        #expect(result == .failure(.invalidEndpoint))
        #expect(!AIImageModel.openAIDirectEditModels.contains(.gptImage2))
    }

    @Test
    func appManagedProxyRequestUsesAllowlistedHostAndTimeout() async throws {
        final class Recorder: @unchecked Sendable {
            var request: URLRequest?
            var body: Data?
        }
        let recorder = Recorder()
        let outputData = try #require(DocumentRasterImageService.pngData(from: solidSurface(width: 1, height: 1)))
        let httpClient = HTTPClient { request in
            recorder.request = request
            recorder.body = request.httpBody
            let responseData = """
            {
              "image_base64": "\(outputData.base64EncodedString())"
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
        let client = AIImageRemoteEditClient.infrastructureLive(httpClient: httpClient)
        let inputPNGData = Data([0x89, 0x50, 0x4E, 0x47])

        let result = await client.execute(
            AIImageEditExecutionRequest(inputPNGData: inputPNGData, command: appManagedCommand()),
            "Edit through proxy",
            .flashImage31Preview
        )

        let data = try result.get()
        #expect(data == outputData)
        let request = try #require(recorder.request)
        #expect(request.url?.absoluteString == "https://proxy.bestcatscience.com/edit")
        #expect(request.timeoutInterval == 60)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer signed-entitlement")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = String(decoding: try #require(recorder.body), as: UTF8.self)
        #expect(body.contains("\"image_base64\":\"\(inputPNGData.base64EncodedString())\""))
    }

    @Test
    func rejectsOversizedInputBeforeUploading() async throws {
        final class Recorder: @unchecked Sendable {
            var callCount = 0
        }
        let recorder = Recorder()
        let httpClient = HTTPClient { request in
            recorder.callCount += 1
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response)
        }
        let client = AIImageRemoteEditClient.infrastructureLive(httpClient: httpClient)
        let oversizedPNGData = Data(count: 16 * 1024 * 1024 + 1)

        let result = await client.execute(
            AIImageEditExecutionRequest(inputPNGData: oversizedPNGData, command: appManagedCommand()),
            "Edit through proxy",
            .flashImage31Preview
        )

        #expect(recorder.callCount == 0)
        #expect(result == .failure(.missingImageData("AI image editing input PNG is too large to upload safely.")))
    }

    @Test
    func providerErrorDisplayRedactsSecrets() async throws {
        let httpClient = HTTPClient { request in
            let responseData = """
            {
              "error": {
                "message": "Authorization: Bearer supersecrettoken123456 and api_key=sk-secretvalue123456"
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
        let client = AIImageRemoteEditClient.infrastructureLive(httpClient: httpClient)

        let result = await client.execute(
            AIImageEditExecutionRequest(inputPNGData: Data([0x89, 0x50, 0x4E, 0x47]), command: appManagedCommand()),
            "Edit through proxy",
            .flashImage31Preview
        )

        #expect(result == .failure(.apiError("Authorization: Bearer [redacted] and api_key=[redacted]")))
    }

    @Test
    func recursiveJSONImageExtractionStopsAtMaximumDepth() async throws {
        let imageData = Data([0x11, 0x12, 0x13]).base64EncodedString()
        let httpClient = HTTPClient { request in
            let responseData = """
            {
              "a": {
                "a": {
                  "a": {
                    "a": {
                      "a": {
                        "a": {
                          "a": {
                            "a": {
                              "a": {
                                "inline_data": {
                                  "mime_type": "image/png",
                                  "data": "\(imageData)"
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
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
        let client = AIImageRemoteEditClient.infrastructureLive(httpClient: httpClient)

        let result = await client.execute(
            AIImageEditExecutionRequest(inputPNGData: Data([0x89, 0x50, 0x4E, 0x47]), command: appManagedCommand()),
            "Edit through proxy",
            .flashImage31Preview
        )

        #expect(result == .failure(.missingImageData("AI image editing did not return decodable image bytes.")))
    }

    @Test
    func remoteImageResponseRejectsBase64ThatIsNotAnImage() async throws {
        let outputData = Data([0x01, 0x02, 0x03])
        let httpClient = HTTPClient { request in
            let responseData = """
            {
              "parts": [
                {
                  "inlineData": {
                    "mimeType": "image/png",
                    "data": "\(outputData.base64EncodedString())"
                  }
                }
              ]
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
        let client = AIImageRemoteEditClient.infrastructureLive(httpClient: httpClient)

        let result = await client.execute(
            AIImageEditExecutionRequest(inputPNGData: Data([0x89, 0x50, 0x4E, 0x47]), command: appManagedCommand()),
            "Edit through proxy",
            .flashImage31Preview
        )

        #expect(result == .failure(.missingImageData("AI image editing did not return decodable image bytes.")))
    }

    @Test
    func geminiImageConfigUsesSourceAspectRatioForPortraitCanvas() async throws {
        final class Recorder: @unchecked Sendable {
            var body: Data?
        }
        let recorder = Recorder()
        let outputData = try #require(DocumentRasterImageService.pngData(from: solidSurface(width: 1, height: 1)))
        let httpClient = HTTPClient { request in
            recorder.body = request.httpBody
            let responseData = """
            {
              "candidates": [
                {
                  "content": {
                    "parts": [
                      {
                        "inlineData": {
                          "mimeType": "image/png",
                          "data": "\(outputData.base64EncodedString())"
                        }
                      }
                    ]
                  }
                }
              ]
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
        let client = AIImageRemoteEditClient.infrastructureLive(httpClient: httpClient)
        let command = geminiCommand(editScope: .wholeLayer)
        let inputPNGData = try #require(DocumentRasterImageService.pngData(
            from: solidSurface(width: 1152, height: 1536)
        ))

        let result = await client.execute(
            AIImageEditExecutionRequest(inputPNGData: inputPNGData, command: command),
            "Edit the supplied image",
            .flashImage31Preview
        )

        let data = try result.get()
        #expect(data == outputData)
        let body = String(decoding: try #require(recorder.body), as: UTF8.self)
        #expect(body.contains("\"aspectRatio\":\"3:\\/4\"") || body.contains("\"aspectRatio\":\"3:4\""))
        #expect(!body.contains("\"aspectRatio\":\"1:1\""))
        #expect(!body.contains("\"imageSize\""))
        #expect(!body.contains("2K"))
    }

    @Test
    func geminiImageConfigUsesSourceAspectRatioForWideSelectedCrop() async throws {
        final class Recorder: @unchecked Sendable {
            var body: Data?
        }
        let recorder = Recorder()
        let outputData = try #require(DocumentRasterImageService.pngData(from: solidSurface(width: 1, height: 1)))
        let httpClient = HTTPClient { request in
            recorder.body = request.httpBody
            let responseData = """
            {
              "parts": [
                {
                  "inlineData": {
                    "mimeType": "image/png",
                    "data": "\(outputData.base64EncodedString())"
                  }
                }
              ]
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
        let client = AIImageRemoteEditClient.infrastructureLive(httpClient: httpClient)
        let inputPNGData = try #require(DocumentRasterImageService.pngData(
            from: solidSurface(width: 320, height: 180)
        ))

        let result = await client.execute(
            AIImageEditExecutionRequest(inputPNGData: inputPNGData, command: geminiCommand(editScope: .selectedArea)),
            "Edit the selected crop",
            .flashImage31Preview
        )

        let data = try result.get()
        #expect(data == outputData)
        let body = String(decoding: try #require(recorder.body), as: UTF8.self)
        #expect(body.contains("\"aspectRatio\":\"16:\\/9\"") || body.contains("\"aspectRatio\":\"16:9\""))
        #expect(!body.contains("\"aspectRatio\":\"1:1\""))
        #expect(!body.contains("\"imageSize\""))
    }

    private func geminiCommand(editScope: AIImageEditScope) -> SubmitAIImageEditCommand {
        SubmitAIImageEditCommand(
            descriptor: AIImageEditDescriptor(
                prompt: NonEmptyPrompt("Improve image")!,
                accessMode: .userAPIKey,
                model: .flashImage31Preview,
                inputLayerIndex: 0,
                editScope: editScope,
                outputMode: .replaceCurrentLayer
            ),
            executionConfig: .userAPIKey(apiKey: AIImageAPIKey("gemini-key")!)
        )
    }

    private func appManagedCommand() -> SubmitAIImageEditCommand {
        SubmitAIImageEditCommand(
            descriptor: AIImageEditDescriptor(
                prompt: NonEmptyPrompt("Improve image")!,
                accessMode: .appManaged,
                model: .flashImage31Preview,
                inputLayerIndex: 0,
                editScope: .wholeLayer,
                outputMode: .replaceCurrentLayer
            ),
            executionConfig: .appManaged(
                entitlement: AIImageEntitlementToken("signed-entitlement")!,
                endpoint: ProxyEndpoint("https://proxy.bestcatscience.com/edit")!
            )
        )
    }

    private func solidSurface(width: Int, height: Int) -> DocumentCompositeSurface {
        DocumentCompositeSurface(
            unsafeUncheckedWidth: width,
            height: height,
            pixelData: Data(repeating: 0x7F, count: width * height * 4)
        )
    }
}
