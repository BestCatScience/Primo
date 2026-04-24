import Foundation
import PrimoDocumentContracts

public enum NanoBananaEditScope: String, CaseIterable, Equatable, Sendable, Identifiable {
    case wholeLayer
    case selectedArea

    public var id: String { rawValue }
}

public enum NanoBananaOutputMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case replaceCurrentLayer
    case newLayer

    public var id: String { rawValue }
}

public struct NanoBananaMaskSettings: Equatable, Sendable {
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

public enum NanoBananaModel: String, CaseIterable, Equatable, Sendable, Identifiable {
    case flashImage25 = "gemini-2.5-flash-image"
    case flashImage31Preview = "gemini-3.1-flash-image-preview"
    case proImagePreview = "gemini-3-pro-image-preview"

    public var id: String { rawValue }
}

public enum NanoBananaAccessMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case userAPIKey
    case appManaged

    public var id: String { rawValue }
}

public struct NonEmptyPrompt: Equatable, Sendable {
    public let rawValue: String

    public init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.rawValue = trimmed
    }
}

public struct NanoBananaAPIKey: Equatable, Sendable {
    public let rawValue: String

    public init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.rawValue = trimmed
    }
}

public struct NanoBananaEntitlementToken: Equatable, Sendable {
    public let rawValue: String

    public init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.rawValue = trimmed
    }
}

public struct ProxyEndpoint: Equatable, Sendable {
    public let rawValue: String

    public init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, URL(string: trimmed) != nil else { return nil }
        self.rawValue = trimmed
    }
}

public enum NanoBananaExecutionConfig: Equatable, Sendable {
    case userAPIKey(apiKey: NanoBananaAPIKey)
    case appManaged(entitlement: NanoBananaEntitlementToken, endpoint: ProxyEndpoint)

    public var accessMode: NanoBananaAccessMode {
        switch self {
        case .userAPIKey:
            return .userAPIKey
        case .appManaged:
            return .appManaged
        }
    }
}

public struct NanoBananaDraft: Equatable, Sendable {
    public var prompt: String
    public var accessMode: NanoBananaAccessMode
    public var model: NanoBananaModel
    public var inputLayerIndex: Int
    public var editScope: NanoBananaEditScope
    public var outputMode: NanoBananaOutputMode
    public var maskSettings: NanoBananaMaskSettings

    public init(
        prompt: String,
        accessMode: NanoBananaAccessMode,
        model: NanoBananaModel,
        inputLayerIndex: Int,
        editScope: NanoBananaEditScope,
        outputMode: NanoBananaOutputMode,
        maskSettings: NanoBananaMaskSettings = .init()
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

public struct NanoBananaEditDescriptor: Equatable, Sendable {
    public var prompt: NonEmptyPrompt
    public var accessMode: NanoBananaAccessMode
    public var model: NanoBananaModel
    public var inputLayerIndex: Int
    public var editScope: NanoBananaEditScope
    public var outputMode: NanoBananaOutputMode
    public var maskSettings: NanoBananaMaskSettings

    public init(
        prompt: NonEmptyPrompt,
        accessMode: NanoBananaAccessMode,
        model: NanoBananaModel,
        inputLayerIndex: Int,
        editScope: NanoBananaEditScope,
        outputMode: NanoBananaOutputMode,
        maskSettings: NanoBananaMaskSettings = .init()
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

public struct SubmitNanoBananaEditCommand: Equatable, Sendable {
    public var descriptor: NanoBananaEditDescriptor
    public var executionConfig: NanoBananaExecutionConfig

    public init(
        descriptor: NanoBananaEditDescriptor,
        executionConfig: NanoBananaExecutionConfig
    ) {
        self.descriptor = descriptor
        self.executionConfig = executionConfig
    }
}

public struct NanoBananaPreviewState: Equatable, Sendable {
    public var descriptor: NanoBananaEditDescriptor
    public var outputLayerIndex: Int
    public var outputSurface: DocumentCompositeSurface
    public var beforePreviewImageData: Data?
    public var afterPreviewImageData: Data?

    public var pixelData: Data {
        outputSurface.pixelData
    }

    public init(
        descriptor: NanoBananaEditDescriptor,
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

public enum NanoBananaJobStatus: String, Equatable, Sendable {
    case running
    case succeeded
    case failed
    case canceled
}

public struct NanoBananaJob: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var descriptor: NanoBananaEditDescriptor
    public var createdAt: Date
    public var status: NanoBananaJobStatus
    public var message: String?

    public init(
        id: UUID,
        descriptor: NanoBananaEditDescriptor,
        createdAt: Date,
        status: NanoBananaJobStatus,
        message: String?
    ) {
        self.id = id
        self.descriptor = descriptor
        self.createdAt = createdAt
        self.status = status
        self.message = message
    }
}

public struct NanoBananaHistoryItem: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var descriptor: NanoBananaEditDescriptor
    public var createdAt: Date
    public var previewImageData: Data?

    public init(
        id: UUID,
        descriptor: NanoBananaEditDescriptor,
        createdAt: Date,
        previewImageData: Data?
    ) {
        self.id = id
        self.descriptor = descriptor
        self.createdAt = createdAt
        self.previewImageData = previewImageData
    }
}

public struct NanoBananaSettings: Equatable, Sendable {
    public var accessMode: NanoBananaAccessMode
    public var apiKey: String

    public init(
        accessMode: NanoBananaAccessMode = .userAPIKey,
        apiKey: String = ""
    ) {
        self.accessMode = accessMode
        self.apiKey = apiKey
    }
}

public struct NanoBananaCommerceSnapshot: Equatable, Sendable {
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

public enum NanoBananaEditFailure: LocalizedError, Equatable, Sendable {
    case invalidEndpoint
    case invalidResponse
    case missingImageData(String)
    case apiError(String)
    case transport(String)

    public var errorDescription: String? {
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
