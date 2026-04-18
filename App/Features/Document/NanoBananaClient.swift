import ComposableArchitecture
import Foundation

enum NanoBananaEditScope: String, CaseIterable, Equatable, Sendable, Identifiable {
    case wholeLayer
    case selectedArea

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .wholeLayer:
            return language.localized("レイヤー全体")
        case .selectedArea:
            return language.localized("選択範囲")
        }
    }
}

enum NanoBananaOutputMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case replaceCurrentLayer
    case newLayer

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .replaceCurrentLayer:
            return language.localized("現在のレイヤーを置き換え")
        case .newLayer:
            return language.localized("新規レイヤー")
        }
    }
}

struct NanoBananaMaskSettings: Equatable, Sendable {
    var expansion: Int = 0
    var isInverted = false
}

struct NanoBananaGenerationRequest: Equatable, Sendable {
    var prompt: String
    var config: NanoBananaRequestConfig
    var model: NanoBananaModel
    var inputLayerIndex: Int
    var editScope: NanoBananaEditScope
    var outputMode: NanoBananaOutputMode
    var maskSettings: NanoBananaMaskSettings = .init()
}

struct NanoBananaPreviewState: Equatable, Sendable {
    var request: NanoBananaGenerationRequest
    var outputLayerIndex: Int
    var pixelData: Data
    var beforePreviewImageData: Data?
    var afterPreviewImageData: Data?
}

enum NanoBananaJobStatus: String, Equatable, Sendable {
    case running
    case succeeded
    case failed
    case canceled
}

struct NanoBananaJob: Equatable, Sendable, Identifiable {
    var id: UUID
    var request: NanoBananaGenerationRequest
    var createdAt: Date
    var status: NanoBananaJobStatus
    var message: String?
}

struct NanoBananaHistoryItem: Equatable, Sendable, Identifiable {
    var id: UUID
    var request: NanoBananaGenerationRequest
    var createdAt: Date
    var previewImageData: Data?
}

enum NanoBananaPromptPreset: String, CaseIterable, Equatable, Sendable, Identifiable {
    case retouch
    case relight
    case cleanup
    case variant

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .retouch:
            return language.localized("整える")
        case .relight:
            return language.localized("ライティング変更")
        case .cleanup:
            return language.localized("ノイズ除去")
        case .variant:
            return language.localized("バリエーション")
        }
    }

    func prompt(_ language: AppLanguage) -> String {
        switch self {
        case .retouch:
            return language.localized("線や輪郭を整え、細部を少し描き込み、自然できれいな陰影にしてください。")
        case .relight:
            return language.localized("構図はそのままにして、よりドラマチックでシネマティックな光に変えてください。")
        case .cleanup:
            return language.localized("元の絵柄と色を保ったまま、不要な汚れやノイズ、乱れを取り除いてください。")
        case .variant:
            return language.localized("全体の構図と被写体を保ったまま、この画像の近いバリエーションを作ってください。")
        }
    }
}

enum NanoBananaModel: String, CaseIterable, Equatable, Sendable, Identifiable {
    case flashImage25 = "gemini-2.5-flash-image"
    case flashImage31Preview = "gemini-3.1-flash-image-preview"
    case proImagePreview = "gemini-3-pro-image-preview"

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .flashImage25:
            return "Nano Banana"
        case .flashImage31Preview:
            return "Nano Banana 2"
        case .proImagePreview:
            return "Nano Banana Pro"
        }
    }
}

enum NanoBananaAccessMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case userAPIKey
    case appManaged

    var id: String { rawValue }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .userAPIKey:
            return language.localized("ユーザー API キー")
        case .appManaged:
            return language.localized("アプリ課金プラン")
        }
    }
}

struct NanoBananaRequestConfig: Equatable, Sendable {
    let accessMode: NanoBananaAccessMode
    let credential: String
    let endpoint: String
}

struct NanoBananaEditRequest: Equatable, Sendable, OperationRequest {
    let inputPNGData: Data
    let prompt: String
    let config: NanoBananaRequestConfig
    let model: NanoBananaModel
}

struct NanoBananaEditResult: Equatable, Sendable, OperationResult {
    let imageData: Data
}

enum NanoBananaFailure: LocalizedError, Equatable, OperationFailure {
    case invalidEndpoint
    case invalidResponse
    case missingImageData(String)
    case apiError(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Nano Banana endpoint is invalid."
        case .invalidResponse:
            return "Nano Banana returned an invalid response."
        case let .missingImageData(message):
            return message
        case let .apiError(message):
            return message
        case let .transport(message):
            return message
        }
    }
}

enum NanoBananaEditContract: OperationContract {
    typealias Request = NanoBananaEditRequest
    typealias Result = NanoBananaEditResult
    typealias Failure = NanoBananaFailure
}

struct NanoBananaClient: Sendable {
    var executeEdit: @Sendable (NanoBananaEditRequest) async -> Result<NanoBananaEditResult, NanoBananaFailure>

    static func live(httpClient: HTTPClient) -> NanoBananaClient {
        NanoBananaClient { request in
            let primaryPrompt = enforcedImageEditingPrompt(from: request.prompt)
            let retryPrompt = strictRetryImageEditingPrompt(from: request.prompt)
            var lastError: NanoBananaFailure?

            let candidateModels = retryModels(startingWith: request.model)
            for round in 0..<3 {
                if round > 0 {
                    let delayNanoseconds = UInt64((0.8 + Double(round) * 0.9) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delayNanoseconds)
                }

                for candidateModel in candidateModels {
                    do {
                        if let imageData = try await performEditRequest(
                            inputPNGData: request.inputPNGData,
                            prompt: primaryPrompt,
                            config: request.config,
                            model: candidateModel,
                            httpClient: httpClient
                        ) {
                            return .success(NanoBananaEditResult(imageData: imageData))
                        }

                        if let imageData = try await performEditRequest(
                            inputPNGData: request.inputPNGData,
                            prompt: retryPrompt,
                            config: request.config,
                            model: candidateModel,
                            httpClient: httpClient
                        ) {
                            return .success(NanoBananaEditResult(imageData: imageData))
                        }
                    } catch let failure as NanoBananaFailure {
                        lastError = failure
                        guard shouldRetryWithAnotherModel(after: failure) else {
                            return .failure(failure)
                        }
                    } catch {
                        let failure = NanoBananaFailure.transport(error.localizedDescription)
                        lastError = failure
                        return .failure(failure)
                    }
                }
            }

            if let lastError {
                return .failure(lastError)
            }
            return .failure(
                .missingImageData("Nano Banana did not return decodable image bytes.")
            )
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

    private static func shouldRetryWithAnotherModel(after error: NanoBananaFailure) -> Bool {
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

    private static func performEditRequest(
        inputPNGData: Data,
        prompt: String,
        config: NanoBananaRequestConfig,
        model: NanoBananaModel,
        httpClient: HTTPClient
    ) async throws -> Data? {
        switch config.accessMode {
        case .userAPIKey:
            var lastError: NanoBananaFailure?
            for request in makeGeminiRequests(
                inputPNGData: inputPNGData,
                prompt: prompt,
                apiKey: config.credential,
                model: model
            ) {
                do {
                    let (data, response) = try await httpClient.data(request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw NanoBananaFailure.invalidResponse
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        if let apiError = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                            throw NanoBananaFailure.apiError(apiError.error.message)
                        }
                        throw NanoBananaFailure.apiError(
                            String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                        )
                    }

                    if let imageData = try decodeImageData(from: data) {
                        return imageData
                    }
                } catch {
                    if let failure = error as? NanoBananaFailure {
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
        case .appManaged:
            let request = try makeProxyRequest(
                inputPNGData: inputPNGData,
                prompt: prompt,
                accessToken: config.credential,
                endpoint: config.endpoint,
                model: model
            )
            let (data, response) = try await httpClient.data(request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NanoBananaFailure.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if let apiError = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                    throw NanoBananaFailure.apiError(apiError.error.message)
                }
                throw NanoBananaFailure.apiError(
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
            request.httpBody = try? JSONEncoder().encode(requestBody)
            return request.httpBody == nil ? nil : request
        }
    }

    private static func makeProxyRequest(
        inputPNGData: Data,
        prompt: String,
        accessToken: String,
        endpoint: String,
        model: NanoBananaModel
    ) throws -> URLRequest {
        guard let url = URL(string: endpoint), !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NanoBananaFailure.invalidEndpoint
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
        case .flashImage25:
            return ImageConfig(
                aspectRatio: nil,
                imageSize: nil
            )
        case .flashImage31Preview, .proImagePreview:
            return ImageConfig(
                aspectRatio: "1:1",
                imageSize: "2K"
            )
        }
    }

    private static func decodeImageData(from data: Data) throws -> Data? {
        if let decoded = try? JSONDecoder().decode(GenerateContentResponse.self, from: data) {
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
                throw NanoBananaFailure.missingImageData(
                    "Nano Banana returned text instead of an image: \(joinedText.prefix(240))"
                )
            }
        }

        if let decoded = try? JSONDecoder().decode(ProxyEditResponse.self, from: data) {
            if let imageBase64 = decoded.imageBase64, let decodedImage = decodeBase64ImageData(imageBase64) {
                return decodedImage
            }
            if let imageBase64 = decoded.inlineData?.data, let decodedImage = decodeBase64ImageData(imageBase64) {
                return decodedImage
            }
        }

        if
            let jsonObject = try? JSONSerialization.jsonObject(with: data),
            let recursivelyDecodedImage = recursivelyExtractImageData(from: jsonObject)
        {
            return recursivelyDecodedImage
        }

        return nil
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

    enum CodingKeys: String, CodingKey {
        case responseModalities = "responseModalities"
        case imageConfig = "imageConfig"
    }
}

private struct ImageConfig: Encodable {
    let aspectRatio: String?
    let imageSize: String?

    enum CodingKeys: String, CodingKey {
        case aspectRatio = "aspectRatio"
        case imageSize = "imageSize"
    }
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

private enum NanoBananaClientKey: DependencyKey {
    static var liveValue: NanoBananaClient {
        @Dependency(\.httpClient) var httpClient
        return .live(httpClient: httpClient)
    }
}

extension DependencyValues {
    var nanoBananaClient: NanoBananaClient {
        get { self[NanoBananaClientKey.self] }
        set { self[NanoBananaClientKey.self] = newValue }
    }
}
