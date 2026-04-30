import Foundation
import PrimoDocumentPresentationContracts

public enum AIImageEditScope: String, CaseIterable, Equatable, Sendable, Identifiable {
    case wholeLayer
    case selectedArea

    public var id: String { rawValue }
}

public enum AIImageOutputMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case replaceCurrentLayer
    case newLayer

    public var id: String { rawValue }
}

public struct AIImageMaskSettings: Equatable, Sendable {
    public var expansion: Int
    public var isInverted: Bool

    public init(
        expansion: Int = 0,
        isInverted: Bool = false
    ) {
        self.expansion = expansion
        self.isInverted = isInverted
    }
}

public enum AIImageModel: String, CaseIterable, Equatable, Sendable, Identifiable {
    case flashImage31Preview = "gemini-3.1-flash-image-preview"
    case proImagePreview = "gemini-3-pro-image-preview"
    case gptImage2 = "gpt-image-2"
    case gptImage15 = "gpt-image-1.5"
    case gptImage1 = "gpt-image-1"
    case gptImage1Mini = "gpt-image-1-mini"
    case chatGPTImageLatest = "chatgpt-image-latest"

    public static var allCases: [AIImageModel] {
        [
            .flashImage31Preview,
            .proImagePreview,
            .gptImage2,
            .gptImage15,
            .gptImage1,
            .gptImage1Mini,
            .chatGPTImageLatest,
        ]
    }

    public var id: String { rawValue }

    public var provider: AIImageModelProvider {
        switch self {
        case .flashImage31Preview, .proImagePreview:
            return .gemini
        case .gptImage2, .gptImage15, .gptImage1, .gptImage1Mini, .chatGPTImageLatest:
            return .openAI
        }
    }

    public static let defaultOpenAIDirectEditModel: AIImageModel = .gptImage15

    public static let openAIDirectEditModels: [AIImageModel] = [
        .gptImage2,
        .gptImage15,
        .gptImage1,
        .gptImage1Mini,
        .chatGPTImageLatest,
    ]

    public var supportsOpenAIDirectImageEdit: Bool {
        Self.openAIDirectEditModels.contains(self)
    }
}

public enum AIImageModelProvider: String, Equatable, Sendable {
    case gemini
    case openAI
}

public enum AIImageAccessMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case userAPIKey
    case appManaged

    public var id: String { rawValue }
}

public struct NonEmptyPrompt: Equatable, Sendable {
    public static let maxCharacterCount = 8192
    public let rawValue: String

    public init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= Self.maxCharacterCount else { return nil }
        self.rawValue = trimmed
    }
}

public struct AIImageAPIKey: Equatable, Sendable {
    public static let maxCharacterCount = 512
    public let rawValue: String

    public init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= Self.maxCharacterCount else { return nil }
        self.rawValue = trimmed
    }
}

public struct AIImageEntitlementToken: Equatable, Sendable {
    public static let maxCharacterCount = 512
    public let rawValue: String

    public init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= Self.maxCharacterCount else { return nil }
        self.rawValue = trimmed
    }
}

public struct ProxyEndpoint: Equatable, Sendable {
    public static let maxCharacterCount = 2048
    public static let allowedHostSuffixes: Set<String> = ["bestcatscience.com"]
    public let rawValue: String

    public init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            trimmed.count <= Self.maxCharacterCount,
            let url = URL(string: trimmed),
            url.scheme == "https",
            Self.isAllowedHost(url.host)
        else { return nil }
        self.rawValue = trimmed
    }

    public static func isAllowedHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased(), !host.isEmpty else { return false }
        return allowedHostSuffixes.contains { suffix in
            host == suffix || host.hasSuffix(".\(suffix)")
        }
    }
}

public enum AIImageExecutionConfig: Equatable, Sendable {
    case userAPIKey(apiKey: AIImageAPIKey)
    case appManaged(entitlement: AIImageEntitlementToken, endpoint: ProxyEndpoint)

    public var accessMode: AIImageAccessMode {
        switch self {
        case .userAPIKey:
            return .userAPIKey
        case .appManaged:
            return .appManaged
        }
    }
}

public struct AIImageDraft: Equatable, Sendable {
    public var prompt: String
    public var accessMode: AIImageAccessMode
    public var model: AIImageModel
    public var inputLayerIndex: Int
    public var editScope: AIImageEditScope
    public var outputMode: AIImageOutputMode
    public var maskSettings: AIImageMaskSettings

    public init(
        prompt: String,
        accessMode: AIImageAccessMode,
        model: AIImageModel,
        inputLayerIndex: Int,
        editScope: AIImageEditScope,
        outputMode: AIImageOutputMode,
        maskSettings: AIImageMaskSettings = .init()
    ) {
        self.prompt = prompt
        self.accessMode = accessMode
        self.model = model
        self.inputLayerIndex = inputLayerIndex
        self.editScope = editScope
        self.outputMode = outputMode
        self.maskSettings = maskSettings
    }
}

public struct AIImageEditDescriptor: Equatable, Sendable {
    public var prompt: NonEmptyPrompt
    public var accessMode: AIImageAccessMode
    public var model: AIImageModel
    public var inputLayerIndex: Int
    public var editScope: AIImageEditScope
    public var outputMode: AIImageOutputMode
    public var maskSettings: AIImageMaskSettings

    public init(
        prompt: NonEmptyPrompt,
        accessMode: AIImageAccessMode,
        model: AIImageModel,
        inputLayerIndex: Int,
        editScope: AIImageEditScope,
        outputMode: AIImageOutputMode,
        maskSettings: AIImageMaskSettings = .init()
    ) {
        self.prompt = prompt
        self.accessMode = accessMode
        self.model = model
        self.inputLayerIndex = inputLayerIndex
        self.editScope = editScope
        self.outputMode = outputMode
        self.maskSettings = maskSettings
    }
}

public struct SubmitAIImageEditCommand: Equatable, Sendable {
    public var descriptor: AIImageEditDescriptor
    public var executionConfig: AIImageExecutionConfig

    public init(
        descriptor: AIImageEditDescriptor,
        executionConfig: AIImageExecutionConfig
    ) {
        self.descriptor = descriptor
        self.executionConfig = executionConfig
    }
}

public struct AIImagePreviewState: Equatable, Sendable {
    public var descriptor: AIImageEditDescriptor
    public var outputLayerIndex: Int
    public var outputSurface: DocumentCompositeSurface
    public var beforePreviewImageData: Data?
    public var afterPreviewImageData: Data?

    public var pixelData: Data {
        outputSurface.pixelData
    }

    public init(
        descriptor: AIImageEditDescriptor,
        outputLayerIndex: Int,
        outputSurface: DocumentCompositeSurface,
        beforePreviewImageData: Data?,
        afterPreviewImageData: Data?
    ) {
        self.descriptor = descriptor
        self.outputLayerIndex = outputLayerIndex
        self.outputSurface = outputSurface
        self.beforePreviewImageData = beforePreviewImageData
        self.afterPreviewImageData = afterPreviewImageData
    }
}

public enum AIImageJobStatus: String, Equatable, Sendable {
    case running
    case succeeded
    case failed
    case canceled
}

public struct AIImageJob: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var descriptor: AIImageEditDescriptor
    public var createdAt: Date
    public var status: AIImageJobStatus
    public var message: String?

    public init(
        id: UUID,
        descriptor: AIImageEditDescriptor,
        createdAt: Date,
        status: AIImageJobStatus,
        message: String?
    ) {
        self.id = id
        self.descriptor = descriptor
        self.createdAt = createdAt
        self.status = status
        self.message = message
    }
}

public struct AIImageHistoryItem: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var descriptor: AIImageEditDescriptor
    public var createdAt: Date
    public var previewImageData: Data?

    public init(
        id: UUID,
        descriptor: AIImageEditDescriptor,
        createdAt: Date,
        previewImageData: Data?
    ) {
        self.id = id
        self.descriptor = descriptor
        self.createdAt = createdAt
        self.previewImageData = previewImageData
    }
}

public struct AIImageSettingsDraft: Equatable, Sendable {
    public var accessMode: AIImageAccessMode
    public var apiKey: String
    public var openAIAPIKey: String

    public init(
        accessMode: AIImageAccessMode = .appManaged,
        apiKey: String = "",
        openAIAPIKey: String = ""
    ) {
        self.accessMode = accessMode
        self.apiKey = apiKey
        self.openAIAPIKey = openAIAPIKey
    }
}

public typealias AIImageSettings = AIImageSettingsDraft

public struct AIImageCommerceSnapshot: Equatable, Sendable {
    public struct ProductSummary: Equatable, Sendable {
        public var id: String
        public var displayName: String
        public var displayPrice: String

        public init(
            id: String,
            displayName: String,
            displayPrice: String
        ) {
            self.id = id
            self.displayName = displayName
            self.displayPrice = displayPrice
        }
    }

    public var primaryProduct: ProductSummary?
    public var isLoading: Bool
    public var isSubscriptionActive: Bool
    public var latestEntitlementJWS: String
    public var purchaseErrorMessage: String?
    public var manageSubscriptionsURL: URL?
    public var proxyEndpoint: String

    public init(
        primaryProduct: ProductSummary? = nil,
        isLoading: Bool = false,
        isSubscriptionActive: Bool = false,
        latestEntitlementJWS: String = "",
        purchaseErrorMessage: String? = nil,
        manageSubscriptionsURL: URL? = URL(string: "https://apps.apple.com/account/subscriptions"),
        proxyEndpoint: String = ""
    ) {
        self.primaryProduct = primaryProduct
        self.isLoading = isLoading
        self.isSubscriptionActive = isSubscriptionActive
        self.latestEntitlementJWS = latestEntitlementJWS
        self.purchaseErrorMessage = purchaseErrorMessage
        self.manageSubscriptionsURL = manageSubscriptionsURL
        self.proxyEndpoint = proxyEndpoint
    }
}

public enum AIImageEditFailure: LocalizedError, Equatable, Sendable {
    case invalidEndpoint
    case invalidResponse
    case missingImageData(String)
    case apiError(String)
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "AI image editing endpoint must be a valid HTTPS URL."
        case .invalidResponse:
            return "AI image editing returned an invalid response."
        case let .missingImageData(message):
            return message
        case let .apiError(message):
            return message
        case let .transport(message):
            return message
        }
    }
}
