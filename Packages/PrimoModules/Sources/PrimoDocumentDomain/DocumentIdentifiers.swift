import Foundation

public struct DocumentRevision: Hashable, Codable, Sendable, Comparable {
    public let rawValue: Int

    public init(_ rawValue: Int) {
        precondition(rawValue >= 0, "Document revision must be non-negative")
        self.rawValue = rawValue
    }

    public static let initial = Self(0)

    public func advanced() -> Self {
        Self(rawValue + 1)
    }

    public static func < (lhs: DocumentRevision, rhs: DocumentRevision) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct NonEmptyLayerName: Hashable, Codable, Sendable {
    public let rawValue: String

    public init?(_ rawValue: String) {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= CanvasSizePolicy.maxLayerNameLength else { return nil }
        self.rawValue = value
    }
}

public struct DocumentLayerIndex: Hashable, Codable, Sendable, Identifiable, Comparable {
    public let rawValue: Int

    public init(validating rawValue: Int) throws {
        guard rawValue >= 0 else {
            throw DocumentWorkspaceError.invalidLayerIndex(rawValue)
        }
        self.rawValue = rawValue
    }

    package init(unchecked rawValue: Int) {
        self.rawValue = rawValue
    }

    package static func unchecked(_ rawValue: Int) -> Self {
        Self(unchecked: rawValue)
    }

    public var id: Int { rawValue }

    public static func < (lhs: DocumentLayerIndex, rhs: DocumentLayerIndex) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        do {
            try self.init(validating: rawValue)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid layer index: \(rawValue)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct DocumentFolderID: Hashable, Codable, Sendable, Identifiable, Comparable {
    public let rawValue: Int

    public init(validating rawValue: Int) throws {
        guard rawValue >= 0 else {
            throw DocumentWorkspaceError.invalidFolderID(rawValue)
        }
        self.rawValue = rawValue
    }

    package init(unchecked rawValue: Int) {
        self.rawValue = rawValue
    }

    package static func unchecked(_ rawValue: Int) -> Self {
        Self(unchecked: rawValue)
    }

    public var id: Int { rawValue }

    public static func < (lhs: DocumentFolderID, rhs: DocumentFolderID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        do {
            try self.init(validating: rawValue)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid folder ID: \(rawValue)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
