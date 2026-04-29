import Foundation
import PrimoCoreTypes
import PrimoNanoBananaApplication
import PrimoNanoBananaDomain

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension NanoBananaRemoteEditClient {
    static func live(httpClient: HTTPClient) -> NanoBananaRemoteEditClient {
        NanoBananaRemoteEditClient { request, prompt, model in
            do {
                let imageData = try await performEditRequest(
                    inputPNGData: request.inputPNGData,
                    prompt: prompt,
                    config: request.command.executionConfig,
                    model: model,
                    httpClient: httpClient
                )
                guard let imageData else {
                    return .failure(.missingImageData("Nano Banana did not return decodable image bytes."))
                }
                return .success(imageData)
            } catch let failure as NanoBananaEditFailure {
                return .failure(failure)
            } catch {
                return .failure(.transport(error.localizedDescription))
            }
        }
    }

    private static func performEditRequest(
        inputPNGData: Data,
        prompt: String,
        config: NanoBananaExecutionConfig,
        model: NanoBananaModel,
        httpClient: HTTPClient
    ) async throws -> Data? {
        switch config {
        case let .userAPIKey(apiKey):
            if model.provider == .openAI {
                let request = try makeOpenAIImageEditRequest(
                    inputPNGData: inputPNGData,
                    prompt: prompt,
                    apiKey: apiKey.rawValue,
                    model: model
                )
                let (data, response) = try await httpClient.data(request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NanoBananaEditFailure.invalidResponse
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    if let apiError = decodeAPIErrorEnvelope(from: data) {
                        throw NanoBananaEditFailure.apiError(apiError.error.message)
                    }
                    throw NanoBananaEditFailure.apiError(
                        String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                    )
                }

                return try decodeImageData(from: data)
            }

            var lastError: NanoBananaEditFailure?
            for request in makeGeminiRequests(
                inputPNGData: inputPNGData,
                prompt: prompt,
                apiKey: apiKey.rawValue,
                model: model
            ) {
                do {
                    let (data, response) = try await httpClient.data(request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw NanoBananaEditFailure.invalidResponse
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        if let apiError = decodeAPIErrorEnvelope(from: data) {
                            throw NanoBananaEditFailure.apiError(apiError.error.message)
                        }
                        throw NanoBananaEditFailure.apiError(
                            String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                        )
                    }

                    if let imageData = try decodeImageData(from: data) {
                        return imageData
                    }
                } catch {
                    if let failure = error as? NanoBananaEditFailure {
                        lastError = failure
                    } else {
                        lastError = .transport(error.localizedDescription)
                    }
                }
            }
            if let lastError {
                throw lastError
            }
            return nil

        case let .appManaged(entitlement, endpoint):
            let request = try makeProxyRequest(
                inputPNGData: inputPNGData,
                prompt: prompt,
                accessToken: entitlement.rawValue,
                endpoint: endpoint.rawValue,
                model: model
            )
            let (data, response) = try await httpClient.data(request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NanoBananaEditFailure.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if let apiError = decodeAPIErrorEnvelope(from: data) {
                    throw NanoBananaEditFailure.apiError(apiError.error.message)
                }
                throw NanoBananaEditFailure.apiError(
                    String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                )
            }

            return try decodeImageData(from: data)
        }
    }

    private static func makeGeminiRequests(
        inputPNGData: Data,
        prompt: String,
        apiKey: String,
        model: NanoBananaModel
    ) -> [URLRequest] {
        guard model.provider == .gemini else { return [] }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model.rawValue):generateContent") else {
            return []
        }

        let imagePart = RequestPart(
            inlineData: InlineData(
                mimeType: "image/png",
                data: inputPNGData.base64EncodedString()
            )
        )
        let textPart = RequestPart(text: prompt)

        let requestBodies: [GenerateContentRequest] = [
            GenerateContentRequest(
                contents: [
                    RequestContent(parts: [textPart, imagePart])
                ],
                generationConfig: GenerationConfig(
                    responseModalities: ["TEXT", "IMAGE"],
                    imageConfig: imageConfig(for: model)
                )
            ),
            GenerateContentRequest(
                contents: [
                    RequestContent(parts: [imagePart, textPart])
                ],
                generationConfig: GenerationConfig(
                    responseModalities: ["TEXT", "IMAGE"],
                    imageConfig: imageConfig(for: model)
                )
            ),
            GenerateContentRequest(
                contents: [
                    RequestContent(parts: [textPart, imagePart])
                ],
                generationConfig: nil
            ),
            GenerateContentRequest(
                contents: [
                    RequestContent(parts: [imagePart, textPart])
                ],
                generationConfig: nil
            )
        ]

        return requestBodies.compactMap { requestBody in
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            do {
                request.httpBody = try JSONEncoder().encode(requestBody)
            } catch {
                request.httpBody = nil
            }
            return request.httpBody == nil ? nil : request
        }
    }

    private static func makeOpenAIImageEditRequest(
        inputPNGData: Data,
        prompt: String,
        apiKey: String,
        model: NanoBananaModel
    ) throws -> URLRequest {
        guard model.provider == .openAI else {
            throw NanoBananaEditFailure.invalidEndpoint
        }
        guard let url = URL(string: "https://api.openai.com/v1/images/edits") else {
            throw NanoBananaEditFailure.invalidEndpoint
        }

        let boundary = "PrimoBoundary-\(UUID().uuidString)"
        var body = Data()
        appendMultipartField(name: "model", value: model.rawValue, boundary: boundary, to: &body)
        appendMultipartField(name: "prompt", value: prompt, boundary: boundary, to: &body)
        appendMultipartField(name: "output_format", value: "png", boundary: boundary, to: &body)
        appendMultipartFile(
            name: "image[]",
            filename: "input.png",
            mimeType: "image/png",
            data: inputPNGData,
            boundary: boundary,
            to: &body
        )
        appendString("--\(boundary)--\r\n", to: &body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        return request
    }

    private static func appendMultipartField(
        name: String,
        value: String,
        boundary: String,
        to body: inout Data
    ) {
        appendString("--\(boundary)\r\n", to: &body)
        appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n", to: &body)
        appendString("\(value)\r\n", to: &body)
    }

    private static func appendMultipartFile(
        name: String,
        filename: String,
        mimeType: String,
        data: Data,
        boundary: String,
        to body: inout Data
    ) {
        appendString("--\(boundary)\r\n", to: &body)
        appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n", to: &body)
        appendString("Content-Type: \(mimeType)\r\n\r\n", to: &body)
        body.append(data)
        appendString("\r\n", to: &body)
    }

    private static func appendString(_ value: String, to body: inout Data) {
        body.append(Data(value.utf8))
    }

    private static func makeProxyRequest(
        inputPNGData: Data,
        prompt: String,
        accessToken: String,
        endpoint: String,
        model: NanoBananaModel
    ) throws -> URLRequest {
        guard let url = URL(string: endpoint), !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NanoBananaEditFailure.invalidEndpoint
        }

        let requestBody = ProxyEditRequest(
            prompt: prompt,
            model: model.rawValue,
            mimeType: "image/png",
            imageBase64: inputPNGData.base64EncodedString()
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }

    private static func imageConfig(for model: NanoBananaModel) -> ImageConfig? {
        switch model {
        case .flashImage31Preview, .proImagePreview:
            return ImageConfig(aspectRatio: "1:1", imageSize: "2K")
        case .gptImage2:
            return nil
        }
    }

    private static func decodeImageData(from data: Data) throws -> Data? {
        if let decoded = decodeOpenAIImageEditResponse(from: data) {
            for image in decoded.data {
                if let imageBase64 = image.b64JSON, let decodedImage = decodeBase64ImageData(imageBase64) {
                    return decodedImage
                }
            }
        }

        if let decoded = decodeGenerateContentResponse(from: data) {
            if let topLevelParts = decoded.parts {
                for part in topLevelParts {
                    if let imageData = part.inlineData?.data, let decodedImage = decodeBase64ImageData(imageData) {
                        return decodedImage
                    }
                }
            }
            for candidate in decoded.candidates {
                let parts = candidate.content?.parts ?? []
                for part in parts {
                    if let imageData = part.inlineData?.data, let decodedImage = decodeBase64ImageData(imageData) {
                        return decodedImage
                    }
                }
            }

            let joinedText = decoded.candidates
                .flatMap { $0.content?.parts ?? [] }
                .compactMap(\.text)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !joinedText.isEmpty {
                throw NanoBananaEditFailure.missingImageData(
                    "Nano Banana returned text instead of an image: \(joinedText.prefix(240))"
                )
            }
        }

        if let decoded = decodeProxyEditResponse(from: data) {
            if let imageBase64 = decoded.imageBase64, let decodedImage = decodeBase64ImageData(imageBase64) {
                return decodedImage
            }
            if let imageBase64 = decoded.inlineData?.data, let decodedImage = decodeBase64ImageData(imageBase64) {
                return decodedImage
            }
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            if let recursivelyDecodedImage = recursivelyExtractImageData(from: jsonObject) {
                return recursivelyDecodedImage
            }
        } catch {
            return nil
        }

        return nil
    }

    private static func decodeAPIErrorEnvelope(from data: Data) -> APIErrorEnvelope? {
        do {
            return try JSONDecoder().decode(APIErrorEnvelope.self, from: data)
        } catch {
            return nil
        }
    }

    private static func decodeGenerateContentResponse(from data: Data) -> GenerateContentResponse? {
        do {
            return try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        } catch {
            return nil
        }
    }

    private static func decodeProxyEditResponse(from data: Data) -> ProxyEditResponse? {
        do {
            return try JSONDecoder().decode(ProxyEditResponse.self, from: data)
        } catch {
            return nil
        }
    }

    private static func decodeOpenAIImageEditResponse(from data: Data) -> OpenAIImageEditResponse? {
        do {
            return try JSONDecoder().decode(OpenAIImageEditResponse.self, from: data)
        } catch {
            return nil
        }
    }

    private static func decodeBase64ImageData(_ rawValue: String) -> Data? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let base64Payload: String
        if let commaIndex = trimmed.firstIndex(of: ","), trimmed[..<commaIndex].contains("base64") {
            base64Payload = String(trimmed[trimmed.index(after: commaIndex)...])
        } else {
            base64Payload = trimmed
        }
        return Data(base64Encoded: base64Payload, options: [.ignoreUnknownCharacters])
    }

    private static func recursivelyExtractImageData(from value: Any) -> Data? {
        if let dictionary = value as? [String: Any] {
            if let imageData = imageData(from: dictionary) {
                return imageData
            }

            for nestedValue in dictionary.values {
                if let imageData = recursivelyExtractImageData(from: nestedValue) {
                    return imageData
                }
            }
        }

        if let array = value as? [Any] {
            for nestedValue in array {
                if let imageData = recursivelyExtractImageData(from: nestedValue) {
                    return imageData
                }
            }
        }

        return nil
    }

    private static func imageData(from dictionary: [String: Any]) -> Data? {
        if
            let inlineData = dictionary["inline_data"] as? [String: Any] ?? dictionary["inlineData"] as? [String: Any],
            let rawValue = inlineData["data"] as? String,
            let decoded = decodeBase64ImageData(rawValue)
        {
            return decoded
        }

        if
            let rawValue = dictionary["image_base64"] as? String ?? dictionary["imageBase64"] as? String,
            let decoded = decodeBase64ImageData(rawValue)
        {
            return decoded
        }

        if
            let mimeType = dictionary["mime_type"] as? String ?? dictionary["mimeType"] as? String,
            mimeType.lowercased().hasPrefix("image/"),
            let rawValue = dictionary["data"] as? String,
            let decoded = decodeBase64ImageData(rawValue)
        {
            return decoded
        }

        return nil
    }
}

private struct GenerateContentRequest: Encodable {
    let contents: [RequestContent]
    let generationConfig: GenerationConfig?
}

private struct RequestContent: Encodable {
    let parts: [RequestPart]
}

private struct GenerationConfig: Encodable {
    let responseModalities: [String]
    let imageConfig: ImageConfig?
}

private struct ImageConfig: Encodable {
    let aspectRatio: String?
    let imageSize: String?
}

private struct RequestPart: Encodable {
    var text: String?
    var inlineData: InlineData?

    init(text: String) {
        self.text = text
    }

    init(inlineData: InlineData) {
        self.inlineData = inlineData
    }

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }
}

private struct InlineData: Codable {
    let mimeType: String?
    let data: String

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

private struct GenerateContentResponse: Decodable {
    let candidates: [Candidate]
    let parts: [ResponsePart]?
}

private struct Candidate: Decodable {
    let content: CandidateContent?
}

private struct CandidateContent: Decodable {
    let parts: [ResponsePart]
}

private struct ResponsePart: Decodable {
    let text: String?
    let inlineData: InlineData?

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }
}

private struct APIErrorEnvelope: Decodable {
    let error: APIError
}

private struct APIError: Decodable {
    let message: String
}

private struct ProxyEditRequest: Encodable {
    let prompt: String
    let model: String
    let mimeType: String
    let imageBase64: String

    enum CodingKeys: String, CodingKey {
        case prompt
        case model
        case mimeType = "mime_type"
        case imageBase64 = "image_base64"
    }
}

private struct ProxyEditResponse: Decodable {
    let imageBase64: String?
    let inlineData: InlineData?

    enum CodingKeys: String, CodingKey {
        case imageBase64 = "image_base64"
        case inlineData = "inline_data"
    }
}

private struct OpenAIImageEditResponse: Decodable {
    let data: [OpenAIImageEditResult]
}

private struct OpenAIImageEditResult: Decodable {
    let b64JSON: String?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case b64JSON = "b64_json"
        case url
    }
}
